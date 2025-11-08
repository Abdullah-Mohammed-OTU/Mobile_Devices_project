import 'package:flutter/material.dart';

class WorkoutsPage extends StatefulWidget {
  const WorkoutsPage({super.key});

  @override
  State<WorkoutsPage> createState() => _WorkoutsPageState();
}

class _WorkoutsPageState extends State<WorkoutsPage> {
  String? _selectedWorkout;

  final List<String> _savedWorkouts = [];
  final List<String> _options = ["Run", "Strength Workout", "Outdoor Bike"];

  void _showWorkoutPicker() {
    showDialog(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text('Select Workout'),
          children: _options.map((workout) {
            return SimpleDialogOption(
              child: Text(workout),
              onPressed: () {
                setState(() {
                  _selectedWorkout = workout;
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
      appBar: AppBar(title: const Text('Workouts')),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_savedWorkouts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text("Selected: ${_savedWorkouts.join(", ")}", style: const TextStyle(fontSize: 16)),
            ),
          if (_selectedWorkout != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text("Chosen Workout: $_selectedWorkout", style: const TextStyle(fontSize: 16)),
            ),
          ElevatedButton(
            onPressed: _showWorkoutPicker,
            child: const Text("Choose Workout"),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text('Start Workout'),
                    content: const Text('Are you sure you want to start a workout?'),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Workout Started')),
                          );
                        },
                        child: const Text('Start'),
                      ),
                    ],
                  );
                },
              );
            },
            child: const Text('Start Workout'),
          ),
        ],
      ),
    );
  }
}