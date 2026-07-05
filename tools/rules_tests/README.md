# rules_tests

Security-rules unit tests using `@firebase/rules-unit-testing`.

## Setup

```bash
cd tools/rules_tests
npm install
```

## Run

```bash
npm test
```

This boots the Firestore emulator, runs the rules under `../../firestore.rules`, and shuts the emulator down. The runner defaults to `127.0.0.1:18080`; set `FIRESTORE_EMULATOR_HOST=127.0.0.1:<port>` if that port is busy.
