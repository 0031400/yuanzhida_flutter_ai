import 'package:flutter/material.dart';

import 'pages/login_page.dart';

void main() {
  runApp(const AnswerlyApp());
}

class AnswerlyApp extends StatelessWidget {
  const AnswerlyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2F2F2F)),
      useMaterial3: true,
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
      ),
    );

    return MaterialApp(
      title: 'Answerly',
      theme: theme,
      home: const LoginPage(),
    );
  }
}
