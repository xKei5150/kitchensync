import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:kitchensync/core/firebase/firebase_initializer.dart';

Future<void> bootEmulatedApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  await const FirebaseInitializer().initialize(AppEnv.dev);
  if (FirebaseAuth.instance.currentUser == null) {
    await FirebaseAuth.instance.signInAnonymously();
  }
}
