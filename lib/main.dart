import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitchensync/app/app.dart';
import 'package:kitchensync/core/firebase/firebase_initializer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final env = FirebaseInitializer.envFromDartDefine();
  await const FirebaseInitializer().initialize(env);
  runApp(const ProviderScope(child: KitchenSyncApp()));
}
