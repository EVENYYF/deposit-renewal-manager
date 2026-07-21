import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android notification icon is retained from resource shrinking', () {
    final icon = File('android/app/src/main/res/drawable/ic_notification.xml');
    final keep = File('android/app/src/main/res/raw/keep.xml');

    expect(icon.existsSync(), isTrue);
    expect(keep.existsSync(), isTrue);
    expect(keep.readAsStringSync(), contains('@drawable/ic_notification'));
  });
}
