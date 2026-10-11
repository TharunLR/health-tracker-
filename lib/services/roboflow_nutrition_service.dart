import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/indian_meal_result.dart';
import '../utils/security_utils.dart';

class RoboflowNutritionService {
  RoboflowNutritionService._();

  static final RoboflowNutritionService instance = RoboflowNutritionService._();

  // Configurable backend URL. Defaults to local Express proxy backend or Cloud Run FastAPI endpoint.
  static String backendUrl = 'http://127.0.0.1:3000/analyze-meal';

  /// Analyzes image bytes (supports Web, Android, iOS, Windows)
  Future<IndianMealResult> analyzeMealBytes(
    Uint8List imageBytes, {
    String filename = 'meal.jpg',
    double confidenceThreshold = 0.5,
  }) async {
    final candidateUrls = <String>{
      backendUrl,
      if (backendUrl.contains('127.0.0.1'))
        backendUrl.replaceFirst('127.0.0.1', '10.0.2.2'),
      if (backendUrl.contains('localhost'))
        backendUrl.replaceFirst('localhost', '10.0.2.2'),
    }.toList();

    for (final targetUrl in candidateUrls) {
      try {
        final uri = Uri.parse(targetUrl);
        final request = http.MultipartRequest('POST', uri);

        request.files.add(
          http.MultipartFile.fromBytes(
            'image',
            imageBytes,
            filename: filename,
          ),
        );

        final streamedResponse =
            await request.send().timeout(const Duration(seconds: 25));
        final response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final result = IndianMealResult.fromMap(data);

          if (result.items.isNotEmpty) {
            final filteredItems = result.items
                .where((item) => (item.confidence ?? 1.0) >= confidenceThreshold)
                .toList();

            if (filteredItems.length != result.items.length) {
              return IndianMealResult(
                success: result.success,
                totals: result.totals,
                items: filteredItems,
                scaleReference: result.scaleReference,
                referenceObject: result.referenceObject,
                disclaimer: result.disclaimer,
                error: result.error,
              );
            }
          }

          return result;
        } else {
          return IndianMealResult(
            success: false,
            totals: const IndianMealTotals(
              totalCaloriesKcal: 0,
              totalProteinG: 0,
              totalCarbsG: 0,
              totalFatG: 0,
            ),
            items: const [],
            error: 'Server Error (${response.statusCode}): ${response.body}',
          );
        }
      } catch (_) {}
    }

