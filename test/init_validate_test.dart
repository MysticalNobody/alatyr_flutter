import 'package:test/test.dart';

import '../tool/src/init_validate.dart';

void main() {
  test(
    'valid name and org map to both bundle-id shapes, a title-case display name and the workspace name',
    () {
      final t = validateTarget(name: 'my_app', org: 'com.example');
      expect(t.bundleIdSnake, 'com.example.my_app');
      expect(t.bundleIdCamel, 'com.example.myApp');
      expect(t.displayName, 'My App');
      expect(t.workspaceName, 'my_app_workspace');
    },
  );

  test('an explicit display name wins', () {
    expect(
      validateTarget(
        name: 'my_app',
        org: 'com.example',
        displayName: 'Nimbus',
      ).displayName,
      'Nimbus',
    );
  });

  test('names must be lowercase_with_underscores identifiers', () {
    for (final bad in ['MyApp', '1app', 'my-app', 'my app', '', '_x']) {
      expect(
        () => validateTarget(name: bad, org: 'com.example'),
        throwsA(isA<InitArgumentException>()),
        reason: bad,
      );
    }
  });

  test('Dart keywords and Flutter-reserved package names are rejected', () {
    for (final bad in [
      'class',
      'switch',
      'flutter',
      'flutter_test',
      'meta',
      'collection',
    ]) {
      expect(
        () => validateTarget(name: bad, org: 'com.example'),
        throwsA(isA<InitArgumentException>()),
        reason: bad,
      );
    }
  });

  test(
    'org must be a lowercase reverse domain of [a-z][a-z0-9]* segments (no underscores: Apple bundle ids)',
    () {
      for (final bad in [
        'example',
        'Com.Example',
        'com.',
        'com..example',
        'com.1x',
        'com.ex-ample',
        'com.my_org',
      ]) {
        expect(
          () => validateTarget(name: 'my_app', org: bad),
          throwsA(isA<InitArgumentException>()),
          reason: bad,
        );
      }
    },
  );

  test(
    'display names are limited to characters every generated shell can carry verbatim',
    () {
      for (final bad in [
        "O'Brien",
        'A&B',
        'Line\nBreak',
        'Back\\slash',
        '"Quoted"',
        ' leading',
      ]) {
        expect(
          () => validateTarget(
            name: 'my_app',
            org: 'com.example',
            displayName: bad,
          ),
          throwsA(isA<InitArgumentException>()),
          reason: bad,
        );
      }
      expect(
        validateTarget(
          name: 'my_app',
          org: 'com.example',
          displayName: 'My App 2.0 - Beta',
        ).displayName,
        'My App 2.0 - Beta',
      );
    },
  );

  test(
    'Java keywords are rejected as org segments and as the name (Android package rule)',
    () {
      expect(
        () => validateTarget(name: 'my_app', org: 'io.long.org'),
        throwsA(predicate((e) => e.toString().contains("'long'"))),
      );
      expect(
        () => validateTarget(name: 'native', org: 'com.example'),
        throwsA(isA<InitArgumentException>()),
      );
    },
  );

  test('a name colliding with an existing workspace member is rejected', () {
    const members = ['app_core', 'feature_settings', 'alatyr_starter'];
    for (final bad in members) {
      expect(
        () => validateTarget(
          name: bad,
          org: 'com.example',
          workspaceMembers: members,
        ),
        throwsA(
          predicate(
            (e) => e.toString().contains('already a package in this workspace'),
          ),
        ),
        reason: bad,
      );
    }
    expect(
      validateTarget(
        name: 'my_app',
        org: 'com.example',
        workspaceMembers: members,
      ).name,
      'my_app',
    );
  });

  test(
    'Windows reserved device names are rejected as the name and as an org segment',
    () {
      for (final bad in ['con', 'prn', 'aux', 'nul', 'com1', 'lpt9']) {
        expect(
          () => validateTarget(name: bad, org: 'com.example'),
          throwsA(predicate((e) => e.toString().contains('Windows reserved'))),
          reason: bad,
        );
        expect(
          () => validateTarget(name: 'my_app', org: 'com.$bad'),
          throwsA(predicate((e) => e.toString().contains('Windows reserved'))),
          reason: 'com.$bad',
        );
      }
      // com10/lpt0 are not reserved.
      expect(validateTarget(name: 'com10', org: 'com.example').name, 'com10');
    },
  );

  test(
    '--template-url must be a http(s) URL that survives a markdown link',
    () {
      for (final bad in [
        '',
        'not a url',
        'ftp://example.invalid/t',
        'https://example.invalid/a(b)',
        'https://example.invalid/a<b>',
        'https://example.invalid/a b',
      ]) {
        expect(
          () => validateTemplateUrl(bad),
          throwsA(isA<InitArgumentException>()),
          reason: '"$bad"',
        );
      }
      expect(
        () => validateTemplateUrl('https://example.invalid/alatyr.git'),
        returnsNormally,
      );
      expect(
        () => validateTemplateUrl('http://example.invalid/t?ref=a&b=c'),
        returnsNormally,
      );
    },
  );
}
