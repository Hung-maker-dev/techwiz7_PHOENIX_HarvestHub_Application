import 'toast_queue.dart';

class Toast {
  Toast._();

  static void success(String message) {
    toastOverlayKey.currentState?.push(message, ToastType.success);
  }

  static void error(String message) {
    toastOverlayKey.currentState?.push(message, ToastType.error);
  }
}
