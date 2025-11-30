import 'dart:convert';
import 'package:http/http.dart' as http;
import 'exercise_model.dart';

class ExerciseAPI {
  static Future<List<Exercise>> fetchExercises() async {
    Uri url = Uri.parse("https://exercisedb.dev/api/v1/exercises");
    http.Response res = await http.get(url);
    if (res.statusCode != 200) {
      throw Exception("Exercise API error: ${res.statusCode}");
    }

    Map<String, dynamic> decoded = jsonDecode(res.body);
    List<dynamic> dataList = decoded["data"];
    return dataList.map((item) => Exercise.fromJson(item as Map<String, dynamic>)).toList();
  }
}
