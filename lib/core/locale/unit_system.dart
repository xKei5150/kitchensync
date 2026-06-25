/// The measurement system the household reads amounts in.
///
/// Recipe and pantry data is authored in [metric]; [imperial] is a display-time
/// conversion applied at the presentation edge, never to stored values.
enum UnitSystem {
  metric('Metric'),
  imperial('Imperial');

  const UnitSystem(this.label);

  /// Human label shown in settings and trailing summaries.
  final String label;

  /// Decodes a persisted value, defaulting to [metric] for anything unknown.
  static UnitSystem decode(String? value) => switch (value) {
    'imperial' => UnitSystem.imperial,
    _ => UnitSystem.metric,
  };
}
