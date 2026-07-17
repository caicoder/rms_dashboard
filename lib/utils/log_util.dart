import 'package:flutter/foundation.dart';

class LogUtil {
  static void d(String message) {
    if (kDebugMode) {
      debugPrint("[DEBUG] $message");
    }
  }

  static void e(String message, [dynamic error]) {
    debugPrint("[ERROR] $message${error != null ? '\nError: $error' : ''}");
  }

  static void v(String message) {
    if (kDebugMode) {
      debugPrint("[VERBOSE] $message");
    }
  }
}
