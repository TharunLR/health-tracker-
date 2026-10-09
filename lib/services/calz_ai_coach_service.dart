import 'dart:convert';
import 'package:http/http.dart' as http;
import 'esp32_health_band_service.dart';
import 'food_log_service.dart';
import 'hydration_service.dart';
import 'steps_service.dart';
import '../utils/security_utils.dart';

class CalzChatMessage {
  const CalzChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });

  final String text;
  final bool isUser;
  final DateTime timestamp;
}

class CalzAICoachService {
  CalzAICoachService._();

  static final CalzAICoachService instance = CalzAICoachService._();

  /// Generates a personalized daily health summary from live telemetry (Calories, Steps, ESP32 BLE Vitals, Hydration)
  Future<String> generateDailyHealthSummary() async {
    final cals = FoodLogService.instance.getTodayCalories().toInt();
    final steps = StepsService.instance.currentSnapshot.stepsToday;
    final water = (HydrationService.instance.currentSnapshot.todayLiters * 1000).toInt();
    final bandData = ESP32HealthBandService.instance.currentData;

    final bpmStr = bandData.isConnected && bandData.bpm > 0
        ? '${bandData.bpm} BPM'
        : 'Normal resting pulse';
    final spo2Str = bandData.isConnected && bandData.spo2 > 0
        ? '${bandData.spo2}%'
        : '98%';

    final promptText = '''
You are "Calz AI", an encouraging, expert AI Personal Health Coach for a health tracker app.
Analyze the user's live daily health stats:
- Calories consumed today: $cals kcal (Target: ~2000 kcal)
- Physical steps walked today: $steps steps (Target: 10,000 steps)
- Water intake today: ${water}ml (Target: 2500ml)
- ESP32 Hardware Band Sensors: Heart Rate = $bpmStr, SpO2 = $spo2Str

Write a concise, friendly, 2-3 sentence personalized summary & health recommendation for the user. Keep it motivating, practical, and highly engaging!
''';

    return _queryGeminiAI(promptText, fallbackText: _buildFallbackSummary(cals, steps, water, bandData));
  }

  /// Handles user chat messages with Calz AI Coach
  Future<String> answerUserQuestion(String question) async {
    final sanitizedQuestion = SecurityUtils.sanitizeInput(question);
    final cals = FoodLogService.instance.getTodayCalories().toInt();
    final steps = StepsService.instance.currentSnapshot.stepsToday;
    final water = (HydrationService.instance.currentSnapshot.todayLiters * 1000).toInt();
    final bandData = ESP32HealthBandService.instance.currentData;

    final promptText = '''
You are "Calz AI", a smart personal health coach in a Flutter app.
Current user stats: Calories=$cals kcal, Steps=$steps, Water=${water}ml, HeartRate=${bandData.bpm} BPM, SpO2=${bandData.spo2}%.

User Question: "$sanitizedQuestion"

Respond helpfully in 2-3 concise sentences with actionable health/nutrition advice.
''';

    return _queryGeminiAI(promptText, fallbackText: _buildFallbackAnswer(sanitizedQuestion, cals, steps, water));
  }

  Future<String> _queryGeminiAI(String promptText, {required String fallbackText}) async {
    final apiKey = SecurityUtils.geminiApiKey;
    final candidateModels = [
      'gemini-3.5-flash',
      'gemini-3.6-flash',
      'gemini-3-flash-preview',
      'gemini-3.5-flash-lite',
    ];

    for (final model in candidateModels) {
      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
      );

      try {
        final response = await http.post(
          uri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {'text': promptText},
                ],
              },
            ],
            'generationConfig': {
              'temperature': 0.3,
              'maxOutputTokens': 250,
            },
          }),
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final body = jsonDecode(response.body) as Map<String, dynamic>;
          final candidates = body['candidates'] as List?;
          if (candidates != null && candidates.isNotEmpty) {
            final content = candidates[0]['content'] as Map?;
            final parts = content?['parts'] as List?;
            if (parts != null && parts.isNotEmpty) {
              final text = parts[0]['text'] as String?;
              if (text != null && text.trim().isNotEmpty) {
                return text.trim();
              }
            }
          }
        }
      } catch (_) {}
    }

    return fallbackText;
  }

  String _buildFallbackSummary(int cals, int steps, int water, HealthBandData bandData) {
    if (steps >= 8000) {
      return "Fantastic activity today! You've walked $steps steps. Make sure to hydrate with another glass of water and keep your protein intake balanced!";
    } else if (cals < 1200) {
      return "You're doing great! Your calorie intake is currently $cals kcal. Consider a light healthy snack like fruits or curd to keep your energy high!";
    } else {
      return "Welcome to your health dashboard! Track your meals, drink water, and connect your ESP32 Dev Board to unlock real-time pulse and step insights.";
    }
  }

  String _buildFallbackAnswer(String question, int cals, int steps, int water) {
    final q = question.toLowerCase();
    if (q.contains('dinner') || q.contains('food') || q.contains('eat')) {
      return "For dinner, aim for a balanced plate with 20-30g of protein (like paneer, dal, or lean chicken) alongside complex carbs like rotis or brown rice.";
    } else if (q.contains('step') || q.contains('walk') || q.contains('activity')) {
      return "You've completed $steps steps today! A quick 15-minute evening walk will help hit your daily activity goal.";
    } else if (q.contains('water') || q.contains('drink') || q.contains('hydrate')) {
      return "You've logged ${water}ml of water today. Staying hydrated boosts your metabolism and supports cardiovascular health!";
    }
    return "Keep maintaining a steady routine! Remember to log your meals, stay hydrated, and sync your ESP32 hardware band for real-time telemetry.";
  }
}
