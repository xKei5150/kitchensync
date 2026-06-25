import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide [SharedPreferences] instance.
///
/// Overridden in `main()` with the already-resolved instance so synchronous
/// reads (e.g. the initial theme mode) are available on the very first frame —
/// no flash of the wrong brightness on cold start.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in main()',
  ),
);
