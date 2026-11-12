/// Typed error mapped from CSP's GlobalExceptionHandler response body:
/// { timestamp, status, error, message, correlationId, fieldErrors? }
class ApiException implements Exception {
  final int? statusCode;
  final String message;
  final Map<String, String>? fieldErrors;
  final String? correlationId;

  const ApiException({
    required this.message,
    this.statusCode,
    this.fieldErrors,
    this.correlationId,
  });

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isValidation => fieldErrors != null && fieldErrors!.isNotEmpty;

  @override
  String toString() => message;
}
