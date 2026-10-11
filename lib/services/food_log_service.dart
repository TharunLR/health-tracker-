import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/security_utils.dart';

class FoodLogEntry {
  const FoodLogEntry({
    required this.id,
    required this.timestamp,
    required this.name,
    this.calories,
    this.proteinG,
    this.carbsG,
    this.fatG,
    this.portionGrams,
    this.itemsSummary,
    this.photoPath,
    this.photoBase64,
  });

  final String id;
  final DateTime timestamp;
  final String name;
  final double? calories;
  final double? proteinG;
  final double? carbsG;
  final double? fatG;
  final double? portionGrams;
  final String? itemsSummary;
  final String? photoPath;
  final String? photoBase64;

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'name': name,
        'calories': calories,
        'proteinG': proteinG,
        'carbsG': carbsG,
        'fatG': fatG,
        'portionGrams': portionGrams,
        'itemsSummary': itemsSummary,
        'photoPath': photoPath,
        'photoBase64': photoBase64,
      };

  static FoodLogEntry fromJson(Map<String, dynamic> json) {
    return FoodLogEntry(
      id: json['id']?.toString() ?? '',
      timestamp:
          DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
              DateTime.now(),
      name: json['name']?.toString() ?? '',
      calories: (json['calories'] as num?)?.toDouble(),
      proteinG: (json['proteinG'] as num?)?.toDouble(),
      carbsG: (json['carbsG'] as num?)?.toDouble(),
      fatG: (json['fatG'] as num?)?.toDouble(),
      portionGrams: (json['portionGrams'] as num?)?.toDouble(),
      itemsSummary: json['itemsSummary']?.toString(),
      photoPath: json['photoPath']?.toString(),
      photoBase64: json['photoBase64']?.toString(),
    );
  }
}

class FoodLogService {
  FoodLogService._();

  static final FoodLogService instance = FoodLogService._();

  static const _entriesKey = 'food_log_entries';

  final StreamController<List<FoodLogEntry>> _controller =
      StreamController<List<FoodLogEntry>>.broadcast();
  List<FoodLogEntry> _entries = [];
  bool _loaded = false;

  Stream<List<FoodLogEntry>> get entriesStream {
    _ensureLoaded();
    return _controller.stream;
  }

  List<FoodLogEntry> get currentEntries {
    _ensureLoaded();
    return List.unmodifiable(_entries);
  }

  double getTodayCalories() {
    return getCaloriesForDate(DateTime.now());
  }

  List<FoodLogEntry> getEntriesForDate(DateTime date) {
    _ensureLoaded();
    return _entries.where((entry) =>
      entry.timestamp.year == date.year &&
      entry.timestamp.month == date.month &&
      entry.timestamp.day == date.day
    ).toList();
  }

  List<FoodLogEntry> getTodayEntries() {
    return getEntriesForDate(DateTime.now());
  }

  Map<String, double> getMacrosForDate(DateTime date) {
    final dayEntries = getEntriesForDate(date);
    double cals = 0;
    double protein = 0;
    double carbs = 0;
    double fat = 0;

    for (final entry in dayEntries) {
      final c = entry.calories ?? 0;
      cals += c;
      protein += entry.proteinG ?? (c * 0.25 / 4.0);
      carbs += entry.carbsG ?? (c * 0.50 / 4.0);
      fat += entry.fatG ?? (c * 0.25 / 9.0);
    }

    return {
      'calories': cals,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
    };
  }

  Map<String, double> getTodayMacros() {
    return getMacrosForDate(DateTime.now());
  }

  double getCaloriesForDate(DateTime date) {
    _ensureLoaded();
    double total = 0;
    for (final entry in _entries) {
      if (entry.timestamp.year == date.year &&
          entry.timestamp.month == date.month &&
          entry.timestamp.day == date.day) {
        total += entry.calories ?? 0;
      }
    }
    return total;
  }

