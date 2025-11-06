import 'package:flutter/material.dart';

class WorkoutsPage extends StatefulWidget {
  const WorkoutsPage({super.key});

  @override
  State<WorkoutsPage> createState() => _WorkoutsPageState();
}

class _WorkoutsPageState extends State<WorkoutsPage> {
  String? _selectedWorkout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Workouts')),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          RadioListTile<String>(
            title: const Text('Run'),
            value: 'run',
            groupValue: _selectedWorkout,
            onChanged: (value) {
              setState(() {
                _selectedWorkout = value;
              });
            },
          ),
          RadioListTile<String>(
            title: const Text('Strength Workout'),
            value: 'strength',
            groupValue: _selectedWorkout,
            onChanged: (value) {
              setState(() {
                _selectedWorkout = value;
              });
            },
          ),
          RadioListTile<String>(
            title: const Text('Outdoor Bike'),
            value: 'bike',
            groupValue: _selectedWorkout,
            onChanged: (value) {
              setState(() {
                _selectedWorkout = value;
              });
            },
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Workout Started')),
              );
            },
            child: const Text('Start Workout'),
          ),
        ],
      ),
    );
  }
}