import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol_finders/patrol_finders.dart';

void main() {
  patrolWidgetTest('shows the title in an app bar and the body below', (
    $,
  ) async {
    await $.pumpWidgetAndSettle(
      const MaterialApp(
        home: AppPageScaffold(
          key: ValueKey<String>('demo.page'),
          title: 'Demo',
          body: Text('body'),
        ),
      ),
    );
    expect($(AppBar).$('Demo'), findsOneWidget);
    expect($(#demo.page).$('body'), findsOneWidget);
  });
}
