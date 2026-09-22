import 'package:flutter_test/flutter_test.dart';

import 'package:golden_hand_care/app.dart';

void main() {
  test('updated app root can be constructed', () {
    expect(const CareApp(), isA<CareApp>());
  });
}
