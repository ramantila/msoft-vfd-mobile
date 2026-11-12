import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Base URL for the CSP (customer-sales-portal) backend.
///
/// Override at build/run time with:
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.50:8082
/// (required for physical devices, which can't reach a dev machine via
/// localhost/10.0.2.2).
class ApiConfig {
  ApiConfig._();

  static const _override = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_override.isNotEmpty) return _override;
    // Android emulator maps the host loopback interface to 10.0.2.2, not
    // localhost. iOS simulator, desktop and web can all reach the host
    // machine directly via localhost. 192.168.100.122
    // if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:8082';
    // return 'http://localhost:8082';
    if (!kIsWeb && Platform.isAndroid) return 'http://192.168.100.219:8082';
    return 'http://192.168.100.219:8082';
  }

  static const connectTimeout = Duration(seconds: 15);
  static const receiveTimeout = Duration(seconds: 20);
}
