import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/loading_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const FootIQApp());
}

class FootIQApp extends StatelessWidget {
  const FootIQApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FootIQ',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'Exo2',
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF63D998), brightness: Brightness.dark),
      ),
      home: const LoadingScreen(),
    );
  }
}
