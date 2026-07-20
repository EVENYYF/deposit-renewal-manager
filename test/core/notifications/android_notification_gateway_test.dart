import 'package:deposit_renewal_manager/core/notifications/android_notification_scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('deposit_renewal_manager/settings');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('uses a drawable resource name without an Android resource prefix', () {
    expect(AndroidNotificationGateway.notificationIcon, 'ic_notification');
    expect(AndroidNotificationGateway.notificationIcon, isNot(startsWith('@')));
  });

  test('returns true when Android settings activity starts', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'openAppSettings');
      return true;
    });

    expect(await AndroidNotificationGateway.openApplicationSettings(), isTrue);
  });

  test('returns false when platform invocation throws', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => throw PlatformException(code: 'ACTIVITY_NOT_FOUND'),
    );

    expect(await AndroidNotificationGateway.openApplicationSettings(), isFalse);
  });

  test('returns false for an unsuccessful platform result', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => null);

    expect(await AndroidNotificationGateway.openApplicationSettings(), isFalse);
  });
}
