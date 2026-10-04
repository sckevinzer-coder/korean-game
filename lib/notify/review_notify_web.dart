import 'dart:js_interop';

import '../i18n/app_locale.dart';
import '../i18n/app_strings.dart';

@JS('Notification')
extension type _Notification._(JSObject _) implements JSObject {
  external static JSString get permission;
  external static JSPromise<JSString> requestPermission();
  external factory _Notification(JSString title, JSAny? options);
}

@JS('Notification')
external JSObject? get _notificationGlobal;

bool _hasNotification() {
  try {
    return _notificationGlobal != null;
  } catch (_) {
    return false;
  }
}

Future<bool> reviewNotifySupported() async => _hasNotification();

Future<String> reviewNotifyPermission() async {
  if (!_hasNotification()) return 'unsupported';
  try {
    return _Notification.permission.toDart;
  } catch (_) {
    return 'unsupported';
  }
}

Future<String> requestReviewNotifyPermission() async {
  if (!_hasNotification()) return 'unsupported';
  try {
    return (await _Notification.requestPermission().toDart).toDart;
  } catch (_) {
    return 'denied';
  }
}

Future<void> showReviewNotification(int dueCount,
    [AppLocale locale = AppLocale.japanese]) async {
  if (!_hasNotification()) return;
  try {
    if (_Notification.permission.toDart != 'granted') return;
    _Notification(
      tr(locale, 'notify.title').toJS,
      {
        'body': trParams(locale, 'notify.body', {'n': dueCount}),
      }.jsify(),
    );
  } catch (_) {}
}
