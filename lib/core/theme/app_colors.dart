import 'package:flutter/material.dart';

/// Token màu dùng chung toàn app — mọi widget PHẢI dùng các const này,
/// không hard-code Color(...) rải rác trong feature code.
class AppColors {
  AppColors._();

  // Nền & bề mặt
  static const bg = Color(0xFFF7F7F5);
  static const surface = Color(0xFFFFFFFF);

  // Chữ
  static const text = Color(0xFF1F2421);
  static const textSecondary = Color(0xFF6B7069);

  // Thương hiệu
  static const primary = Color(0xFF2F7D4F);
  static const primaryHover = Color(0xFF255F3D); // dùng cho pressed, không có hover thật trên mobile

  // Trạng thái
  static const accent = Color(0xFFE7A33E);
  static const danger = Color(0xFFC24444);
  static const success = Color(0xFF2F7D4F);

  static const border = Color(0xFFE1E3DE);

  // Bản tối — dùng cùng cấu trúc token, chỉ đổi giá trị
  static const bgDark = Color(0xFF14171A);
  static const surfaceDark = Color(0xFF1D2124);
  static const textDark = Color(0xFFEDEFEC);
  static const textSecondaryDark = Color(0xFFA3A9A3);
  static const borderDark = Color(0xFF2C3134);
}
