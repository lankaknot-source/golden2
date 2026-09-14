import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:golden_hand_care/main.dart';

void main() {
  testWidgets('App starts with the branded splash screen', (tester) async {
    await tester.pumpWidget(const GoldenHandApp());
    expect(find.text('GOLDEN HAND'), findsOneWidget);
    expect(find.text('CAREGIVERS'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Dispose the splash before its login redirect, which needs Firebase.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });
}
