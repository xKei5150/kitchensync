import 'dart:async';

import 'package:google_fonts/google_fonts.dart';

/// Global test bootstrap (auto-discovered by `flutter test`).
///
/// Disables google_fonts runtime HTTP fetching. The Fraunces and DM Sans
/// families are bundled as assets (see pubspec.yaml), so google_fonts resolves
/// them from the asset font manifest with no network access — widget tests get
/// deterministic typography instead of flaky, sandbox-blocked font downloads.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  await testMain();
}
