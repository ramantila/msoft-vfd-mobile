import 'package:dio/dio.dart';

import '../../features/auth/services/session_manager.dart';
import 'api_config.dart';
import 'api_exception.dart';

/// Singleton Dio wrapper for the CSP backend: injects the bearer token on
/// every request and maps CSP's GlobalExceptionHandler error body into
/// [ApiException] on failure.
class ApiClient {
  ApiClient._internal() : dio = _buildDio();

  static final ApiClient instance = ApiClient._internal();

  final Dio dio;

  static Dio _buildDio() {
    final dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: ApiConfig.connectTimeout,
      receiveTimeout: ApiConfig.receiveTimeout,
      contentType: 'application/json',
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await SessionManager.instance.readToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        handler.next(_mapError(error));
      },
    ));

    return dio;
  }

  static DioException _mapError(DioException error) {
    final response = error.response;
    final data = response?.data;

    String message = error.message ?? 'Network error';
    Map<String, String>? fieldErrors;
    String? correlationId;

    if (data is Map) {
      final rawMessage = data['message'];
      if (rawMessage is String && rawMessage.isNotEmpty) message = rawMessage;

      final rawFieldErrors = data['fieldErrors'];
      if (rawFieldErrors is Map) {
        fieldErrors = rawFieldErrors.map(
          (key, value) => MapEntry(key.toString(), value.toString()),
        );
      }

      correlationId = data['correlationId'] as String?;
    } else if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError) {
      message = 'Could not reach the server. Check your connection and try again.';
    }

    return error.copyWith(
      error: ApiException(
        message: message,
        statusCode: response?.statusCode,
        fieldErrors: fieldErrors,
        correlationId: correlationId,
      ),
    );
  }
}

/// Unwraps the [ApiException] a caller should actually catch, since Dio
/// wraps thrown errors in [DioException.error].
extension DioExceptionX on DioException {
  ApiException toApiException() {
    final wrapped = error;
    if (wrapped is ApiException) return wrapped;
    return ApiException(message: message ?? 'Unexpected error');
  }
}
