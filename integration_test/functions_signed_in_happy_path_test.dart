import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '_helpers.dart';

const _firebaseEmulatorHost = String.fromEnvironment(
  'FIREBASE_EMULATOR_HOST',
  defaultValue: '10.0.2.2',
);
const _firestoreEmulatorPort = int.fromEnvironment(
  'FIRESTORE_EMULATOR_PORT',
  defaultValue: 8080,
);
const _authEmulatorPort = int.fromEnvironment(
  'AUTH_EMULATOR_PORT',
  defaultValue: 9099,
);
const _functionsEmulatorPort = int.fromEnvironment(
  'FUNCTIONS_EMULATOR_PORT',
  defaultValue: 5001,
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'FirebaseInitializer signs in then shoppingSmoke returns exactly ok true',
    (tester) async {
      await bootEmulatedApp();
      final user = FirebaseAuth.instance.currentUser;

      expect(
        user,
        isNotNull,
        reason: 'FirebaseInitializer must establish a user',
      );
      final uid = user!.uid;
      expect(uid, isNotEmpty);
      final token = await user.getIdToken();
      final tokenPresent = token?.isNotEmpty ?? false;
      expect(
        tokenPresent,
        isTrue,
        reason: 'Signed-in user must have an ID token',
      );

      debugPrint(
        'QA_CONFIG platform=$defaultTargetPlatform '
        'firebaseHost=$_firebaseEmulatorHost '
        'firestorePort=$_firestoreEmulatorPort '
        'authPort=$_authEmulatorPort '
        'functionsPort=$_functionsEmulatorPort',
      );
      debugPrint(
        'QA_AUTH isAnonymous=${user.isAnonymous} '
        'idTokenPresent=$tokenPresent',
      );

      final result = await FirebaseFunctions.instance
          .httpsCallable('shoppingSmoke')
          .call<Map<String, dynamic>>(<String, dynamic>{})
          .timeout(const Duration(seconds: 15));
      final response = result.data;

      debugPrint('QA_RESPONSE exact=${jsonEncode(response)}');
      expect(response, equals(<String, dynamic>{'ok': true}));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Text(
                'Signed-in callable PASS\nresponse=${jsonEncode(response)}',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    },
    timeout: const Timeout(Duration(seconds: 45)),
  );
}
