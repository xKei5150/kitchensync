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

This boots isolated Firestore and Storage emulators, runs both production and
development rule profiles, and shuts them down. The runner defaults to
`127.0.0.1:18080` for Firestore and `127.0.0.1:19199` for Storage; override
them with `FIRESTORE_EMULATOR_HOST` and `FIREBASE_STORAGE_EMULATOR_HOST` if
needed.