  Future<void> addEntry({
    required String name,
    double? calories,
    double? proteinG,
    double? carbsG,
    double? fatG,
    double? portionGrams,
    String? itemsSummary,
    String? photoPath,
    Uint8List? imageBytes,
  }) async {
    await _ensureLoaded();
    final sanitizedName = SecurityUtils.sanitizeInput(name);
    final sanitizedSummary = itemsSummary != null ? SecurityUtils.sanitizeInput(itemsSummary) : null;
    final trimmedPhotoPath = photoPath?.trim();

    String? base64Str;
    if (imageBytes != null && imageBytes.isNotEmpty) {
      base64Str = _createThumbnailBase64(imageBytes);
    } else {
      base64Str = await _readPhotoBase64(trimmedPhotoPath);
    }

    final entry = FoodLogEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      name: sanitizedName.isNotEmpty ? sanitizedName : 'Meal Entry',
      calories: calories != null ? SecurityUtils.sanitizeNumeric(calories) : null,
      proteinG: proteinG != null ? SecurityUtils.sanitizeNumeric(proteinG) : null,
      carbsG: carbsG != null ? SecurityUtils.sanitizeNumeric(carbsG) : null,
      fatG: fatG != null ? SecurityUtils.sanitizeNumeric(fatG) : null,
      portionGrams: portionGrams != null ? SecurityUtils.sanitizeNumeric(portionGrams) : null,
      itemsSummary: sanitizedSummary,
      photoPath: trimmedPhotoPath,
      photoBase64: base64Str,
    );

    _entries = [entry, ..._entries];
    _controller.add(List<FoodLogEntry>.unmodifiable(_entries));
    unawaited(_persist());
  }

  Future<void> removeEntry(String id) async {
    await _ensureLoaded();
    _entries.removeWhere((entry) => entry.id == id);
    _controller.add(List<FoodLogEntry>.unmodifiable(_entries));
    unawaited(_persist());
  }

  Future<void> _ensureLoaded() async {
    if (_loaded) {
      return;
    }
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_entriesKey);
    _entries = _decodeEntries(raw);

    // Guarantee retention for at least 2 days (48 hours)
    final twoDaysAgo = DateTime.now().subtract(const Duration(days: 2));
    _entries = _entries.where((e) => e.timestamp.isAfter(twoDaysAgo)).toList();

    // Clean up oversized base64 strings from legacy entries to prevent UI freeze
    bool modified = false;
    final cleaned = <FoodLogEntry>[];
    for (final e in _entries) {
      if (e.photoBase64 != null && e.photoBase64!.length > 100000) {
        modified = true;
        cleaned.add(FoodLogEntry(
          id: e.id,
          timestamp: e.timestamp,
          name: e.name,
          calories: e.calories,
          proteinG: e.proteinG,
          carbsG: e.carbsG,
          fatG: e.fatG,
          portionGrams: e.portionGrams,
          itemsSummary: e.itemsSummary,
          photoPath: e.photoPath,
          photoBase64: null,
        ));
      } else {
        cleaned.add(e);
      }
    }
    if (modified) {
      _entries = cleaned;
      unawaited(_persist());
    }

    _controller.add(List<FoodLogEntry>.unmodifiable(_entries));
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode(_entries.map((entry) => entry.toJson()).toList());
      await prefs.setString(_entriesKey, raw);
    } catch (_) {}
  }

  List<FoodLogEntry> _decodeEntries(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return [];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return [];
      }
      return decoded
          .whereType<Map>()
          .map((item) => FoodLogEntry.fromJson(item.cast<String, dynamic>()))
          .where((entry) => entry.name.trim().isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return [];
    }
  }

  Future<String?> _readPhotoBase64(String? photoPath) async {
    if (photoPath == null || photoPath.isEmpty) {
      return null;
    }

    try {
      final file = File(photoPath);
      if (!await file.exists()) {
        return null;
      }
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        return null;
      }
      return _createThumbnailBase64(bytes);
    } catch (_) {
      return null;
    }
  }

  static String? _createThumbnailBase64(Uint8List? rawBytes) {
    if (rawBytes == null || rawBytes.isEmpty) return null;
    try {
      if (rawBytes.length < 30000) {
        return base64Encode(rawBytes);
      }
      final decoded = img.decodeImage(rawBytes);
      if (decoded == null) {
        return rawBytes.length < 100000 ? base64Encode(rawBytes) : null;
      }
      final resized = img.copyResize(
        decoded,
        width: decoded.width > decoded.height ? 250 : null,
        height: decoded.height >= decoded.width ? 250 : null,
      );
      final compressed = img.encodeJpg(resized, quality: 60);
      return base64Encode(compressed);
    } catch (_) {
      return rawBytes.length < 100000 ? base64Encode(rawBytes) : null;
    }
  }
}
