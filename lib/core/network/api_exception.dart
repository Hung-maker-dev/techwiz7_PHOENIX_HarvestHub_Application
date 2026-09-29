import 'package:dio/dio.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final Object? cause;

  const ApiException(this.message, {this.statusCode, this.cause});

  bool get isNetworkError => statusCode == null;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

ApiException mapDioError(DioException error) {
  final statusCode = error.response?.statusCode;
  final payload = error.response?.data;
  final serverMessage =
      payload is Map ? payload['message'] ?? payload['error'] : null;
  if (error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.sendTimeout ||
      error.type == DioExceptionType.receiveTimeout ||
      error.type == DioExceptionType.connectionError) {
    return ApiException('Không có kết nối tới máy chủ.', cause: error);
  }
  return ApiException(
    serverMessage is String && serverMessage.isNotEmpty
        ? serverMessage
        : error.message ?? 'Đã xảy ra lỗi không xác định.',
    statusCode: statusCode,
    cause: error,
  );
}
