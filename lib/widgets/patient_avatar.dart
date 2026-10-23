// lib/widgets/patient_avatar.dart
//
// Canonical patient avatar — initial letter on a blue tint with a soft ring.
// Replaces the four hand-rolled avatar styles across the app.

import 'package:flutter/material.dart';
import '../theme.dart';

class PatientAvatar extends StatelessWidget {
  final String name;
  final double size;

  /// Render in white-on-translucent style for use on top of the blue
  /// brand gradient (e.g. inside the patient-profile hero card).
  final bool onGradient;

  const PatientAvatar({
    super.key,
    required this.name,
    this.size = 48,
    this.onGradient = false,
  });

  String get _initial =>
      name.isEmpty ? '?' : name.trim()[0].toUpperCase();

  @override
  Widget build(BuildContext context) {
    final bg     = onGradient ? Colors.white.withValues(alpha: 0.18) : kBlue50;
    final fg     = onGradient ? Colors.white : kPrimaryDark;
    final border = onGradient
        ? Colors.white.withValues(alpha: 0.35)
        : const Color(0xFFD1DDF4);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: border, width: 1),
      ),
      alignment: Alignment.center,
      child: Text(
        _initial,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.38,
        ),
      ),
    );
  }
}
