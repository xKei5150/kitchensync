.PHONY: get gen watch analyze test cov format clean run-dev run-prod build-dev build-prod functions-install functions-lint functions-build functions-test functions-test-emulator functions-gate rules-test integration-gate firebase-gates firebase-indexes-list firebase-deploy-dev-backend firebase-rollout-dev emulators-full emulator

get:
	flutter pub get

gen:
	dart run build_runner build --delete-conflicting-outputs

watch:
	dart run build_runner watch --delete-conflicting-outputs

analyze:
	flutter analyze

test:
	flutter test

cov:
	flutter test --coverage
	@echo "Coverage at coverage/lcov.info"

format:
	dart format lib test

clean:
	flutter clean

run-dev:
	flutter run --dart-define=ENV=dev

run-prod:
	flutter run --dart-define=ENV=prod

build-dev:
	flutter build apk --dart-define=ENV=dev --debug

build-prod:
	flutter build appbundle --dart-define=ENV=prod --release

functions-install:
	npm --prefix functions ci

functions-lint:
	npm --prefix functions run lint

functions-build:
	npm --prefix functions run build

functions-test:
	npm --prefix functions test

functions-test-emulator:
	tools/firebase-gates/firebase.sh --config firebase.dev.json emulators:exec --only auth,firestore,functions,storage --project kitchensync-dev-da503 "npm --prefix functions run test:emulator"

functions-gate: functions-install functions-lint functions-build functions-test

rules-test:
	npm --prefix tools/rules_tests ci
	npm --prefix tools/rules_tests test

integration-gate:
	tools/firebase-gates/run-flutter-callable-android.sh "$(ANDROID_DEVICE_ID)"

firebase-gates:
	tools/firebase-gates/run-local.sh

firebase-indexes-list:
	tools/firebase-gates/firebase.sh firestore:indexes --project kitchensync-dev-da503 --database '(default)' --pretty

firebase-deploy-dev-backend:
	tools/firebase-gates/firebase.sh deploy --project kitchensync-dev-da503 --only functions,firestore:indexes

firebase-rollout-dev:
	tools/firebase-gates/rollout-dev.sh

emulators-full:
	tools/firebase-gates/firebase.sh --config firebase.dev.json emulators:start --only auth,firestore,functions,storage --project kitchensync-dev-da503

emulator: emulators-full
