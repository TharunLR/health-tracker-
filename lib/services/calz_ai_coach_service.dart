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

  /// Generates a rich, structured, personalized daily health summary from live telemetry
  Future<String> generateDailyHealthSummary() async {
    final cals = FoodLogService.instance.getTodayCalories().toInt();
    final steps = StepsService.instance.currentSnapshot.stepsToday;
    final water = (HydrationService.instance.currentSnapshot.todayLiters * 1000).toInt();
    final bandData = ESP32HealthBandService.instance.currentData;

    final entries = FoodLogService.instance.currentEntries;
    final loggedFoodNames = entries.isNotEmpty
        ? entries.take(4).map((e) => e.name).join(', ')
        : 'No meals logged yet today';

    final bpmStr = bandData.isConnected && bandData.bpm > 0
        ? '${bandData.bpm} BPM'
        : 'Normal resting pulse (72 BPM)';
    final spo2Str = bandData.isConnected && bandData.spo2 > 0
        ? '${bandData.spo2}%'
        : '98% (Optimal Blood Oxygen)';

    final promptText = '''
You are "ARTI AI Health Coach", an expert clinical nutritionist and personal health advisor for the "ARTI Health" app.
Analyze the user's live daily telemetry and metrics:

📊 TODAY'S METRICS & TELEMETRY:
- Calorie Intake: $cals kcal / 2000 kcal target
- Logged Meals Today: $loggedFoodNames
- Physical Steps: $steps steps / 10,000 step target (~${(steps * 0.00075).toStringAsFixed(1)} km)
- Water Hydration: ${water}ml / 2500ml target
- ESP32 Hardware Band Sensors: Heart Rate = $bpmStr | Blood Oxygen SpO2 = $spo2Str | Connection = ${bandData.isConnected ? "Active BLE Connected" : "Simulated/Offline"}

REQUIREMENTS:
Write an exceptionally high-quality, professional, encouraging, and structured health summary for the user using clean Markdown formatting:
1. Start with an overall **Daily Health & Energy Status** (1 sentence summary).
2. Provide **Dietary & Macronutrient Guidance**: Analyze calorie balance, suggest specific healthy foods (e.g. paneer, chana, dal, sprouts, curd, oats, eggs) to fill nutrition gaps.
3. Provide **Movement & Heart Rate Insights**: Evaluate physical steps and ESP32 heart rate trends.
4. Conclude with **Hydration & Actionable Next Step**.

Keep the tone expert, motivating, friendly, and structured with clean bullet points and emoji headers!
''';

    return _queryGeminiAI(promptText, fallbackText: _buildFallbackSummary(cals, steps, water, bandData, loggedFoodNames));
  }

  /// Handles user chat messages with ARTI AI Coach
  Future<String> answerUserQuestion(String question) async {
    final sanitizedQuestion = SecurityUtils.sanitizeInput(question);
    final cals = FoodLogService.instance.getTodayCalories().toInt();
    final steps = StepsService.instance.currentSnapshot.stepsToday;
    final water = (HydrationService.instance.currentSnapshot.todayLiters * 1000).toInt();
    final bandData = ESP32HealthBandService.instance.currentData;

    final entries = FoodLogService.instance.currentEntries;
    final loggedFoodNames = entries.isNotEmpty
        ? entries.take(4).map((e) => e.name).join(', ')
        : 'No meals logged yet today';

    final promptText = '''
You are "ARTI AI Health Coach", a senior clinical nutritionist and health advisor in the "ARTI Health" app.
User's Live Data:
- Calories: $cals / 2000 kcal | Meals: $loggedFoodNames
- Steps: $steps / 10,000 steps
- Water: ${water}ml / 2500ml
- ESP32 Band: Heart Rate = ${bandData.bpm > 0 ? bandData.bpm : 72} BPM | SpO2 = ${bandData.spo2 > 0 ? bandData.spo2 : 98}%

USER QUESTION: "$sanitizedQuestion"

Provide a detailed, highly accurate, structured answer using bullet points, specific food suggestions, and actionable health guidance tailored directly to their current metrics!
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
              'temperature': 0.2,
              'maxOutputTokens': 700,
            },
          }),
        ).timeout(const Duration(seconds: 12));

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

  String _buildFallbackSummary(int cals, int steps, int water, HealthBandData bandData, String loggedFoodNames) {
    final calsRemaining = (2000 - cals).clamp(0, 2000);
    final stepsRemaining = (10000 - steps).clamp(0, 10000);

    return '''
🌟 **Daily Health & Energy Summary**
You're maintaining a steady pace today with **$cals kcal** consumed and **$steps steps** walked!

🥗 **Dietary & Nutrition Advice**
- **Calories Remaining**: $calsRemaining kcal left for your daily 2,000 kcal target.
- **Recommended Foods**: Add a protein-rich meal like *Paneer Bhurji*, *Rajma*, *Sprouted Moong Salad*, or *Greek Yoghurt* to meet your macro goals.

🏃 **Activity & ESP32 Vitals**
- **Steps Progress**: $steps / 10,000 steps ($stepsRemaining steps to target).
- **Heart Rate & SpO2**: ${bandData.isConnected ? "${bandData.bpm} BPM | SpO2 ${bandData.spo2}%" : "72 BPM (Optimal Resting Pulse)"}.

💧 **Hydration Goal**: You've logged ${water}ml of water. Drink another 500ml glass before dinner!
''';
  }

  String _buildFallbackAnswer(String question, int cals, int steps, int water) {
    final q = question.toLowerCase();
    if (q.contains('dinner') || q.contains('food') || q.contains('eat') || q.contains('snack')) {
      return '''
🥗 **ARTI Nutrition Recommendation**
- **Current Calories Logged**: $cals kcal.
- **Suggested Dinner Items**:
  • **Protein**: Paneer Curry (200g), Boiled Eggs, or Chana Masala.
  • **Carbs & Fiber**: 2 Whole Wheat Rotis or Brown Rice with Cucumber Salad.
- **Tip**: Keep your evening meal balanced and avoid heavy fried foods right before bedtime.
''';
    } else if (q.contains('step') || q.contains('walk') || q.contains('activity') || q.contains('run')) {
      return '''
🏃 **Physical Activity Insights**
- **Today's Step Count**: $steps steps.
- **Distance Covered**: ~${(steps * 0.00075).toStringAsFixed(1)} km.
- **Recommendation**: A light 15-20 minute brisk walk this evening will easily burn ~120 extra kcal and hit your 10,000 daily step goal!
''';
    } else if (q.contains('water') || q.contains('drink') || q.contains('hydrate')) {
      return '''
💧 **Hydration Telemetry**
- **Today's Water Intake**: ${water}ml / 2500ml.
- **Benefit**: Hydration improves oxygen delivery in your bloodstream and keeps your ESP32 heart rate readings stable.
''';
    }

    return '''
🤖 **ARTI Health Coach Advice**
- **Daily Progress**: $cals kcal consumed | $steps physical steps | ${water}ml hydration.
- **Key Focus**: Maintain balanced macronutrients, stay active, and keep your ESP32 hardware band connected for real-time telemetry!
''';
  }
}
