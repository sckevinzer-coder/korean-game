import 'package:flutter_test/flutter_test.dart';

import 'package:korean_game/notify/review_notify.dart';

void main() {
  group('reminderState', () {
    test('hidden when unsupported', () {
      expect(
        reminderState(supported: false, permission: 'granted', dueCount: 5),
        'hidden',
      );
    });

    test('hidden when nothing due', () {
      expect(
        reminderState(supported: true, permission: 'granted', dueCount: 0),
        'hidden',
      );
    });

    test('notify when granted with due cards', () {
      expect(
        reminderState(supported: true, permission: 'granted', dueCount: 5),
        'notify',
      );
    });

    test('opt-in when permission undecided', () {
      expect(
        reminderState(supported: true, permission: 'default', dueCount: 5),
        'opt-in',
      );
    });

    test('hidden when denied', () {
      expect(
        reminderState(supported: true, permission: 'denied', dueCount: 5),
        'hidden',
      );
    });
  });

  group('stub platform (VM)', () {
    test('reports unsupported and no-ops', () async {
      expect(await reviewNotifySupported(), isFalse);
      expect(await reviewNotifyPermission(), 'unsupported');
      expect(await requestReviewNotifyPermission(), 'unsupported');
      await showReviewNotification(5);
    });
  });
}
