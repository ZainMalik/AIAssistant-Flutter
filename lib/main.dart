import 'package:flutter/material.dart';
import 'package:ai_assistant/Screens/ScreenHome.dart';
import 'package:ai_assistant/Screens/ScreenSplash.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Needed before any async work
  await dotenv.load(); // Load .env correctly

  Gemini.init(apiKey: dotenv.env['GEMINI_API_KEY'] ?? '');
  // Gemini.init(apiKey: GEMINI_API_KEY);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ScreenSplash(),
    );
  }
}
