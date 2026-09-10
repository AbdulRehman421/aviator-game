import 'package:flutter/material.dart';

class AppColors {
  static const bg = Color(0xFF0E0E0E);
  static const panel = Color(0xFF1B1C1D);
  static const panelAlt = Color(0xFF141516);
  static const field = Color(0xFF000000);
  static const border = Color(0xFF2C2D30);
  static const red = Color(0xFFE50539);
  static const orange = Color(0xFFD07206);
  static const green = Color(0xFF28A909);
  static const blue = Color(0xFF34B4FF);
  static const purple = Color(0xFF913EF8);
  static const pink = Color(0xFFC017B4);

  static Color forMultiplier(double m) =>
      m < 2 ? blue : (m < 10 ? purple : pink);
}

String money(double v) {
  final negative = v < 0;
  final fixed = v.abs().toStringAsFixed(2);
  final dot = fixed.indexOf('.');
  final intPart = fixed.substring(0, dot);
  final buf = StringBuffer();
  for (var i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) buf.write(',');
    buf.write(intPart[i]);
  }
  return '${negative ? '-' : ''}$buf${fixed.substring(dot)}';
}

String pkr(double v) => '${money(v)} PKR';
String multiplierText(double m) => '${m.toStringAsFixed(2)}x';
