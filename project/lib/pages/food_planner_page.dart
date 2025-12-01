import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../services/notifications_service.dart';
import '../services/macro_tracker.dart';

class _FoodItem {
  _FoodItem({
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  final String name;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  String get label => '$name (${calories.toStringAsFixed(0)} cal)';

  MacroTotals get macros => MacroTotals(
        calories: calories,
        protein: protein,
        carbs: carbs,
        fat: fat,
      );
}

class _DayPlan {
  final List<_FoodItem> breakfast = [];
  final List<_FoodItem> lunch = [];
  final List<_FoodItem> dinner = [];
  final List<_FoodItem> snack = [];
  bool mealsNotificationSent = false;
  String? analysisResult;
  String? analysisError;
}

const String _geminiApiKey = 'AIzaSyDXNgrLMqotpKCrKpbeG4r09pLicNCCpr8';
const String _geminiModel = 'gemini-2.5-flash';
const String _foodPlannerSystemPrompt =
    'You are a concise nutrition assistant. Respond ONLY with raw JSON (no markdown) in the exact shape '
    '{"items":[{"name":string,"calories":number,"protein_g":number,"carbohydrates_total_g":number,"fat_total_g":number}]}. '
    'Return up to 6 common foods that match the user search. Use plain numbers (no units) for macros.';

class FoodPlannerPage extends StatefulWidget {
  const FoodPlannerPage({super.key});

  @override
  State<FoodPlannerPage> createState() => _FoodPlannerPageState();
}

class _FoodPlannerPageState extends State<FoodPlannerPage> {
  DateTime _selectedDate = DateTime.now();
  bool _analysisLoading = false;

  double _userWeightKg = 0.0;
  String _weightUnit = 'kg';
  Map<String, double> _weightHistory = {}; // dateString -> kg

  final Map<String, _DayPlan> _plans = {};

  @override
  void initState() {
    super.initState();
    _updateMacroTotals();
    _loadUserWeight();
  }

  Future<void> _loadUserWeight() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final histJson = prefs.getString('weight_history');
      final map = <String, double>{};
      if (histJson != null) {
        try {
          final decoded = jsonDecode(histJson) as Map<String, dynamic>;
          decoded.forEach((k, v) {
            final d = (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0.0;
            map[k] = d;
          });
        } catch (e, st) {
          debugPrint('Failed parsing weight_history in FoodPlanner: $e');
          debugPrint(st.toString());
        }
      }
      final defaultKg = prefs.getDouble('user_weight_kg') ?? 0.0;
      setState(() {
        _weightHistory = map;
        _weightUnit = prefs.getString('weight_unit') ?? 'kg';
        _userWeightKg = _weightHistory[_formatDate(_selectedDate)] ?? defaultKg;
      });
    } catch (e, st) {
      debugPrint('Failed loading user weight: $e');
      debugPrint(st.toString());
    }
  }

  Future<void> _setUserWeightKg(double kg) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // save to history by date
      final key = _formatDate(_selectedDate);
      _weightHistory[key] = kg;
      await prefs.setString('weight_history', jsonEncode(_weightHistory));
      // also keep a default user_weight_kg for quick access
      await prefs.setDouble('user_weight_kg', kg);
      setState(() {
        _userWeightKg = kg;
      });
    } catch (e, st) {
      debugPrint('Failed saving user weight: $e');
      debugPrint(st.toString());
    }
  }

  void _showEditWeightDialog() {
    final controller = TextEditingController(text: (_weightUnit == 'kg' ? _userWeightKg : (_userWeightKg * 2.2046226218)).toStringAsFixed(1));
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Edit Weight'),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: 'Weight (${_weightUnit == 'kg' ? 'kg' : 'lbs'})'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                final v = double.tryParse(controller.text);
                if (v != null) {
                  final kg = _weightUnit == 'kg' ? v : v * 0.45359237;
                  _setUserWeightKg(kg);
                }
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _maybeNotifyWhenComplete() async {
    final plan = _currentPlan;
    final allSelected = plan.breakfast.isNotEmpty &&
        plan.lunch.isNotEmpty &&
        plan.dinner.isNotEmpty &&
        plan.snack.isNotEmpty;

    if (allSelected && !plan.mealsNotificationSent) {
      plan.mealsNotificationSent = true; 
      await NotificationService.instance.notifyFoodPlanner();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Food Plan Complete')),
        );
      }
    }
  }

  List<dynamic> _parseFoodItems(String content) {
    dynamic decoded;
    try {
      decoded = jsonDecode(content);
    } catch (_) {
      final match = RegExp(r'\{.*\}', dotAll: true).firstMatch(content);
      if (match != null) {
        try {
          decoded = jsonDecode(match.group(0)!);
        } catch (_) {}
      }
    }

    if (decoded is Map<String, dynamic>) {
      final items = decoded['items'];
      if (items is List) {
        return items;
      }
    }
    return [];
  }

  String? _extractGeminiText(Map<String, dynamic> candidate) {
    final content = candidate['content'] as Map<String, dynamic>?;
    if (content == null) return null;
    final parts = content['parts'] as List?;
    if (parts == null || parts.isEmpty) return null;
    final firstPart = parts.first as Map<String, dynamic>?;
    return firstPart?['text'] as String?;
  }

  void _showFoodSearchDialog(List<_FoodItem> mealList, String mealType) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final TextEditingController searchController =
            TextEditingController();
        List<dynamic> results = [];
        bool isLoading = false;
        String? errorMessage;

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            Future<void> performSearch(String query) async {
              final trimmed = query.trim();
              if (trimmed.isEmpty) {
                setStateDialog(() {
                  results = [];
                  errorMessage = null;
                  isLoading = false;
                });
                return;
              }

              setStateDialog(() {
                isLoading = true;
                errorMessage = null;
              });

              if (_geminiApiKey.isEmpty) {
                setStateDialog(() {
                  results = [];
                  errorMessage =
                      'Missing Gemini API key.';
                  isLoading = false;
                });
                return;
              }

              final uri = Uri.https(
                'generativelanguage.googleapis.com',
                '/v1beta/models/$_geminiModel:generateContent',
              );

              try {
                final response = await http.post(uri,
                    headers: {
                      'x-goog-api-key': _geminiApiKey,
                      'Content-Type': 'application/json',
                    },
                    body: jsonEncode({
                      'systemInstruction': {
                        'parts': [
                          {'text': _foodPlannerSystemPrompt}
                        ],
                      },
                      'contents': [
                        {
                          'role': 'user',
                          'parts': [
                            {'text': 'Food search term: "$trimmed"'},
                          ],
                        },
                      ],
                      'generationConfig': {
                        'temperature': 0.0,
                        'maxOutputTokens': 5000,
                        'responseMimeType': 'application/json',
                        'responseSchema': {
                          'type': 'object',
                          'properties': {
                            'items': {
                              'type': 'array',
                              'items': {
                                'type': 'object',
                                'properties': {
                                  'name': {'type': 'string'},
                                  'calories': {'type': 'number'},
                                  'protein_g': {'type': 'number'},
                                  'carbohydrates_total_g': {'type': 'number'},
                                  'fat_total_g': {'type': 'number'},
                                },
                                'required': [
                                  'name',
                                  'calories',
                                  'protein_g',
                                  'carbohydrates_total_g',
                                  'fat_total_g'
                                ],
                              },
                            },
                          },
                          'required': ['items'],
                        },
                      },
                    }));

                if (response.statusCode == 200) {
                  final data =
                      jsonDecode(response.body) as Map<String, dynamic>;
                  final candidates = data['candidates'] as List?;
                  final String? content =
                      (candidates != null && candidates.isNotEmpty)
                          ? _extractGeminiText(candidates.first)
                          : null;

                  final parsedItems =
                      content == null ? <dynamic>[] : _parseFoodItems(content);

                  if (parsedItems.isEmpty) {
                    setStateDialog(() {
                      results = [];
                      final finishReason = (candidates != null &&
                              candidates.isNotEmpty &&
                              candidates.first is Map<String, dynamic>)
                          ? ((candidates.first as Map<String, dynamic>?)
                                      ?['finishReason'] as String?) ??
                              ''
                          : '';
                      errorMessage =
                          'No items returned from the nutrition response.\nFinish reason: $finishReason\nRaw reply: ${content ?? jsonEncode(data)}';
                      isLoading = false;
                    });
                  } else {
                    setStateDialog(() {
                      results = parsedItems;
                      isLoading = false;
                    });
                  }
                } else {
                  setStateDialog(() {
                    results = [];
                    errorMessage =
                        'Error ${response.statusCode}: ${response.body}';
                    isLoading = false;
                  });
                }
              } catch (e) {
                setStateDialog(() {
                  results = [];
                  errorMessage = 'Failed to load foods.';
                  isLoading = false;
                });
              }
            }

            return AlertDialog(
              title: Text('Search $mealType food'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: searchController,
                    decoration: const InputDecoration(
                      hintText: 'Search meals...',
                      prefixIcon: Icon(Icons.search),
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (text) => performSearch(text),
                    onChanged: (text) {
                      // You can debounce this in the future if you want.
                    },
                  ),
                  const SizedBox(height: 12),
                  if (isLoading) const CircularProgressIndicator(),
                  if (!isLoading && errorMessage != null) ...[
                    Text(
                      errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (!isLoading && results.isEmpty && errorMessage == null)
                    const Text(
                      'Type a food name and press search.',
                      style: TextStyle(fontSize: 12),
                    ),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(dialogContext).size.height * 0.6,
                    ),
                    child: results.isEmpty
                        ? const SizedBox.shrink()
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: results.length,
                            itemBuilder: (context, index) {
                               final item =
                                   results[index] as Map<String, dynamic>;
                               final String name =
                                   (item['name'] ?? 'Unknown food') as String;
                               final double calories =
                                   (item['calories'] as num?)?.toDouble() ?? 0;
                               final double protein =
                                   (item['protein_g'] as num?)?.toDouble() ?? 0;
                               final double carbs =
                                   (item['carbohydrates_total_g'] as num?)
                                           ?.toDouble() ??
                                       0;
                                 final double fat =
                                   (item['fat_total_g'] as num?)?.toDouble() ??
                                       0;

                               return ListTile(
                                 leading: CircleAvatar(
                                   child: Text(
                                     name.isNotEmpty
                                         ? name[0].toUpperCase()
                                         : '?',
                                   ),
                                 ),
                                 title: Text(
                                     '$name (${calories.toStringAsFixed(0)} cal)'),
                                 subtitle: Text(
                                   'P: ${protein.toStringAsFixed(1)}g · C: ${carbs.toStringAsFixed(1)}g · F: ${fat.toStringAsFixed(1)}g',
                                 ),
                                 onTap: () async {
                                   final entry = _FoodItem(
                                     name: name,
                                     calories: calories,
                                     protein: protein,
                                     carbs: carbs,
                                     fat: fat,
                                   );
                                   setState(() {
                                     mealList.add(entry);
                                   });
                                   _updateMacroTotals();
                                   Navigator.of(dialogContext).pop();
                                   await _maybeNotifyWhenComplete();
                                 },
                               );
                             },
                          ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  bool _hasMealsSelected() {
    final plan = _currentPlan;
    return plan.breakfast.isNotEmpty ||
        plan.lunch.isNotEmpty ||
        plan.dinner.isNotEmpty ||
        plan.snack.isNotEmpty;
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _analysisLoading = false;
        _currentPlan.mealsNotificationSent = false;
      });
      // update displayed weight for the newly selected date
      setState(() {
        _userWeightKg = _weightHistory[_formatDate(_selectedDate)] ?? _userWeightKg;
      });
      _updateMacroTotals();
    }
  }

  _DayPlan get _currentPlan {
    final key = _formatDate(_selectedDate);
    return _plans.putIfAbsent(key, () => _DayPlan());
  }

  void _updateMacroTotals() {
    final plan = _currentPlan;
    final items = <_FoodItem>[...plan.breakfast, ...plan.lunch, ...plan.dinner, ...plan.snack];

    MacroTotals totals = MacroTotals.empty;
    for (final item in items) {
      totals = totals + item.macros;
    }

    MacroTracker.instance.setTotalsForDate(_selectedDate, totals);
  }

  void _clearCurrentPlan() {
    final plan = _currentPlan;
    plan.breakfast.clear();
    plan.lunch.clear();
    plan.dinner.clear();
    plan.snack.clear();
    plan.mealsNotificationSent = false;
    plan.analysisError = null;
    plan.analysisResult = null;
    setState(() {
      _analysisLoading = false;
    });
    _updateMacroTotals();
  }

  Future<void> _analyzePlan() async {
    if (!_hasMealsSelected()) {
      setState(() {
        _currentPlan.analysisError = 'Add some foods first, then analyze.';
        _currentPlan.analysisResult = null;
      });
      return;
    }

    setState(() {
      _analysisLoading = true;
      _currentPlan.analysisError = null;
      _currentPlan.analysisResult = null;
    });

    final uri = Uri.https(
      'generativelanguage.googleapis.com',
      '/v1beta/models/$_geminiModel:generateContent',
    );

    try {
      // Build a brief weight-history summary (up to 7 recent days) to give the AI context.
      final StringBuffer weightSummaryBuf = StringBuffer();
      try {
        if (_weightHistory.isNotEmpty) {
          final entries = _weightHistory.entries.toList()
            ..sort((a, b) => a.key.compareTo(b.key));
          final recent = entries.length <= 7 ? entries : entries.sublist(entries.length - 7);
          weightSummaryBuf.writeln('User weight history (most recent ${recent.length} days):');
          for (final e in recent) {
            weightSummaryBuf.writeln('${e.key}: ${e.value.toStringAsFixed(1)} kg');
          }
          if (recent.length >= 2) {
            final first = recent.first.value;
            final last = recent.last.value;
            final delta = last - first;
            final days = DateTime.parse(recent.last.key).difference(DateTime.parse(recent.first.key)).inDays;
            final sign = delta >= 0 ? '+' : '';
            weightSummaryBuf.writeln('Trend: $sign${delta.toStringAsFixed(1)} kg over $days days.');
          }
        } else if (_userWeightKg > 0) {
          weightSummaryBuf.writeln('User current weight: ${_userWeightKg.toStringAsFixed(1)} kg');
        }
      } catch (e, st) {
        debugPrint('Error building weight summary for AI prompt: $e');
        debugPrint(st.toString());
      }

      // include user's goal from dashboard if available
      String? userGoal;
      try {
        final prefs = await SharedPreferences.getInstance();
        userGoal = prefs.getString('dashboard_goal');
      } catch (e) {
        userGoal = null;
      }

      final response = await http.post(
        uri,
        headers: {
          'x-goog-api-key': _geminiApiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'systemInstruction': {
            'parts': [
              {
                'text':
                    'You are a fitness nutrition coach. Analyze the provided daily meal plan and give a short critique plus 3 concrete improvements. Keep it concise (<=120 words). Focus on protein adequacy, calorie balance, and nutrient diversity. Be encouraging and practical.'
              }
            ],
          },
          'contents': [
            {
              'role': 'user',
              'parts': [
                {
                  'text':
                      'Breakfast: ${_currentPlan.breakfast.map((item) => item.label).join(', ')}\nLunch: ${_currentPlan.lunch.map((item) => item.label).join(', ')}\nDinner: ${_currentPlan.dinner.map((item) => item.label).join(', ')}\nSnack: ${_currentPlan.snack.map((item) => item.label).join(', ')}\n\n${weightSummaryBuf.toString()}${userGoal != null && userGoal.isNotEmpty ? '\nUser goal: $userGoal' : ''}'
                },
              ],
            },
          ],
          'generationConfig': {
            'temperature': 0.2,
            'maxOutputTokens': 5000,
            'responseMimeType': 'text/plain',
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final candidates = data['candidates'] as List?;
        final finishReason = (candidates != null &&
                candidates.isNotEmpty &&
                candidates.first is Map<String, dynamic>)
            ? ((candidates.first as Map<String, dynamic>?)?['finishReason']
                    as String?) ??
                ''
            : '';
        final content = (candidates != null && candidates.isNotEmpty)
            ? _extractGeminiText(candidates.first)
            : null;
        setState(() {
          _currentPlan.analysisResult = content ??
              'No analysis returned.\nFinish reason: $finishReason\nRaw: ${jsonEncode(data)}';
          _currentPlan.analysisError = null;
          _analysisLoading = false;
        });
      } else {
        setState(() {
          _currentPlan.analysisError =
              'Analysis failed: ${response.statusCode} ${response.body}';
          _analysisLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _currentPlan.analysisError = 'Analysis failed.';
        _analysisLoading = false;
      });
    }
  }

  Widget _buildMealSection(
      String title, List<_FoodItem> mealList, VoidCallback onAddPressed) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ),
                ElevatedButton.icon(
                  onPressed: onAddPressed,
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            mealList.isEmpty
              ? Text('No items', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.65)))
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: mealList
                        .map((item) => Chip(
                              label: Text(item.label),
                            ))
                        .toList(),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeightCard() {
    final display = _weightUnit == 'kg'
      ? (_userWeightKg > 0 ? '${_userWeightKg.toStringAsFixed(1)} kg' : '')
      : (_userWeightKg > 0 ? '${(_userWeightKg * 2.2046226218).toStringAsFixed(1)} lbs' : '');

    // compute a small recent trend (up to 7 days) using stored weight history
    String? trendText;
    Color? trendColor;
    try {
      if (_weightHistory.isNotEmpty) {
        final entries = _weightHistory.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key));
        // only consider entries up to the selected date
        final filtered = entries.where((e) {
          try {
            return DateTime.parse(e.key).isBefore(_selectedDate.add(const Duration(days: 1)));
          } catch (_) {
            return false;
          }
        }).toList();
        if (filtered.isNotEmpty) {
          final recent = filtered.length <= 7 ? filtered : filtered.sublist(filtered.length - 7);
          if (recent.length >= 2) {
            final first = recent.first.value;
            final last = recent.last.value;
            final deltaKg = last - first;
            final firstDate = DateTime.parse(recent.first.key);
            final lastDate = DateTime.parse(recent.last.key);
            var days = lastDate.difference(firstDate).inDays;
            if (days <= 0) days = 1;
            double displayDelta = deltaKg;
            String unitLabel = 'kg';
            if (_weightUnit != 'kg') {
              displayDelta = deltaKg * 2.2046226218;
              unitLabel = 'lbs';
            }
            final sign = displayDelta >= 0 ? '+' : '';
            trendText = 'Trend: $sign${displayDelta.toStringAsFixed(1)} $unitLabel over ${days}d';
            trendColor = displayDelta < 0 ? Colors.green : (displayDelta > 0 ? Colors.red : Colors.grey);
          }
        }
      }
    } catch (e) {
      // ignore errors computing trend
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Weight', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(display, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                if (trendText != null) ...[
                  const SizedBox(height: 6),
                  Text(trendText, style: TextStyle(fontSize: 12, color: trendColor ?? Theme.of(context).colorScheme.onSurface.withOpacity(0.65))),
                ],
              ],
            ),
            ElevatedButton.icon(
              onPressed: _showEditWeightDialog,
              icon: const Icon(Icons.edit),
              label: Text(_userWeightKg > 0 ? 'Edit' : 'Set weight'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Logging date: ${_formatDate(_selectedDate)}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Weight moved to its own card below
                  SizedBox.shrink(),
                  TextButton(
                    onPressed: _clearCurrentPlan,
                    child: const Text('Clear day'),
                  ),
                  TextButton(
                    onPressed: _pickDate,
                    child: const Text('Change'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Insert the weight card here so it visually matches the meal cards
              _buildWeightCard(),
              const SizedBox(height: 12),
              _buildMealSection(
                'Breakfast',
                _currentPlan.breakfast,
                () => _showFoodSearchDialog(_currentPlan.breakfast, 'Breakfast'),
              ),
              _buildMealSection(
                'Lunch',
                _currentPlan.lunch,
                () => _showFoodSearchDialog(_currentPlan.lunch, 'Lunch'),
              ),
              _buildMealSection(
                'Dinner',
                _currentPlan.dinner,
                () => _showFoodSearchDialog(_currentPlan.dinner, 'Dinner'),
              ),
              _buildMealSection(
                'Snack',
                _currentPlan.snack,
                () => _showFoodSearchDialog(_currentPlan.snack, 'Snack'),
              ),
              const Divider(height: 32),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('AI Plan Analysis', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _analysisLoading ? null : _analyzePlan,
                        icon: _analysisLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.analytics),
                        label: const Text('Analyze'),
                      ),
                      const SizedBox(height: 8),
                      if (_currentPlan.analysisError != null)
                        Text(
                          _currentPlan.analysisError!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      if (_currentPlan.analysisResult != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _currentPlan.analysisResult!,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
