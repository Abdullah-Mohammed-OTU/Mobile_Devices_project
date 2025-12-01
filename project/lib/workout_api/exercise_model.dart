class Exercise {
  String name;
  List<String> instructions;

  Exercise({
    required this.name,
    required this.instructions,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) {
    List<dynamic>? instrList = json["instructions"];

    List<String> tips = [];
    if (instrList != null) {
      tips = instrList.map((e) => e.toString()).toList();
    }

    return Exercise(
      name: json["name"] ?? "Unknown",
      instructions: tips,
    );
  }
}