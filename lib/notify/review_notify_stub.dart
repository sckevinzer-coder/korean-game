/// Non-web implementation: notifications unsupported, all calls no-op.
Future<bool> reviewNotifySupported() async => false;

Future<String> reviewNotifyPermission() async => 'unsupported';

Future<String> requestReviewNotifyPermission() async => 'unsupported';

Future<void> showReviewNotification(int dueCount) async {}
