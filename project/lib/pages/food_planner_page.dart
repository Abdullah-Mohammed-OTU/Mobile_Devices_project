import 'package:flutter/material.dart';

class FoodPlannerPage extends StatefulWidget {
  const FoodPlannerPage({super.key});

  @override
  State<FoodPlannerPage> createState() => _FoodPlannerPageState();
}

class _FoodPlannerPageState extends State<FoodPlannerPage> {
  final List<String> _breakfast = [];
  final List<String> _lunch = [];
  final List<String> _dinner = [];
  final List<String> _snack = [];
  final List<String> _foods = ["Eggs", "Chicken", "Broccoli", "Bread"];

  void _showFoodPicker(List<String> mealList) {
    showDialog(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text('Select Food'),
          children: _foods.map((food) {
            return SimpleDialogOption(
              child: Text(food),
              onPressed: () {
                setState(() {
                  mealList.add(food);
                });
                Navigator.pop(context);
              },
            );
          }).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Food Planner')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Breakfast", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text(_breakfast.isEmpty ? "No items" : _breakfast.join(", ")),
            ElevatedButton(
              onPressed: () => _showFoodPicker(_breakfast),
              child: const Text("Add Food"),
            ),
            SizedBox(height: 20),
            Text("Lunch", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text(_lunch.isEmpty ? "No items" : _lunch.join(", ")),
            ElevatedButton(
              onPressed: () => _showFoodPicker(_lunch),
              child: const Text("Add Food"),
            ),
            SizedBox(height: 20),
            Text("Dinner", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text(_dinner.isEmpty ? "No items" : _dinner.join(", ")),
            ElevatedButton(
              onPressed: () => _showFoodPicker(_dinner),
              child: const Text("Add Food"),
            ),
            SizedBox(height: 20),
            Text("Snack", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text(_snack.isEmpty ? "No items" : _snack.join(", ")),
            ElevatedButton(
              onPressed: () => _showFoodPicker(_snack),
              child: const Text("Add Food"),
            ),
          ],
        ),
      ),
    );
  }
}