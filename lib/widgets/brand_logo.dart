// lib/widgets/brand_logo.dart
//
// The canonical NurseAssist heart + plus mark.
// Replaces the four hand-rolled logo variations across the app.
//
//     BrandLogo(size: 80)              // login/registration tile
//     BrandLogo(size: 32, onGradient: true)  // dashboard hero chip
//     BrandLogo(size: 200, glassy: true)     // splash hero

import 'package:flutter/material.dart';
import '../theme.dart';

class BrandLogo extends StatelessWidget {
  /// Outer tile size in logical pixels.
  final double size;

  /// When true, the tile is a translucent white chip designed to sit
  /// on top of the blue brand gradient (e.g. inside the dashboard hero).
  final bool onGradient;

  /// When true, the tile uses the lifted glassy treatment used on the
  /// splash screen (large rounded tile, deep blue heart, soft shadow).
  final bool glassy;

  const BrandLogo({
    super.key,
    this.size = 80,
    this.onGradient = false,
    this.glassy = false,
  });

  @override
  Widget build(BuildContext context) {
    // Token defaults
    Color tileColor;
    Color heartColor;
    Color plusColor;
    BorderRadius radius = BorderRadius.circular(size * 0.25);
    List<BoxShadow>? shadow;

    if (onGradient) {
      tileColor  = Colors.white.withValues(alpha: 0.20);
      heartColor = Colors.white;
      plusColor  = kPrimary;
    } else if (glassy) {
      tileColor  = kBlue50;
      heartColor = kPrimaryDark;
      plusColor  = Colors.white;
      radius     = BorderRadius.circular(size * 0.18);
      shadow     = [
        BoxShadow(
          color: const Color(0xFFB6C5DB).withValues(alpha: 0.30),
          blurRadius: size * 0.15,
          offset: Offset(0, size * 0.08),
        ),
      ];
    } else {
      tileColor  = kPrimary;
      heartColor = Colors.white;
      plusColor  = kPrimary;
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tileColor,
        borderRadius: radius,
        boxShadow: shadow,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Filled heart (never outlined — that's a brand inconsistency to avoid)
          Icon(
            Icons.favorite_rounded,
            color: heartColor,
            size: size * 0.55,
          ),
          // Centered plus inside the heart
          Text(
            '+',
            style: TextStyle(
              color: plusColor,
              fontSize: size * 0.22,
              fontWeight: FontWeight.w800,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}
