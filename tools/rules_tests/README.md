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

This boots the Firestore emulator, runs the rules under `../../firestore.rules`, and shuts the emulator down. Make sure no other emulator instance is running on port 8080.
