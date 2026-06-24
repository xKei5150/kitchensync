# Bundled fonts

These files let the `google_fonts` package load **Fraunces** (display) and
**DM Sans** (body) from the app bundle instead of fetching them from Google's
CDN at runtime. The package looks up files in this folder by their exact
weight-name (e.g. `DMSans-SemiBold.ttf`); when found it skips the network
request. Benefits:

- **Deterministic tests** — widget/a11y tests render real type with no flaky,
  sandbox-blocked downloads (paired with `test/flutter_test_config.dart`, which
  sets `GoogleFonts.config.allowRuntimeFetching = false`).
- **Offline app** — no first-launch font flash and no runtime dependency on
  `fonts.gstatic.com`.

The folder is registered as an asset in `pubspec.yaml` under `flutter: assets:`.

## Files

Each `.ttf` is the upstream **variable** font copied under the per-weight name
`google_fonts` requests; Flutter applies the requested weight via the `wght`
axis. Only the weights the app actually uses are bundled:

| Family   | Weights bundled                  | Source role |
|----------|----------------------------------|-------------|
| Fraunces | Medium (500), SemiBold (600)     | display / headline |
| DM Sans  | Regular (400), Medium (500), SemiBold (600), Bold (700) | title / body / label |

## License

Both families are licensed under the SIL Open Font License 1.1; the full text
and copyright notices are in `OFL-Fraunces.txt` and `OFL-DMSans.txt`.
