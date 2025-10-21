import 'package:flutter/material.dart';

class FoodPlannerPage extends StatelessWidget {
  const FoodPlannerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Food Planner')),
      body: const Center(
        child: Text(
          'Food Planner Page',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}