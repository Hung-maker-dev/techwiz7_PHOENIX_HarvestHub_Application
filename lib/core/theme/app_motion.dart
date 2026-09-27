import 'package:flutter/animation.dart';

/// Token thời gian dùng chung — không hard-code Duration(milliseconds: ...)
/// rải rác trong feature code. Xem ANIMATION_SYSTEM_MOBILE.md.
class AppDurations {
  AppDurations._();
  static const micro = Duration(milliseconds: 150); // hover/press/focus
  static const standard = Duration(milliseconds: 250); // modal/sheet/route
  static const emphasis = Duration(milliseconds: 500); // timeline, count-up
  static const toastVisible = Duration(milliseconds: 4000);
  static const toastTransition = Duration(milliseconds: 200);
}

class AppCurves {
  AppCurves._();
  static const easeOut = Cubic(0.22, 1, 0.36, 1); // vào màn hình
  static const easeIn = Cubic(0.4, 0, 1, 1); // ra khỏi màn hình
}
