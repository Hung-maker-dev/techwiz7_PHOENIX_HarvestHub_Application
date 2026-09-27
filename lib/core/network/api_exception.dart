import 'package:dio/dio.dart';

/// Lỗi API chuẩn hoá — repository/provider bắt lỗi này thay vì DioException
/// thô, để UI hiển thị thông báo nhất quán (vd toast lỗi, pattern #4).
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final Object? cause;

  const ApiException(this.message, {this.statusCode, this.cause});

  /// Không có mạng / timeout — UI nên phân biệt với lỗi 4xx/5xx để có thể
  /// gợi ý "dùng dữ liệu ngoại tuyến" thay vì chỉ báo lỗi chung chung.
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
