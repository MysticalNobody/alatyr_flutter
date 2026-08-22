import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('light theme is light and uses Material 3', () {
    final theme = AppTheme.light();
    expect(theme.brightness, Brightness.light);
    expect(theme.useMaterial3, isTrue);
  });

  test('dark theme is dark', () {
    expect(AppTheme.dark().brightness, Brightness.dark);
  });

  test('spacing tokens grow monotonically', () {
    expect(
      [
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xl,
      ],
      [4, 8, 16, 24, 32],
    );
  });
}
