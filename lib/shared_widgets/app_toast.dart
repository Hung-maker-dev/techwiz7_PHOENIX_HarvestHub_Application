import 'toast_queue.dart';

/// API công khai — gọi được từ bất kỳ đâu (provider, repository, widget)
/// miễn `ToastOverlay` đã được mount ở gốc cây widget trong app.dart.
///
/// Ví dụ: `Toast.success('Đã lưu thành công')`.
class Toast {
  Toast._();

  static void success(String message) {
    toastOverlayKey.currentState?.push(message, ToastType.success);
  }

  static void error(String message) {
    toastOverlayKey.currentState?.push(message, ToastType.error);
  }
}
