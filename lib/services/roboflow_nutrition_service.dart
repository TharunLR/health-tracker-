import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/indian_meal_result.dart';

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
    try {
      final uri = Uri.parse(backendUrl);
      final request = http.MultipartRequest('POST', uri);

      // Support both FastAPI ('file') and Node.js proxy ('image') multipart fields
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          imageBytes,
          filename: filename,
        ),
      );
      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          imageBytes,
          filename: filename,
        ),
      );

      // Handle Cloud Run cold starts with a 30 second timeout
      final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final result = IndianMealResult.fromMap(data);

        // Apply confidence threshold filtering if items exist
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
    } catch (e) {
      return IndianMealResult(
        success: false,
        totals: const IndianMealTotals(
          totalCaloriesKcal: 0,
          totalProteinG: 0,
          totalCarbsG: 0,
          totalFatG: 0,
        ),
        items: const [],
        error: 'Network / API Error: $e',
      );
    }
  }
}
