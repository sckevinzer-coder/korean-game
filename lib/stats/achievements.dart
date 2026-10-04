import 'stats_store.dart';

/// Definition of one achievement badge.
class AchievementDef {
  const AchievementDef({
    required this.id,
    required this.title,
    required this.description,
  });

  final String id;
  final String title;
  final String description;
}

/// All achievement badges.
const List<AchievementDef> allAchievements = [
  AchievementDef(
    id: 'first_quiz',
    title: '初クイズ',
    description: '初めてクイズを完了する',
  ),
  AchievementDef(
    id: 'streak_3',
    title: '3日連続',
    description: '3日連続で学習する',
  ),
  AchievementDef(
    id: 'streak_7',
    title: '7日連続',
    description: '7日連続で学習する',
  ),
  AchievementDef(
    id: 'accuracy_80',
    title: '正答率80%',
    description: '1回のクイズで正答率80%以上',
  ),
  AchievementDef(
    id: 'total_100',
    title: '100問正解',
    description: '累計100問正解する',
  ),
  AchievementDef(
    id: 'all_levels',
    title: '全レベル制覇',
    description: '1〜6級すべてのクイズを完了する',
  ),
];

/// Evaluates achievement conditions, unlocks newly earned ones, and returns
/// their ids. Uses displayStreak (no freeze side effects).
Future<List<String>> evaluateNewAchievements({
  required StatsStore stats,
  required DateTime today,
}) async {
  final unlocked = await stats.unlockedAchievements();
  final fresh = <String>[];

  void grant(String id) {
    if (!unlocked.contains(id) && !fresh.contains(id)) {
      fresh.add(id);
    }
  }

  final sessions = await stats.recentSessions(1);
  if (sessions.isNotEmpty) {
    grant('first_quiz');
    final last = sessions.first;
    if (last.total > 0 && last.rate >= 0.8) {
      grant('accuracy_80');
    }
  }
  final streak = await stats.displayStreak(today);
  if (streak >= 3) grant('streak_3');
  if (streak >= 7) grant('streak_7');
  final totals = await stats.lifetimeTotals();
  if (totals.correct >= 100) grant('total_100');
  final levels = await stats.completedLevels();
  if (const {1, 2, 3, 4, 5, 6}.difference(levels).isEmpty) {
    grant('all_levels');
  }

  for (final id in fresh) {
    await stats.unlockAchievement(id, today);
  }
  return fresh;
}
