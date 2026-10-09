import 'dart:convert';

/// Central Security Utility for Application Hardening
class SecurityUtils {
  SecurityUtils._();

  /// Retrieves the Gemini API key safely, allowing compile-time override via `--dart-define=GEMINI_API_KEY=...`
  /// or decoding at runtime to prevent plain-text key exposure in binary strings/decompilers.
  static String get geminiApiKey {
    const envKey = String.fromEnvironment('GEMINI_API_KEY');
    if (envKey.isNotEmpty) {
      return envKey.trim();
    }
    // Runtime decoded base64 string to hinder static string extraction
    return utf8.decode(
      base64Decode('QVEuQWI4Uk42S1RLUnlsdk5TMFpueGNxYTh0NkM4aWwtRGlseWNXNmFnak5IN01RQ3ZYSlE='),
    );
  }

  /// Sanitizes text input to prevent XSS, script injection, and control character exploits
  static String sanitizeInput(String? input) {
    if (input == null || input.trim().isEmpty) {
      return '';
    }
    return input
        .replaceAll(RegExp(r'[<>]'), '') // Strip dangerous HTML/script tags
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '') // Strip control chars
        .trim();
  }

  /// Validates numeric values to prevent NaN, Infinity, or memory overflow attacks
  static double sanitizeNumeric(double? value, {double max = 100000.0}) {
    if (value == null || value.isNaN || value.isInfinite || value < 0) {
      return 0.0;
    }
    return value > max ? max : value;
  }
}
