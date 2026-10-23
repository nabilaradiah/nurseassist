// lib/theme.dart
//
// NurseAssist — single source of truth for colors, type, spacing, shadows.
// Import this from every screen and use the tokens instead of inline hex values.
//
//     import '../theme.dart';
//     Container(color: kBgCanvas)
//     Text('Title', style: kH1)
//
// Mirrors colors_and_type.css from the design system.

import 'package:flutter/material.dart';

// ════════════════════════════════════════════════════════════════
//  COLORS
// ════════════════════════════════════════════════════════════════

// ── Brand blue scale ───────────────────────────────────────────
const Color kBlue50  = Color(0xFFEAF0FA);
const Color kBlue100 = Color(0xFFE8EFFF);
const Color kBlue200 = Color(0xFFD2DCE9);
const Color kBlue400 = Color(0xFF3C87F4);
const Color kBlue600 = Color(0xFF2F65DE);
const Color kBlue700 = Color(0xFF2F6DEB); // ★ canonical primary
const Color kBlue800 = Color(0xFF0E5CC3);

/// THE primary brand blue. Use this for all primary CTAs, focus rings,
/// FABs and brand-gradient stops. Replaces the six different blues that
/// were scattered across the app.
const Color kPrimary      = kBlue700;
const Color kPrimaryDark  = kBlue800;
const Color kOnPrimary    = Colors.white;

// ── Surfaces & neutrals ────────────────────────────────────────
const Color kBgCanvas  = Color(0xFFF0F4F8); // primary page bg — use everywhere
const Color kBgLifted  = Color(0xFFEEF2FF); // accent bg (modals, sheets)
const Color kBgInput   = Color(0xFFF5F7FB); // input fill
const Color kSurface   = Color(0xFFFFFFFF);

const Color kInk1   = Color(0xFF111827); // primary text
const Color kInk2   = Color(0xFF1B2636); // heading variant
const Color kMuted1 = Color(0xFF607085); // secondary text
const Color kMuted2 = Color(0xFF6C7483); // tertiary / spaced caps
const Color kMuted3 = Color(0xFF94A3B8); // placeholder
const Color kLine   = Color(0xFFDCE3EE); // hairline divider

// ── Severity (clinical signal — Mild / Moderate / Critical) ────
const Color kSevMild        = Color(0xFF2E7D32);
const Color kSevMildBg      = Color(0xFFE8F5E9);
const Color kSevModerate    = Color(0xFFE65100);
const Color kSevModerateBg  = Color(0xFFFFF3E0);
const Color kSevCritical    = Color(0xFFD32F2F);
const Color kSevCriticalBg  = Color(0xFFFFEBEB);

// ── Aliases for snackbar / dialog colors ───────────────────────
const Color kSuccess   = kSevMild;
const Color kSuccessBg = kSevMildBg;
const Color kWarning   = kSevModerate;
const Color kWarningBg = kSevModerateBg;
const Color kDanger    = kSevCritical;
const Color kDangerBg  = kSevCriticalBg;

// ── Role accents ───────────────────────────────────────────────
const Color kTeal600   = Color(0xFF128A74);
const Color kTeal50    = Color(0xFFE3F5F1);
const Color kPurple600 = Color(0xFF5E35B1);
const Color kPurple400 = Color(0xFF9575CD);

// ── Brand gradients ────────────────────────────────────────────
const LinearGradient kHeroGradient = LinearGradient(
  begin: Alignment.topLeft, end: Alignment.bottomRight,
  colors: [kBlue600, kBlue400],
);
const LinearGradient kLecturerGradient = LinearGradient(
  begin: Alignment.topLeft, end: Alignment.bottomRight,
  colors: [kPurple600, kPurple400],
);

// ════════════════════════════════════════════════════════════════
//  RADII
// ════════════════════════════════════════════════════════════════
const double kRadiusMd  = 10;
const double kRadiusLg  = 12;
const double kRadiusXl  = 16;
const double kRadius3xl = 28; // hero bottom corners

// ════════════════════════════════════════════════════════════════
//  SHADOWS
// ════════════════════════════════════════════════════════════════
const List<BoxShadow> kShadowSm = [
  BoxShadow(color: Color(0x0D000000), blurRadius: 10, offset: Offset(0, 3)),
];
const List<BoxShadow> kShadowMd = [
  BoxShadow(color: Color(0x0F000000), blurRadius: 12, offset: Offset(0, 4)),
];
final List<BoxShadow> kShadowHero = [
  BoxShadow(color: kBlue600.withValues(alpha: 0.24),
            blurRadius: 16, offset: const Offset(0, 6)),
];
final List<BoxShadow> kShadowLecturer = [
  BoxShadow(color: kPurple600.withValues(alpha: 0.30),
            blurRadius: 14, offset: const Offset(0, 6)),
];

// ════════════════════════════════════════════════════════════════
//  TYPOGRAPHY
// ════════════════════════════════════════════════════════════════
const TextStyle kH1 = TextStyle(
  fontSize: 26, fontWeight: FontWeight.w700,
  height: 1.2, letterSpacing: -0.4, color: kInk2,
);
const TextStyle kH3 = TextStyle(
  fontSize: 18, fontWeight: FontWeight.w700,
  height: 1.25, color: kInk2,
);
const TextStyle kBodySm = TextStyle(
  fontSize: 13, color: kMuted1, height: 1.5,
);

// ════════════════════════════════════════════════════════════════
//  GLOBAL THEMEDATA
//  Apply once in MaterialApp(theme: kNurseAssistTheme).
//  This is what the screens silently rely on (button colors, input
//  decorations, etc.) so individual screens don't need to restate
//  the brand on every widget.
// ════════════════════════════════════════════════════════════════
final ThemeData kNurseAssistTheme = ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: kBgCanvas,
  colorScheme: ColorScheme.fromSeed(
    seedColor: kPrimary,
    primary: kPrimary,
    onPrimary: kOnPrimary,
    error: kDanger,
    surface: kSurface,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: kBgCanvas,
    foregroundColor: kInk2,
    elevation: 0,
    scrolledUnderElevation: 0,
    titleTextStyle: TextStyle(
      color: kInk2, fontSize: 17, fontWeight: FontWeight.w700,
    ),
    iconTheme: IconThemeData(color: kInk2),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: kPrimary,
      foregroundColor: kOnPrimary,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusLg),
      ),
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: kPrimary,
      side: const BorderSide(color: kLine),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusLg),
      ),
      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: kBgInput,
    contentPadding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(kRadiusMd),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(kRadiusMd),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(kRadiusMd),
      borderSide: const BorderSide(color: kBlue400, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(kRadiusMd),
      borderSide: const BorderSide(color: kDanger),
    ),
    hintStyle: const TextStyle(color: kMuted3, fontSize: 14),
  ),
  snackBarTheme: const SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    backgroundColor: kInk2,
    contentTextStyle: TextStyle(color: kOnPrimary, fontSize: 14),
  ),
);

// ════════════════════════════════════════════════════════════════
//  HELPERS — brand snackbars (replace raw Colors.green / red / orange)
// ════════════════════════════════════════════════════════════════
void showSuccessSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(message),
    backgroundColor: kSuccess,
  ));
}

void showWarningSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(message),
    backgroundColor: kWarning,
  ));
}

void showErrorSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(message),
    backgroundColor: kDanger,
  ));
}
