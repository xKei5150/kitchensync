.PHONY: get gen watch analyze test cov format clean run-dev run-prod build-dev build-prod functions-install functions-lint functions-build functions-test functions-test-emulator functions-gate rules-test integration-gate firebase-gates firebase-indexes-list firebase-deploy-dev-backend firebase-rollout-dev firebase-deploy-prod-backend firebase-rollout-prod deploy-planner-dev deploy-planner-prod firebase-native-config-dev firebase-native-config-prod assert-prod-auth-config emulators-full emulator


# OAuth client IDs are public, but environment-specific. Dev remains usable on
# a fresh clone; prod artifacts must not be built without its verified config.
AUTH_DEV_DEFINE := $(if $(wildcard tool/auth/auth.dev.json),--dart-define-from-file=tool/auth/auth.dev.json,)
AUTH_PROD_DEFINE := --dart-define-from-file=tool/auth/auth.prod.json

get:
	flutter pub get

gen:
	dart run build_runner build --delete-conflicting-outputs

watch:
	dart run build_runner watch --delete-conflicting-outputs

analyze:
	flutter analyze lib test integration_test

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
	flutter run --dart-define=ENV=dev $(AUTH_DEV_DEFINE)

assert-prod-auth-config:
	@test -f tool/auth/auth.prod.json || (echo "Missing tool/auth/auth.prod.json; run Firebase OAuth config sync first." >&2; exit 1)

run-prod: assert-prod-auth-config
	flutter run --dart-define=ENV=prod $(AUTH_PROD_DEFINE)

firebase-native-config-dev:
	bash tools/sync-firebase-native-config.sh dev

firebase-native-config-prod:
	bash tools/sync-firebase-native-config.sh prod

build-dev: firebase-native-config-dev
	flutter build apk --dart-define=ENV=dev --debug $(AUTH_DEV_DEFINE)

build-prod: firebase-native-config-prod assert-prod-auth-config
	flutter build appbundle --dart-define=ENV=prod --release $(AUTH_PROD_DEFINE)

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

firebase-deploy-prod-backend:
	tools/firebase-gates/firebase.sh deploy --config firebase.prod.json --project kitchensync-prod-8d6fd --only functions,firestore:rules,firestore:indexes,storage

firebase-rollout-prod:
	tools/firebase-gates/rollout-prod.sh --confirm-prod

deploy-planner-dev:
	bash tools/deploy-planner-dev.sh

deploy-planner-prod:
	bash tools/deploy-planner-prod.sh

emulators-full:
	tools/firebase-gates/firebase.sh --config firebase.dev.json emulators:start --only auth,firestore,functions,storage --project kitchensync-dev-da503

emulator: emulators-full
