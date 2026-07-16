import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/router.dart';
import 'app/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Capture all Flutter framework errors
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint(
        'FLUTTER FRAMEWORK ERROR: ${details.exception}\n${details.stack}');
  };

  // Capture all asynchronous errors outside of Flutter framework
  WidgetsBinding.instance.platformDispatcher.onError =
      (Object error, StackTrace stack) {
    debugPrint('UNCAUGHT ASYNC ERROR: $error\n$stack');
    return true;
  };

  // ระบบแคชเป็นความสามารถเสริม โดยเฉพาะบน Web ที่ IndexedDB อาจถูกบล็อก
  // แอปต้องยังเปิดและเรียก API ได้ แม้ Hive เริ่มต้นไม่สำเร็จ
  try {
    debugPrint('Initializing Hive...');
    await Hive.initFlutter();
  } catch (error, stack) {
    debugPrint('HIVE INITIALIZATION SKIPPED: $error');
    debugPrint(stack.toString());
  }

  try {
    await initializeDateFormatting('th');
  } catch (error, stack) {
    debugPrint('THAI DATE LOCALE INITIALIZATION SKIPPED: $error');
    debugPrint(stack.toString());
  }

  debugPrint('Running app...');
  runApp(const ProviderScope(child: FinanceCoachApp()));
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
