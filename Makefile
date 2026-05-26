.PHONY: get gen watch analyze test cov format clean run-dev run-prod build-dev build-prod emulator

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

emulator:
	firebase emulators:start --import=./tools/emulator-data --export-on-exit=./tools/emulator-data
