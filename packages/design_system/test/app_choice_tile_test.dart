import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol_finders/patrol_finders.dart';

const _key = ValueKey<String>('demo.choice.alpha');

Future<void> _pump(
  PatrolTester $, {
  required bool selected,
  VoidCallback? onTap,
}) {
  return $.pumpWidgetAndSettle(
    MaterialApp(
      home: Scaffold(
        body: AppChoiceTile(
          key: _key,
          title: 'Alpha',
          subtitle: 'First option',
          selected: selected,
          onTap: onTap ?? () {},
        ),
      ),
    ),
  );
}

void main() {
  patrolWidgetTest('renders title and subtitle under its key', ($) async {
    await _pump($, selected: false);
    expect($(_key), findsOneWidget);
    expect($(_key).$('Alpha'), findsOneWidget);
    expect($(_key).$('First option'), findsOneWidget);
  });

  patrolWidgetTest('shows a check mark only when selected', ($) async {
    await _pump($, selected: true);
    expect($(Icons.check), findsOneWidget);
    await _pump($, selected: false);
    expect($(Icons.check), findsNothing);
  });

  patrolWidgetTest('tap invokes onTap exactly once', ($) async {
    var taps = 0;
    await _pump($, selected: false, onTap: () => taps++);
    await $(_key).tap();
    expect(taps, 1);
  });
}
