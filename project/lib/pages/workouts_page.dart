import 'package:flutter/material.dart';
import '../services/notifications_service.dart';
import 'dart:async';

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
  void dispose() {
    super.dispose();
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
              child: Text(
                "Selected: ${_savedWorkouts.join(", ")}",
                style: const TextStyle(fontSize: 16),
              ),
            ),
          if (_selectedWorkout != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(
                "Chosen Workout: $_selectedWorkout",
                style: const TextStyle(fontSize: 16),
              ),
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
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Pick how long you want to work out:'),
                        const SizedBox(height: 10),
                        ListTile(
                          title: const Text('10 minutes'),
                          onTap: () async {
                            Navigator.of(context).pop();
                            await NotificationService.instance.notifyWorkoutStart();

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Workout started for 10 minutes')),
                            );

                            await Future.delayed(const Duration(minutes: 10));
                            await NotificationService.instance.notifyWorkoutComplete(10);

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Workout complete! (10 min)')),
                            );
                          },
                        ),
                        ListTile(
                          title: const Text('20 minutes'),
                          onTap: () async {
                            Navigator.of(context).pop();
                            await NotificationService.instance.notifyWorkoutStart();

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Workout started for 20 minutes')),
                            );

                            await Future.delayed(const Duration(minutes: 20));
                            await NotificationService.instance.notifyWorkoutComplete(20);

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Workout complete! (20 min)')),
                            );
                          },
                        ),
                        ListTile(
                          title: const Text('30 minutes'),
                          onTap: () async {
                            Navigator.of(context).pop();
                            await NotificationService.instance.notifyWorkoutStart();

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Workout started for 30 minutes')),
                            );

                            await Future.delayed(const Duration(minutes: 30));
                            await NotificationService.instance.notifyWorkoutComplete(30);

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Workout complete! (30 min)')),
                            );
                          },
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                    ],
                  );
                },
              );
            },
            child: const Text('Start Workout'),
          )
        ],
      ),
    );
  }
}
