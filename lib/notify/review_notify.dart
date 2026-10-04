export 'review_notify_stub.dart'
    if (dart.library.js_interop) 'review_notify_web.dart';

/// Decides the reminder UI state from platform support, permission, and due.
///
/// Returns 'opt-in' when the user can enable reminders, 'notify' when a
/// notification should be shown now, and 'hidden' otherwise.
String reminderState({
  required bool supported,
  required String permission,
  required int dueCount,
}) {
  if (!supported || dueCount <= 0) return 'hidden';
  if (permission == 'granted') return 'notify';
  if (permission == 'default') return 'opt-in';
  return 'hidden';
}
