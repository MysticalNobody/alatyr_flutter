import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/docs_language.dart';

void _git(Directory root, List<String> args) {
  final result = Process.runSync('git', args, workingDirectory: root.path);
  if (result.exitCode != 0) {
    throw StateError('git ${args.join(' ')} failed: ${result.stderr}');
  }
}

void _write(Directory root, String path, String content) {
  File(p.join(root.path, path))
    ..createSync(recursive: true)
    ..writeAsStringSync(content);
}

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('alatyr-docs-language-');
    _git(root, ['init', '-q']);
  });
  tearDown(() => root.deleteSync(recursive: true));

  for (final tracked in [false, true]) {
    final state = tracked ? 'tracked' : 'untracked';

    test('$state localization, assets and test fixtures may use Cyrillic', () {
      const files = {
        'app/lib/l10n/app_ru.arb': '{"greeting":"Привет"}',
        'app/lib/localized_title.dart': "const title = 'Настройки';",
        'app/assets/help.md': '# Помощь',
        'app/android/app/src/main/res/values/strings.xml':
            '<resources><string name="app_name">Приложение</string></resources>',
        'test/fixtures/help.md': '# Пример',
        'packages/feature_settings/test/fixtures/input.json':
            '{"value":"тема"}',
      };
      for (final entry in files.entries) {
        _write(root, entry.key, entry.value);
      }
      if (tracked) _git(root, ['add', '.']);

      expect(findCyrillicDocumentation(root), isEmpty);
    });

    test('$state canonical documentation still rejects Cyrillic', () {
      const paths = [
        'README.md',
        'AGENTS.md',
        'CLAUDE.md',
        'app/README.md',
        'docs/testing/new-guide.md',
        'docs/workflow/superpowers/new guide.md',
      ];
      for (final path in paths) {
        _write(root, path, '# Документация');
      }
      if (tracked) _git(root, ['add', '.']);

      expect(findCyrillicDocumentation(root), unorderedEquals(paths));
    });
  }

  test('English documentation and ignored local notes pass', () {
    _write(
      root,
      '.gitignore',
      '*.ru.md\n/docs/superpowers/\nCLAUDE.local.md\n',
    );
    _write(root, 'README.md', '# Application');
    _write(root, 'docs/testing/strategy.md', '# Testing strategy');
    _write(root, 'docs/testing/strategy.ru.md', '# Стратегия тестирования');
    _write(root, 'docs/superpowers/plan.md', '# Локальный план');
    _write(root, 'CLAUDE.local.md', '# Личные настройки');

    expect(findCyrillicDocumentation(root), isEmpty);
  });

  test('local twins and plans stay outside policy even when tracked', () {
    _write(root, 'docs/testing/strategy.ru.md', '# Стратегия');
    _write(root, 'docs/superpowers/plan.md', '# План');
    _git(root, ['add', '.']);

    expect(findCyrillicDocumentation(root), isEmpty);
  });

  test('Git failure is reported instead of passing an empty scan', () {
    Directory(p.join(root.path, '.git')).deleteSync(recursive: true);

    expect(() => findCyrillicDocumentation(root), throwsStateError);
  });
}
