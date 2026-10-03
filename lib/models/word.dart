class Word {
  final String id;
  final String korean;
  final String reading;
  final String meaningJa;
  final String exampleKo;
  final String exampleJa;
  final int topikLevel;

  const Word({
    required this.id,
    required this.korean,
    required this.reading,
    required this.meaningJa,
    required this.exampleKo,
    required this.exampleJa,
    required this.topikLevel,
  });

  factory Word.fromJson(Map<String, dynamic> json) {
    String requireString(String key) {
      final value = json[key];
      if (value is! String) {
        throw FormatException('Missing or invalid field: $key');
      }
      return value;
    }

    final topikLevel = json['topikLevel'];
    if (topikLevel is! int) {
      throw FormatException('Missing or invalid field: topikLevel');
    }

    return Word(
      id: requireString('id'),
      korean: requireString('korean'),
      reading: requireString('reading'),
      meaningJa: requireString('meaningJa'),
      exampleKo: requireString('exampleKo'),
      exampleJa: requireString('exampleJa'),
      topikLevel: topikLevel,
    );
  }
}