    // Direct AI Vision analysis using obfuscated API key getter
    return _analyzeWithDirectAIVision(imageBytes);
  }

  /// Analyzes meal description in text format with optional portion in grams
  Future<IndianMealResult> analyzeMealText(
    String foodText, {
    double? portionGrams,
  }) async {
    final sanitizedFood = SecurityUtils.sanitizeInput(foodText);
    final sanitizedGrams = portionGrams != null ? SecurityUtils.sanitizeNumeric(portionGrams) : null;
    final apiKey = SecurityUtils.geminiApiKey;

    final candidateModels = [
      'gemini-3.5-flash',
      'gemini-3.8-flash',
      'gemini-3.5-flash-lite',
      'gemini-3.7-flash',
    ];

    final weightStr = sanitizedGrams != null && sanitizedGrams > 0
        ? 'The user specified a total portion weight of ${sanitizedGrams.toInt()} grams.'
        : 'The user did not specify exact weight, estimate a typical serving weight in grams.';

    final promptText = '''
The user ate the following meal: "$sanitizedFood".
$weightStr
Calculate accurate calories and macronutrients (protein, carbs, fat in grams) for this specified food and weight.
Respond STRICTLY with a valid JSON object adhering to this schema:
{
  "success": true,
  "totals": {
    "total_calories_kcal": 350.0,
    "total_protein_g": 15.0,
    "total_carbs_g": 45.0,
    "total_fat_g": 10.0
  },
  "items": [
    {
      "name": "Food item name",
      "estimated_weight_g": 250.0,
      "calories_kcal": 350.0,
      "protein_g": 15.0,
      "carbs_g": 45.0,
      "fat_g": 10.0,
      "category": "Custom Entry",
      "notes": "Text description entry"
    }
  ],
  "disclaimer": "AI text estimated portion & nutrition."
}
''';

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
              'responseMimeType': 'application/json',
            },
          }),
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final body = jsonDecode(response.body) as Map<String, dynamic>;
          final candidates = body['candidates'] as List?;
          if (candidates != null && candidates.isNotEmpty) {
            final content = candidates[0]['content'] as Map?;
            final parts = content?['parts'] as List?;
            if (parts != null && parts.isNotEmpty) {
              final text = parts[0]['text'] as String?;
              if (text != null && text.trim().isNotEmpty) {
                final start = text.indexOf('{');
                final end = text.lastIndexOf('}');
                if (start != -1 && end > start) {
                  final jsonPayload =
                      jsonDecode(text.substring(start, end + 1)) as Map<String, dynamic>;
                  final result = IndianMealResult.fromMap(jsonPayload);
                  if (!result.isFood || !result.success) {
                    return result;
                  }
                  if (!result.isFood || !result.success) {
                    return result;
                  }
                  if (!result.isFood || !result.success) {
                    return result;
                  }
                  if (result.items.isNotEmpty || result.totals.totalCaloriesKcal > 0) {
                    return result;
                  }
                }
              }
            }
          }
        }
      } catch (_) {
        // Try next candidate model
      }
    }

    // Fallback smart calculation if offline or network failure
    final double weight = (sanitizedGrams != null && sanitizedGrams > 0) ? sanitizedGrams : 200.0;
    final double estimatedCals = (weight * 1.5).roundToDouble();
    final double estimatedProtein = (weight * 0.06).roundToDouble();
    final double estimatedCarbs = (weight * 0.20).roundToDouble();
    final double estimatedFat = (weight * 0.05).roundToDouble();

    return IndianMealResult(
      success: true,
      totals: IndianMealTotals(
        totalCaloriesKcal: estimatedCals,
        totalProteinG: estimatedProtein,
        totalCarbsG: estimatedCarbs,
        totalFatG: estimatedFat,
      ),
      items: [
        IndianMealItem(
          name: sanitizedFood.isNotEmpty ? sanitizedFood : 'Manual Meal Entry',
          portionGrams: weight,
          caloriesKcal: estimatedCals,
          proteinG: estimatedProtein,
          carbG: estimatedCarbs,
          fatG: estimatedFat,
          category: 'Manual Entry',
          notes: 'Estimated based on $weight g portion',
        ),
      ],
      disclaimer: 'Portion & nutrition calculated from text entry.',
    );
  }

  Future<IndianMealResult> _analyzeWithDirectAIVision(Uint8List imageBytes) async {
    final apiKey = SecurityUtils.geminiApiKey;
    final candidateModels = [
      'gemini-3.5-flash',
      'gemini-3.8-flash',
      'gemini-3.5-flash-lite',
      'gemini-3.7-flash',
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
                  {
                    'text': '''
Carefully inspect this image as an AI nutritional assistant.
Step 1: Check if the image contains edible food, cooked dishes, fruits, vegetables, snacks, or drinks.
If the image DOES NOT contain food (for example, if it shows people, faces, crowds, selfies, clothing, buildings, animals, cars, paper/documents, electronic devices, furniture, or non-food objects):
You MUST respond STRICTLY in JSON:
{
  "is_food": false,
  "success": false,
  "error": "No food detected in this image. Please take or upload a clear photo of your meal or food dish."
}

Step 2: If the image DOES contain genuine edible food:
Identify all visible food items, estimate reasonable portion weights in grams, calories, and macronutrients (protein, carbs, fat in grams).
Respond STRICTLY with valid JSON:
{
  "is_food": true,
  "success": true,
  "totals": {
    "total_calories_kcal": 420.0,
    "total_protein_g": 22.0,
    "total_carbs_g": 54.0,
    "total_fat_g": 12.0
  },
  "items": [
    {
      "name": "Food item name",
      "estimated_weight_g": 250.0,
      "calories_kcal": 420.0,
      "protein_g": 22.0,
      "carbs_g": 54.0,
      "fat_g": 12.0,
      "category": "Main Dish",
      "notes": "Estimated portion"
    }
  ],
  "disclaimer": "AI Vision estimated portion & nutrition."
}
''',
                  },
                  {
                    'inlineData': {
                      'mimeType': 'image/jpeg',
                      'data': base64Encode(imageBytes),
                    },
                  },
                ],
              },
            ],
            'generationConfig': {
              'temperature': 0.2,
              'responseMimeType': 'application/json',
            },
          }),
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final body = jsonDecode(response.body) as Map<String, dynamic>;
          final candidates = body['candidates'] as List?;
          if (candidates != null && candidates.isNotEmpty) {
            final content = candidates[0]['content'] as Map?;
            final parts = content?['parts'] as List?;
            if (parts != null && parts.isNotEmpty) {
              final text = parts[0]['text'] as String?;
              if (text != null && text.trim().isNotEmpty) {
                final start = text.indexOf('{');
                final end = text.lastIndexOf('}');
                if (start != -1 && end > start) {
                  final jsonPayload =
                      jsonDecode(text.substring(start, end + 1)) as Map<String, dynamic>;
                  final result = IndianMealResult.fromMap(jsonPayload);
                  if (result.items.isNotEmpty || result.totals.totalCaloriesKcal > 0) {
                    return result;
                  }
                }
              }
            }
          }
        }
      } catch (_) {
        // Try next candidate model
      }
    }

    // Never return fake food fallback for non-food or failed scans!
    return const IndianMealResult(
      success: false,
      isFood: false,
      totals: IndianMealTotals(
        totalCaloriesKcal: 0,
        totalProteinG: 0,
        totalCarbsG: 0,
        totalFatG: 0,
      ),
      items: [],
      error: 'Unable to detect food in this image. Please take a clear, well-lit photo of your meal or use the text entry option.',
    );
  }
}
