
import 'package:material_ui/material_ui.dart';
import 'package:flutter_localizations/flutter_localizations.dart' as fl;
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Bus Management System',
      debugShowCheckedModeBanner: false,

      localizationsDelegates: const [
        fl.GlobalMaterialLocalizations.delegate,
        fl.GlobalWidgetsLocalizations.delegate,
        fl.GlobalCupertinoLocalizations.delegate,
      ],

      supportedLocales: const [
        Locale('en'),
      ],

      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
        ),
        useMaterial3: true,
      ),

      builder: (context, child) {
        return ScaffoldMessenger(
          child: child ?? const SizedBox.shrink(),
        );
      },

      home: const LoginScreen(),
    );
  }
}
