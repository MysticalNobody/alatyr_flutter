import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import '../tool/src/import_validator.dart';

void main() {
  group('collectPackageImports', () {
    test('reads imports and exports', () {
      const src = '''
import 'package:a/a.dart';
export 'package:b/b.dart';
import 'dart:async';
import 'src/local.dart';
''';
      expect(collectPackageImports(src), ['a', 'b']);
    });

    test('ignores directives inside comments and strings', () {
      const src = '''
// import 'package:evil/evil.dart';
/* import 'package:evil2/e.dart'; */
const s = "import 'package:evil3/e.dart';";
const r = r"import 'package:evil4/e.dart';";
const t = \'\'\'
import 'package:evil5/e.dart';
\'\'\';
import 'package:good/g.dart';
''';
      expect(collectPackageImports(src), ['good']);
    });

    test('collects every URI of a conditional directive', () {
      const src = '''
import 'stub.dart'
    if (dart.library.io) 'package:io_impl/io.dart'
    if (dart.library.html) 'package:web_impl/web.dart';
''';
      expect(collectPackageImports(src), ['io_impl', 'web_impl']);
    });
  });

  group('validateImports', () {
    final root = p.join('test', 'fixtures', 'workspaces', 'imports');
    late final List<String> v;
    setUpAll(() => v = validateImports(rootDir: root, graphPath: 'graph.yaml'));

    test('pure package importing flutter is reported', () {
      expect(v.join('\n'), contains('packages/a/lib/a.dart'));
    });
    test('disallowed member edge in lib/ is reported with position', () {
      expect(
        v.join('\n'),
        matches(RegExp(r'packages/b/lib/b\.dart:\d+:\d+: .*data_local')),
      );
    });
    test('boundary rule exempts test/, banned rule does not', () {
      expect(v.join('\n'), isNot(contains('b_test.dart: import of member')));
      expect(v.join('\n'), contains('get_it'));
    });
    test('secret-shaped identifier in data_local lib is reported', () {
      expect(
        v.join('\n'),
        allOf(contains('dao.dart'), contains('data_secure')),
      );
    });
    test('exact violation count', () => expect(v, hasLength(4)));
  });
}
