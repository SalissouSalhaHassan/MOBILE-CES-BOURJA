import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/main.dart';

void main() {
  testWidgets('shows the Edut splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.byIcon(Icons.school), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
