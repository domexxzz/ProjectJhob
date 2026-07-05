import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app/router.dart';
import 'app/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Capture all Flutter framework errors
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('FLUTTER FRAMEWORK ERROR: ${details.exception}\n${details.stack}');
  };

  // Capture all asynchronous errors outside of Flutter framework
  WidgetsBinding.instance.platformDispatcher.onError = (Object error, StackTrace stack) {
    debugPrint('UNCAUGHT ASYNC ERROR: $error\n$stack');
    return true;
  };

  try {
    debugPrint('Initializing Hive...');
    await Hive.initFlutter();
    debugPrint('Opening Hive box...');
    await Hive.openBox('cache');
    debugPrint('Running app...');
    runApp(const ProviderScope(child: FinanceCoachApp()));
  } catch (e, stack) {
    debugPrint('INITIALIZATION ERROR: $e');
    debugPrint(stack.toString());
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SelectableText(
                'Initialization Error:\n$e\n\nStacktrace:\n$stack',
                style: const TextStyle(color: Colors.red, fontSize: 14),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class FinanceCoachApp extends ConsumerWidget {
  const FinanceCoachApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'พี่เงิน',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      routerConfig: router,
    );
  }
}
