// lib/widgets/primary_fab.dart
//
// The canonical "create new" CTA used on dashboard, patient list, and
// patient profile. Replaces the three different create-button styles.

import 'package:flutter/material.dart';
import '../theme.dart';

class PrimaryFAB extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const PrimaryFAB({
    super.key,
    required this.label,
    this.icon = Icons.add_rounded,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: kPrimary,
        foregroundColor: kOnPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        elevation: 6,
        shadowColor: kPrimaryDark.withValues(alpha: 0.40),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999), // full pill — FAB convention
        ),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }
}
