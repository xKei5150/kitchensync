import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Screenshot-collecting driver. Run a target with:
///   flutter drive \
///     --driver=integration_test/test_driver/integration_test.dart \
///     --target=integration_test/<name>_test.dart -d <device>
/// Captured frames land in screenshots/<name>.png.
Future<void> main() async {
  await integrationDriver(
    onScreenshot: (name, bytes, [args]) async {
      final file = File('screenshots/$name.png');
      await file.create(recursive: true);
      await file.writeAsBytes(bytes);
      return true;
    },
  );
}
