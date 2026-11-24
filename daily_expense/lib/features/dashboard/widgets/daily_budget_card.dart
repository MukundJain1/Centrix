import 'package:flutter/material.dart';

class NeumorphicBudgetCard extends StatelessWidget {
  final double dailyAmount;

  const NeumorphicBudgetCard({Key? key, required this.dailyAmount}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFE0E5EC), // Base background color
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          // Bottom right dark shadow
          BoxShadow(
            color: Colors.grey.shade500,
            offset: const Offset(8, 8),
            blurRadius: 15,
            spreadRadius: 1,
          ),
          // Top left light shadow (creates the 3D pop)
          const BoxShadow(
            color: Colors.white,
            offset: Offset(-8, -8),
            blurRadius: 15,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Today's Budget",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "₹${dailyAmount.toStringAsFixed(0)}",
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: 0.7, // Connect this to BLoC state later
            backgroundColor: Colors.grey.shade300,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
          ),
        ],
      ),
    );
  }
}