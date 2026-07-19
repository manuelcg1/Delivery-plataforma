class AppException implements Exception {
  const AppException(
    this.message, {
    this.code = 'UNKNOWN',
    this.fieldErrors = const {},
  });
  final String message;
  final String code;
  final Map<String, String> fieldErrors;
  @override
  String toString() => message;
}
