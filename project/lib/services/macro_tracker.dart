import 'package:flutter/foundation.dart';

class MacroTotals {
  const MacroTotals({
    this.calories = 0,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
  });

  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  static const empty = MacroTotals();

  MacroTotals operator +(MacroTotals other) {
    return MacroTotals(
      calories: calories + other.calories,
      protein: protein + other.protein,
      carbs: carbs + other.carbs,
      fat: fat + other.fat,
    );
  }
}

class MacroTracker extends ChangeNotifier {
  MacroTracker._();

  static final MacroTracker instance = MacroTracker._();

  final Map<String, MacroTotals> _totalsByDate = {};

  MacroTotals totalsForDate(DateTime date) {
    return _totalsByDate[_format(date)] ?? MacroTotals.empty;
  }

  void setTotalsForDate(DateTime date, MacroTotals totals) {
    _totalsByDate[_format(date)] = totals;
    notifyListeners();
  }

  String _format(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
