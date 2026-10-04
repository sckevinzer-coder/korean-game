enum WritingErrorType {
  correct,
  wrongParticle,
  wrongVowel,
  wrongConsonant,
  missingCharacter,
  extraCharacter,
  wrongWord,
  typo,
}

class WritingAnalysisResult {
  final bool isCorrect;
  final WritingErrorType errorType;
  final String userInput;
  final String correctAnswer;
  final String feedback;
  final List<CharacterAnalysis> characterAnalysis;
  final double similarityScore; // 0.0 to 1.0

  WritingAnalysisResult({
    required this.isCorrect,
    required this.errorType,
    required this.userInput,
    required this.correctAnswer,
    required this.feedback,
    required this.characterAnalysis,
    required this.similarityScore,
  });

  WritingAnalysisResult copyWith({
    bool? isCorrect,
    WritingErrorType? errorType,
    String? userInput,
    String? correctAnswer,
    String? feedback,
    List<CharacterAnalysis>? characterAnalysis,
    double? similarityScore,
  }) {
    return WritingAnalysisResult(
      isCorrect: isCorrect ?? this.isCorrect,
      errorType: errorType ?? this.errorType,
      userInput: userInput ?? this.userInput,
      correctAnswer: correctAnswer ?? this.correctAnswer,
      feedback: feedback ?? this.feedback,
      characterAnalysis: characterAnalysis ?? this.characterAnalysis,
      similarityScore: similarityScore ?? this.similarityScore,
    );
  }
}

class CharacterAnalysis {
  final int index;
  final String expectedChar;
  final String? actualChar;
  final bool isMatch;
  final CharacterErrorType errorType;

  CharacterAnalysis({
    required this.index,
    required this.expectedChar,
    this.actualChar,
    required this.isMatch,
    this.errorType = CharacterErrorType.none,
  });
}

enum CharacterErrorType {
  none,
  missing,
  extra,
  wrongVowel,
  wrongConsonant,
  wrongParticle,
  typo,
}

class WritingGrader {
  static const List<String> _particles = [
    '은', '는', '이', '가', '을', '를', '에', '에서', '으로', '로',
    '와', '과', '도', '만', '의', '도', '께', '한테', '에게', '보다',
    '처럼', '같이', '만큼', '까지', '부터', '마다', '조차', '마저',
  ];

  /// Analyze writing input with detailed feedback
  static WritingAnalysisResult analyze(String input, String answer, {bool ignoreParticles = true}) {
    if (input.trim().isEmpty) {
      return WritingAnalysisResult(
        isCorrect: false,
        errorType: WritingErrorType.missingCharacter,
        userInput: input,
        correctAnswer: answer,
        feedback: '入力が空です',
        characterAnalysis: [],
        similarityScore: 0.0,
      );
    }

    final normalizedInput = _normalize(input, ignoreParticles);
    final normalizedAnswer = _normalize(answer, ignoreParticles);

    if (normalizedInput == normalizedAnswer) {
      return WritingAnalysisResult(
        isCorrect: true,
        errorType: WritingErrorType.correct,
        userInput: input,
        correctAnswer: answer,
        feedback: '正解です！',
        characterAnalysis: _analyzeCharacters(input, answer),
        similarityScore: 1.0,
      );
    }

    // Analyze character by character
    final charAnalysis = _analyzeCharacters(input, answer);
    final errorType = _determineErrorType(charAnalysis, input, answer, ignoreParticles);
    final similarity = _calculateSimilarity(input, answer);
    final feedback = _generateFeedback(errorType, charAnalysis, input, answer);

    return WritingAnalysisResult(
      isCorrect: false,
      errorType: errorType,
      userInput: input,
      correctAnswer: answer,
      feedback: feedback,
      characterAnalysis: charAnalysis,
      similarityScore: similarity,
    );
  }

