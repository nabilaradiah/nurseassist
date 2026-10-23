// lib/widgets/load_error_view.dart
//
// Shown in place of a list when loading it failed, so "permission denied"
// or "offline" is never mistaken for "there are no patients".

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../theme.dart';

/// A short, nurse-readable reason for a failed load.
String describeLoadError(Object error) {
  if (error is FirebaseException) {
    switch (error.code) {
      case 'permission-denied':
        return "You don't have permission to view this. Make sure your "
            'email is verified, or ask a lecturer to check your account.';
      case 'unavailable':
      case 'deadline-exceeded':
        return "Can't reach the server. Check your internet connection.";
    }
    return 'Something went wrong (${error.code}).';
  }
  return 'Something went wrong: $error';
}

class LoadErrorView extends StatelessWidget {
  /// What failed to load, e.g. 'patients'.
  final String what;
  final Object error;
  final VoidCallback onRetry;

  const LoadErrorView({
    super.key,
    required this.what,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: kDangerBg,
          borderRadius: BorderRadius.circular(kRadiusLg),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 34, color: kDanger),
            const SizedBox(height: 10),
            Text(
              'Could not load $what',
              textAlign: TextAlign.center,
              style: kH3.copyWith(color: kDanger),
            ),
            const SizedBox(height: 6),
            Text(
              describeLoadError(error),
              textAlign: TextAlign.center,
              style: kBodySm.copyWith(color: kInk2),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: OutlinedButton.styleFrom(
                foregroundColor: kDanger,
                side: const BorderSide(color: kDanger),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
