import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'active_household_id_provider.g.dart';

/// Returns the active household id. Stub: always 'solo-household'.
/// When real auth lands, this provider is reimplemented to derive from the
/// authenticated user's household membership.
@Riverpod(keepAlive: true)
String activeHouseholdId(Ref ref) => 'solo-household';
