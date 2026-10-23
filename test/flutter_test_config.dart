import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Runs before every test file. Loads the real Roboto font (Android's
/// default, and what the app uses) from the Flutter SDK so widget tests
/// measure text the way a phone does. Without this, the test font draws
/// every letter as a full-width square and reports overflows that never
/// happen on a device.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();

  final fontsDir = Directory(
    '${_flutterRoot()}/bin/cache/artifacts/material_fonts',
  );
  if (fontsDir.existsSync()) {
    final roboto = FontLoader('Roboto');
    for (final file in fontsDir.listSync().whereType<File>()) {
      final name = file.uri.pathSegments.last;
      if (name.startsWith('roboto-') && name.endsWith('.ttf')) {
        final bytes = file.readAsBytesSync();
        roboto.addFont(Future.value(ByteData.sublistView(bytes)));
      }
    }
    await roboto.load();
  }

  await testMain();
}

/// Flutter SDK root, found from the running Dart executable
/// (<flutter>/bin/cache/dart-sdk/bin/dart).
String _flutterRoot() {
  final env = Platform.environment['FLUTTER_ROOT'];
  if (env != null && env.isNotEmpty) return env;
  return File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.path;
}
