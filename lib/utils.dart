import 'package:flutter/material.dart';

final List<Color> colors = [
  Colors.red,
  Colors.green,
  Colors.blue,
  Colors.orange,
  Colors.yellow,
  Colors.purple,
];

String formatTime(int seconds) {
  final minutes = seconds ~/ 60;
  final remainingSeconds = seconds % 60;
  return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
}

bool listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}