/// Classifies "the backend could not be reached" across Firebase plugins.
///
/// The obvious signal is the gRPC status `unavailable`, and on Android and web
/// that is what an unreachable backend produces. **iOS does not.** Measured
/// against a Functions port with no listener, `cloud_functions` on iOS raises a
/// bounded `FirebaseFunctionsException` in ~26ms with:
///
///   code:    `unknown`
///   message: `Could not connect to the server.`
///   details: `null`
///
/// There is no structured field to key on — `details` is null and `plugin` is
/// just `firebase_functions` — so the message is the only available signal.
///
/// Keeping this in one place matters: `ExceptionMapper` and
/// `ShoppingCommandRepositoryImpl` both classify these errors, and when only
/// one of them knew about a shape they disagreed about whether the user was
/// offline.
///
/// Note the deliberate asymmetry: the message check applies **only** to the
/// `unknown` code. A real `permission-denied` must never be laundered into a
/// retryable offline outcome just because its message mentions a connection.
///
/// Limitation, recorded rather than hidden: these strings come from
/// `NSError.localizedDescription` and are localised on a non-English device, so
/// the match can miss. That is strictly no worse than the previous behaviour —
/// a miss falls through to exactly the classification used before this existed.
library;

const _unreachableTransportPhrases = <String>[
  'could not connect to the server',
  'internet connection appears to be offline',
  'specified hostname could not be found',
  'network connection was lost',
  'the request timed out',
  'connection refused',
  'software caused connection abort',
];

/// Whether `code`/`message` describe a backend that could not be reached.
bool isFirebaseBackendUnreachable({required String code, String? message}) {
  if (code == 'unavailable') return true;
  if (code != 'unknown' || message == null) return false;
  final normalized = message.toLowerCase();
  return _unreachableTransportPhrases.any(normalized.contains);
}