  static List<CharacterAnalysis> _analyzeCharacters(String input, String answer) {
    final inputChars = _decomposeHangul(input);
    final answerChars = _decomposeHangul(answer);
    
    final analysis = <CharacterAnalysis>[];
    final maxLen = inputChars.length > answerChars.length ? inputChars.length : answerChars.length;
    
    for (int i = 0; i < maxLen; i++) {
      final expected = i < answerChars.length ? answerChars[i] : '';
      final actual = i < inputChars.length ? inputChars[i] : null;
      
      if (i >= answerChars.length) {
        analysis.add(CharacterAnalysis(
          index: i,
          expectedChar: '',
          actualChar: actual,
          isMatch: false,
          errorType: CharacterErrorType.extra,
        ));
      } else if (i >= inputChars.length) {
        analysis.add(CharacterAnalysis(
          index: i,
          expectedChar: expected,
          actualChar: null,
          isMatch: false,
          errorType: CharacterErrorType.missing,
        ));
      } else if (actual == expected) {
        analysis.add(CharacterAnalysis(
          index: i,
          expectedChar: expected,
          actualChar: actual,
          isMatch: true,
        ));
      } else {
        // Determine specific error type
        final errorType = _compareHangulChars(actual!, expected);
        analysis.add(CharacterAnalysis(
          index: i,
          expectedChar: expected,
          actualChar: actual,
          isMatch: false,
          errorType: errorType,
        ));
      }
    }
    
    return analysis;
  }

  static List<String> _decomposeHangul(String s) {
    final result = <String>[];
    for (final codeUnit in s.codeUnits) {
      if (codeUnit >= 0xAC00 && codeUnit <= 0xD7A3) {
        // Decompose Hangul syllable
        final syllableIndex = codeUnit - 0xAC00;
        final choseong = syllableIndex ~/ (21 * 28);
        final jungseong = (syllableIndex % (21 * 28)) ~/ 28;
        final jongseong = syllableIndex % 28;
        
        final choseongChars = ['ㄱ','ㄲ','ㄴ','ㄷ','ㄸ','ㄹ','ㅁ','ㅂ','ㅃ','ㅅ','ㅆ','ㅇ','ㅈ','ㅉ','ㅊ','ㅋ','ㅌ','ㅍ','ㅎ'];
        final jungseongChars = ['ㅏ','ㅐ','ㅑ','ㅒ','ㅓ','ㅔ','ㅕ','ㅖ','ㅗ','ㅘ','ㅙ','ㅚ','ㅛ','ㅜ','ㅝ','ㅞ','ㅟ','ㅠ','ㅡ','ㅢ','ㅣ'];
        final jongseongChars = ['','ㄱ','ㄲ','ㄳ','ㄴ','ㄵ','ㄶ','ㄷ','ㄹ','ㄺ','ㄻ','ㄼ','ㄽ','ㄾ','ㄿ','ㅀ','ㅁ','ㅂ','ㅄ','ㅅ','ㅆ','ㅇ','ㅈ','ㅊ','ㅋ','ㅌ','ㅍ','ㅎ'];
        
        result.add(choseongChars[choseong]);
        result.add(jungseongChars[jungseong]);
        if (jongseong > 0) {
          result.add(jongseongChars[jongseong]);
        }
      } else {
        // Non-Hangul character
        result.add(String.fromCharCode(codeUnit));
      }
    }
    return result;
  }

  static CharacterErrorType _compareHangulChars(String actual, String expected) {
    if (actual == expected) return CharacterErrorType.none;
    
    // Check if it's a particle error
    final particles = ['은','는','이','가','을','를','에','에서','으로','로','와','과','도','만','의'];
    if (particles.contains(actual) || particles.contains(expected)) {
      return CharacterErrorType.wrongParticle;
    }
    
    // Decompose both and compare components
    final actualDecomposed = _decomposeHangul(actual);
    final expectedDecomposed = _decomposeHangul(expected);
    
    if (actualDecomposed.length >= 2 && expectedDecomposed.length >= 2) {
      // Compare vowel (jungseong) - index 1
      if (actualDecomposed[1] != expectedDecomposed[1]) {
        return CharacterErrorType.wrongVowel;
      }
      // Compare final consonant (jongseong) - index 2 if exists
      if (actualDecomposed.length > 2 && expectedDecomposed.length > 2) {
        if (actualDecomposed[2] != expectedDecomposed[2]) {
          return CharacterErrorType.wrongConsonant;
        }
      }
      // Compare initial consonant (choseong) - index 0
      if (actualDecomposed[0] != expectedDecomposed[0]) {
        return CharacterErrorType.wrongConsonant;
      }
    }
    
    return CharacterErrorType.typo;
  }

