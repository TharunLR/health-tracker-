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
    final candidateUrls = [
      backendUrl,
      if (backendUrl.contains('127.0.0.1'))
        backendUrl.replaceFirst('127.0.0.1', '10.0.2.2'),
      if (backendUrl.contains('localhost'))
        backendUrl.replaceFirst('localhost', '10.0.2.2'),
    ].toSet().toList();

    Object? lastError;

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
      } catch (e) {
        lastError = e;
      }
    }

    return IndianMealResult(
      success: false,
      totals: const IndianMealTotals(
        totalCaloriesKcal: 0,
        totalProteinG: 0,
        totalCarbsG: 0,
        totalFatG: 0,
      ),
      items: const [],
      error:
          'Backend connection failed. Ensure Node backend is running (cd backend_node && node server.js).\n'
          'For physical Android devices: run "adb reverse tcp:3000 tcp:3000".\n'
          'Details: $lastError',
    );
  }
}
