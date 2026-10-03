bool gradeWriting(String input, String answer, {bool ignoreParticles = true}) {
  if (input.trim().isEmpty) {
    return false;
  }

  final normalizedInput = _normalize(input, ignoreParticles);
  final normalizedAnswer = _normalize(answer, ignoreParticles);

  return normalizedInput == normalizedAnswer;
}

String _normalize(String s, bool ignoreParticles) {
  var result = s.replaceAll(RegExp(r'\s+'), '');
  result = result.replaceAll(RegExp(r'[。.?!]'), '');

  if (ignoreParticles) {
    result = _stripTrailingParticle(result);
  }

  return result;
}

String _stripTrailingParticle(String s) {
  const particles = [
    '은',
    '는',
    '이',
    '가',
    '을',
    '를',
    '에',
    '에서',
    '으로',
    '로',
    '와',
    '과',
    '도',
    '만',
    '의',
  ];

  for (final particle in particles) {
    if (s.endsWith(particle)) {
      return s.substring(0, s.length - particle.length);
    }
  }

  return s;
}