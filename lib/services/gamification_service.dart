import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'food_log_service.dart';
import 'hydration_service.dart';
import 'steps_service.dart';

class AchievementBadge {
  const AchievementBadge({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.unlocked,
    required this.progress,
    required this.xpReward,
  });

  final String id;
  final String title;
  final String description;
  final String icon;
  final bool unlocked;
  final double progress; // 0.0 to 1.0
  final int xpReward;
}

class GamificationState {
  const GamificationState({
    required this.xpPoints,
    required this.currentStreak,
    required this.level,
    required this.badges,
  });

  final int xpPoints;
  final int currentStreak;
  final int level;
  final List<AchievementBadge> badges;
}

class GamificationService {
  GamificationService._();

  static final GamificationService instance = GamificationService._();

  static const String _xpKey = 'user_gamification_xp';
  static const String _streakKey = 'user_gamification_streak';
  static const String _lastActiveKey = 'user_gamification_last_active';

  final StreamController<GamificationState> _controller =
      StreamController<GamificationState>.broadcast();

  int _xp = 350;
  int _streak = 3;
  bool _loaded = false;

  Stream<GamificationState> get stateStream {
    _ensureLoaded();
    return _controller.stream;
  }

  GamificationState get currentState {
    _ensureLoaded();
    return _computeState();
  }

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      _xp = prefs.getInt(_xpKey) ?? 350;
      _streak = prefs.getInt(_streakKey) ?? 3;

      final lastActiveRaw = prefs.getString(_lastActiveKey);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      if (lastActiveRaw != null) {
        final lastDate = DateTime.tryParse(lastActiveRaw);
        if (lastDate != null) {
          final lastDay = DateTime(lastDate.year, lastDate.month, lastDate.day);
          final diff = today.difference(lastDay).inDays;
          if (diff == 1) {
            // Consecutive day activity!
          } else if (diff > 1) {
            _streak = 1; // Reset streak if missed more than 1 day
          }
        }
      } else {
        prefs.setString(_lastActiveKey, today.toIso8601String());
      }
    } catch (_) {}

    _emitState();
  }

  void addXP(int points) {
    _xp += points;
    _saveState();
    _emitState();
  }

  void _saveState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_xpKey, _xp);
      await prefs.setInt(_streakKey, _streak);
    } catch (_) {}
  }

  void _emitState() {
    _controller.add(_computeState());
  }

  GamificationState _computeState() {
    final todayCalories = FoodLogService.instance.getTodayCalories();
    final todaySteps = StepsService.instance.currentSnapshot.stepsToday;
    final todayWater = (HydrationService.instance.currentSnapshot.todayLiters * 1000).toInt();

    final badges = [
      AchievementBadge(
        id: 'water_hero',
        title: 'Hydration Hero',
        description: 'Drink at least 2,000ml of water today',
        icon: '💧',
        unlocked: todayWater >= 2000,
        progress: (todayWater / 2000.0).clamp(0.0, 1.0),
        xpReward: 100,
      ),
      AchievementBadge(
        id: 'step_master',
        title: '10k Steps Master',
        description: 'Reach 10,000 physical steps today',
        icon: '🏃',
        unlocked: todaySteps >= 10000,
        progress: (todaySteps / 10000.0).clamp(0.0, 1.0),
        xpReward: 200,
      ),
      AchievementBadge(
        id: 'macro_pro',
        title: 'Macro Balance Pro',
        description: 'Log your meals to hit nutrition targets',
        icon: '🥗',
        unlocked: todayCalories >= 1200,
        progress: (todayCalories / 1500.0).clamp(0.0, 1.0),
        xpReward: 150,
      ),
      AchievementBadge(
        id: 'ai_scanner',
        title: 'AI Meal Scanner',
        description: 'Scan or describe a meal using AI',
        icon: '📸',
        unlocked: FoodLogService.instance.currentEntries.isNotEmpty,
        progress: FoodLogService.instance.currentEntries.isNotEmpty ? 1.0 : 0.0,
        xpReward: 120,
      ),
    ];

    final level = (_xp / 200).floor() + 1;

    return GamificationState(
      xpPoints: _xp,
      currentStreak: _streak,
      level: level,
      badges: badges,
    );
  }
}
