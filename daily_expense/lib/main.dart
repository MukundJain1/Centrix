import 'package:flutter/material.dart';
import 'features/auth/auth_screen.dart'; // Ensure this path is correct

void main() {
  runApp(const DailyBudgetApp());
}

class DailyBudgetApp extends StatelessWidget {
  const DailyBudgetApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AuthScreen(),
    );
  }
}