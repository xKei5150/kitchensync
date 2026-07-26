# Integration test harness

The iOS integration suite is **37 targets** and it is not uniform. Four targets
need parameters or a companion process, and driving one of them incorrectly
produces a failure that is indistinguishable from a product defect. A sweep on
2026-07-26 reported 10 failures; **six of them were harness errors, not bugs.**

This page and `scripts/run-integration.sh` exist so that nobody has to
rediscover those recipes.

```bash
scripts/run-integration.sh              # every target
scripts/run-integration.sh shopping_mvp_emulator recipe_nav
scripts/run-integration.sh --list       # target names
```

Logs land in `.integration-logs/<target>.log`; the emulator log is
`.integration-logs/emulator.log`.

## The alternate emulator stack

**Never point the suite at the dev emulator.** The sweep restarts the emulator
between targets, which would wipe whatever a developer has running.

`firebase.reverify.json` therefore uses a separate set of ports, and the script
refuses to start if that config ever names a dev port:

| Emulator  | Dev (`firebase.dev.json`) | Suite (`firebase.reverify.json`) |
| --------- | ------------------------- | -------------------------------- |
| auth      | 9099                      | **19099**                        |
| firestore | 8080                      | **18090**                        |
| functions | 5001                      | **15001**                        |
| storage   | 9199                      | **19198**                        |
| ui        | 4000                      | disabled                         |

Every target gets a **freshly restarted** stack, because several write at
deterministic document ids and pass only against a clean database.

Base defines for every target:

```
--dart-define=ENV=dev
--dart-define=USE_EMULATOR=true
--dart-define=FIRESTORE_EMULATOR_PORT=18090
--dart-define=AUTH_EMULATOR_PORT=19099
--dart-define=STORAGE_EMULATOR_PORT=19198
--dart-define=FUNCTIONS_EMULATOR_PORT=15001
```

Device: iPhone 17 Pro `B1177420-2859-43F7-8E26-B3835A85C984`
(override with `INTEGRATION_DEVICE`).

## The four targets that need parameters

Driving any of these without its parameters fails in a way that looks exactly
like a product defect. `scripts/run-integration.sh` supplies all of them.

| Target | Requirement |
| --- | --- |
| `functions_unused_port` | `FUNCTIONS_EMULATOR_PORT` **and** `UNUSED_FUNCTIONS_PORT` set to a port with **nothing listening** (default 56551). Pointed at the live emulator the call succeeds and the "expect an exception" assertion correctly fails. |
| `shopping_mvp_emulator` | `QA_CANONICAL_DATE=YYYY-MM-DD` **and** `FINAL_CAPTURE_SIGNAL_PORT` with a live listener. |
| `shopping_visual_state_matrix` | `VISUAL_CAPTURE_SIGNAL_PORT` with a live listener (it signals up to 3 times). |
| `email_auth_session_restore_emulator` | Runs **twice against one emulator**: `AUTH_SESSION_PHASE=create` then `=restore`, sharing one `AUTH_SESSION_RUN_ID`. A per-target emulator restart destroys the account between phases. |

Two more targets are not mis-parameterised but are environment-sensitive:

| Target | Trap |
| --- | --- |
| `day_view_lifecycle_emulator` | Historically intermittent; re-run in isolation before believing a failure. |
| `calendar_defaults_emulator` | Fails at ~6s if `flutter analyze`/`flutter test` runs concurrently — see below. |

### The capture-signal protocol

The two capture targets do not merely want a port number. The app **connects,
sends one byte, and then blocks on `socket.first` with a 20s timeout**. Without
a listener that *echoes a byte back*, the target hangs for 20s and then fails.

`scripts/capture_signal_server.py` is that listener. It accepts connections
until terminated, so it serves both the single-signal and three-signal targets.

### A listening port is not readiness

Firestore accepts TCP connections before it can serve. A target started in that
window dies at its very first read with

```
[cloud_firestore/unavailable] The service is currently unavailable.
```

which reads exactly like a product defect and is not one. This cost a real
`shopping_mvp_emulator` failure during the 2026-07-26 verification. The runner
therefore waits for all four ports **and** a successful admin read against the
Firestore emulator (200 or 404 both mean "serving") before driving a target.

## Environment traps that cost real time

- **macOS has no `timeout`/`gtimeout`.** The script implements its watchdog
  inline (`run_with_watchdog`); a wedged simulator otherwise blocks forever.
- **Never run `flutter analyze` or `flutter test` while a target is driving.**
  Xcode's SPM resolution is shared per project directory; concurrent access
  corrupts it and produces a bogus ~6s failure that looks like a real defect.
  The script refuses to start when it detects a concurrent flutter process.
- `tools/rules_tests/run-firestore-rules-tests.sh` is **not executable** —
  invoke it with `bash`.

## Planner runtime tests

Three planner tests are skipped by default behind
`LOCAL_PLANNER_INTEGRATION_TEST` and exercise the **real** Dart planner rather
than the emulator stub. They need no Google credentials and no Firestore.

`tools/run-shopping-planner-runtime-qa.sh` already automates this:

1. Starts `services/shopping_allocation_planner` (`dart run bin/server.dart`)
   with `LOCAL_PLANNER_INTEGRATION_TEST=true`, `FUNCTIONS_EMULATOR=true`,
   `LOCAL_PLANNER_OIDC_TOKEN=<any token>`, `PORT=<port>`.
2. Starts the Functions emulator with `LOCAL_PLANNER_INTEGRATION_TEST=true`,
   `LOCAL_PLANNER_URL`, `LOCAL_PLANNER_AUDIENCE` and the same token.
3. Runs `test/emulator/shopping-write-commands/plannerRuntime.test.ts`.

## Screenshot galleries

`p2`/`p3`/`p4`/`p5_gallery` and `recipe_nav` used to build the real router
**without** booting Firebase. Since the 2026-07-22 auth hardening
`firebaseAuthProvider` is null in that setup, the session is
`AppSessionPhase.unavailable`, and the redirect sends every route to
`/onboarding` — so they photographed the sign-in page while claiming to walk
Premium, Pantry, accessibility and recipe surfaces. `p3` and `p5` asserted
nothing at all and therefore passed.

They now boot the same emulator harness as every other target
(`integration_test/_gallery_harness.dart`) and **assert the destination screen
by widget type before each screenshot**, so a redirect fails the target instead
of silently capturing the wrong screen.

### Never cache the `GoRouter` instance

Converting them surfaced a second, independent defect in the same tests.
`routerProvider` watches the session, so Riverpod **rebuilds it** — yielding a
new `GoRouter` — as the session advances. Every gallery pumped

```dart
MaterialApp.router(routerConfig: container.read(routerProvider))  // WRONG
```

which pins the instance that existed at pump time. Its redirect closure still
sees a loading session, so every route stays at `/auth/loading` no matter what
the real session does. `KitchenSyncApp` does not have this problem because it
uses `ref.watch(routerProvider)` inside a `ConsumerWidget`.

Any test that drives the real router must do the same. The harness now pumps a
`ConsumerWidget` that watches the provider, and reads `router` fresh on every
use rather than caching it.
