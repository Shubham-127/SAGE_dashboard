import 'package:flutter/material.dart';

/// ALL colours of the app live here.
/// Want a different look? Change a value here and the whole app updates.
/// Colours are written as 0xFF + 6 hex digits (RRGGBB). Example: 0xFF3FD0C9 = teal.
class AppColors {
  static const bg = Color(0xFF0A1118); // page background (deep ink)
  static const panel = Color(0xFF111B26); // cards
  static const panel2 = Color(0xFF16222F); // cards inside cards
  static const border = Color(0xFF223344);
  static const text = Color(0xFFE8EEF4);
  static const muted = Color(0xFF8CA0B3); // grey helper text
  static const accent = Color(0xFF3FD0C9); // teal "pulse" colour
  static const good = Color(0xFF4ADE80); // green  = healthy / success
  static const warn = Color(0xFFFFB347); // amber  = warning / needs a human
  static const bad = Color(0xFFFF6B6B); // red    = down / error
}
