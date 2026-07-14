// crew_gui/test/app_test.dart
import 'package:crew_gui/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('CrewApp renders its home', (tester) async {
    await tester.pumpWidget(
      const CrewApp(home: Scaffold(body: Text('hello'))),
    );
    expect(find.text('hello'), findsOneWidget);
  });
}