  static WritingErrorType _determineErrorType(
    List<CharacterAnalysis> analysis, 
    String input, 
    String answer,
    bool ignoreParticles,
  ) {
    final errorCounts = <CharacterErrorType, int>{};
    for (final a in analysis) {
      if (!a.isMatch) {
        errorCounts[a.errorType] = (errorCounts[a.errorType] ?? 0) + 1;
      }
    }
    
    if (errorCounts[CharacterErrorType.wrongParticle] != null && errorCounts[CharacterErrorType.wrongParticle]! > 0) {
      return WritingErrorType.wrongParticle;
    }
    if (errorCounts[CharacterErrorType.missing] != null && errorCounts[CharacterErrorType.missing]! > 0) {
      return WritingErrorType.missingCharacter;
    }
    if (errorCounts[CharacterErrorType.extra] != null && errorCounts[CharacterErrorType.extra]! > 0) {
      return WritingErrorType.extraCharacter;
    }
    if (errorCounts[CharacterErrorType.wrongVowel] != null && errorCounts[CharacterErrorType.wrongVowel]! > 0) {
      return WritingErrorType.wrongVowel;
    }
    if (errorCounts[CharacterErrorType.wrongConsonant] != null && errorCounts[CharacterErrorType.wrongConsonant]! > 0) {
      return WritingErrorType.wrongConsonant;
    }
    
    return WritingErrorType.typo;
  }

  static double _calculateSimilarity(String input, String answer) {
    if (input.isEmpty || answer.isEmpty) return 0.0;
    final maxLen = input.length > answer.length ? input.length : answer.length;
    if (maxLen == 0) return 1.0;
    
    int matches = 0;
    for (int i = 0; i < maxLen; i++) {
      if (i < input.length && i < answer.length && input[i] == answer[i]) {
        matches++;
      }
    }
    return matches / maxLen;
  }

  static String _generateFeedback(WritingErrorType errorType, List<CharacterAnalysis> analysis, String input, String answer) {
    switch (errorType) {
      case WritingErrorType.wrongParticle:
        return '助詞が違います。正しくは「${_getCorrectParticles(answer)}」です';
      case WritingErrorType.wrongVowel:
        return '母音が違います。正しい母音を確認してください';
      case WritingErrorType.wrongConsonant:
        return '子音が違います。正しい子音を確認してください';
      case WritingErrorType.missingCharacter:
        return '文字が不足しています。${answer.length - input.length}文字足りません';
      case WritingErrorType.extraCharacter:
        return '文字が余分です。${input.length - answer.length}文字多いです';
      case WritingErrorType.wrongWord:
        return '単語が違います。正しくは「$answer」です';
      case WritingErrorType.typo:
        return '入力ミスがあります。正しくは「$answer」です';
      default:
        return '正解は「$answer」です';
    }
  }

  static String _getCorrectParticles(String answer) {
    // Extract particles from answer
    final particles = ['은','는','이','가','을','를','에','에서','으로','로','와','と','も','だけ','の'];
    for (final p in particles) {
      if (answer.endsWith(p)) return p;
    }
    return '';
  }

  /// Get grade with partial credit (0.0 to 1.0)
  static double getPartialGrade(WritingAnalysisResult result) {
    if (result.isCorrect) return 1.0;
    return result.similarityScore.clamp(0.0, 0.9);
  }

  /// Near-miss threshold for partial bonus feedback.
  static bool isNearMiss(WritingAnalysisResult result,
      {double threshold = 0.7}) {
    return !result.isCorrect && result.similarityScore >= threshold;
  }

  /// Small bonus shown separately so integer quiz scores stay compatible.
  static double bonusFor(WritingAnalysisResult result) {
    if (result.isCorrect || !isNearMiss(result)) return 0.0;
    return (result.similarityScore * 0.5).clamp(0.0, 0.45);
  }

  static String similarityLabel(double similarity) =>
      '類似度 ${(similarity * 100).round()}%';

  static String _normalize(String s, bool ignoreParticles) {
    var result = s.replaceAll(RegExp(r'\s+'), '');
    result = result.replaceAll(RegExp(r'[。.?!]'), '');
    if (ignoreParticles) {
      result = _stripTrailingParticle(result);
    }
    return result;
  }

  static String _stripTrailingParticle(String s) {
    for (final particle in _particles) {
      if (s.endsWith(particle)) {
        return s.substring(0, s.length - particle.length);
      }
    }
    return s;
  }
}

/// Backward compatibility
/// Backward compatibility - simple boolean grade
bool gradeWriting(String input, String answer, {bool ignoreParticles = true}) {
  return WritingGrader.analyze(input, answer, ignoreParticles: ignoreParticles).isCorrect;
}