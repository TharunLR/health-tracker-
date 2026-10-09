import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/food_log_service.dart';
import '../widgets/nutrition_graph_card.dart';
import 'food_scanner_screen.dart';

class FoodLogScreen extends StatefulWidget {
  const FoodLogScreen({super.key});

  @override
  State<FoodLogScreen> createState() => _FoodLogScreenState();
}

class _FoodLogScreenState extends State<FoodLogScreen> {
  bool _isOpeningScanner = false;

  Future<void> _openScanner(BuildContext context) async {
    if (_isOpeningScanner) {
      return;
    }

    setState(() {
      _isOpeningScanner = true;
    });

    try {
      final added = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const FoodScannerScreen()),
      );
      if (!context.mounted || added != true) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Food logged.')));
    } finally {
      if (mounted) {
        setState(() {
          _isOpeningScanner = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F1EC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F1EC),
        elevation: 0,
        title: const Text('Food log'),
      ),
      body: Stack(
        children: [
          StreamBuilder<List<FoodLogEntry>>(
            stream: FoodLogService.instance.entriesStream,
            builder: (context, snapshot) {
              final entries = snapshot.data ?? const [];
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
                children: [
                  const NutritionGraphCard(),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x12000000),
                          blurRadius: 22,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your meals',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: const Color(0xFF111111),
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          entries.isEmpty
                              ? 'No food logged yet.'
                              : 'Logged meals: ${entries.length}',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: const Color(0xFF6F6A64)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (entries.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x12000000),
                            blurRadius: 22,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Text(
                        'Tap Scan below to add your first meal.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF6F6A64),
                        ),
                      ),
                    ),
                  if (entries.isNotEmpty)
                    ...entries.map((entry) => _FoodLogCard(entry: entry)),
                ],
              );
            },
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFE9DB),
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x22000000),
                    blurRadius: 16,
                    offset: Offset(0, 8),
                  ),
                ],
                border: Border.all(color: const Color(0xFFFFD2B5)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFFFB37A),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.qr_code_scanner_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Scan meal',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: const Color(0xFF111111),
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Log food quickly with the scanner.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: const Color(0xFF6F6A64)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _isOpeningScanner
                        ? null
                        : () => _openScanner(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFF8A4C),
                      foregroundColor: Colors.white,
                    ),
                    child: Text(_isOpeningScanner ? 'Opening...' : 'Scan'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FoodLogCard extends StatelessWidget {
  const _FoodLogCard({required this.entry});

  final FoodLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final hour = entry.timestamp.hour == 0 ? 12 : (entry.timestamp.hour > 12 ? entry.timestamp.hour - 12 : entry.timestamp.hour);
    final minute = entry.timestamp.minute.toString().padLeft(2, '0');
    final ampm = entry.timestamp.hour >= 12 ? 'PM' : 'AM';
    final timeStr = '$hour:$minute $ampm';

    final calories = entry.calories == null
        ? '0 kcal'
        : '${entry.calories!.round()} kcal';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPhotoPreview(),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF111111),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$timeStr • $calories',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF6F6A64),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (entry.proteinG != null || entry.carbsG != null || entry.fatG != null) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (entry.proteinG != null)
                            _buildMiniChip('${entry.proteinG!.toStringAsFixed(1)}g P', const Color(0xFF1565C0), const Color(0xFFF0F7FF)),
                          if (entry.carbsG != null)
                            _buildMiniChip('${entry.carbsG!.toStringAsFixed(1)}g C', const Color(0xFF2E7D32), const Color(0xFFF2F9F2)),
                          if (entry.fatG != null)
                            _buildMiniChip('${entry.fatG!.toStringAsFixed(1)}g F', const Color(0xFFC2185B), const Color(0xFFFFF0F3)),
                          if (entry.portionGrams != null)
                            _buildMiniChip('${entry.portionGrams!.toInt()}g', const Color(0xFF7B1FA2), const Color(0xFFF3E5F5)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Color(0xFFD32F2F)),
                onPressed: () => FoodLogService.instance.removeEntry(entry.id),
              ),
            ],
          ),
          if (entry.itemsSummary != null && entry.itemsSummary!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F6F2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                entry.itemsSummary!,
                style: const TextStyle(fontSize: 12, color: Color(0xFF55504A), height: 1.35),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMiniChip(String label, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textColor),
      ),
    );
  }

  Widget _buildPhotoPreview() {
    final trimmedPath = entry.photoPath?.trim();
    if (trimmedPath != null && trimmedPath.isNotEmpty) {
      if (kIsWeb) {
        if (trimmedPath.startsWith('http://') ||
            trimmedPath.startsWith('https://') ||
            trimmedPath.startsWith('blob:')) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.network(
              trimmedPath,
              width: 72,
              height: 72,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _buildPhotoFallback(),
            ),
          );
        }
      } else {
        try {
          final file = File(trimmedPath);
          if (file.existsSync()) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.file(
                file,
                width: 72,
                height: 72,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _buildPhotoFallback(),
              ),
            );
          }
        } catch (_) {}
      }
    }

    final memoryBytes = _decodePhotoBytes(entry.photoBase64);
    if (memoryBytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.memory(
          memoryBytes,
          width: 72,
          height: 72,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _buildPhotoFallback(),
        ),
      );
    }

    return _buildPhotoFallback();
  }

  Widget _buildPhotoFallback() {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: const Color(0xFFFFE9DB),
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.restaurant_menu_rounded, color: Color(0xFFFF7A59)),
    );
  }

  Uint8List? _decodePhotoBytes(String? encoded) {
    if (encoded == null || encoded.trim().isEmpty) {
      return null;
    }

    try {
      return base64Decode(encoded);
    } catch (_) {
      return null;
    }
  }
}
