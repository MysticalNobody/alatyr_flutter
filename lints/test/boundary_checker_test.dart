import 'package:alatyr_lints/src/graph/boundary_checker.dart';
import 'package:alatyr_lints/src/graph/package_graph.dart';
import 'package:test/test.dart';

const _graph = '''
package_kinds: [base, feature_api, feature_impl, app_root]
banned_packages:
  get_it: "manual constructor DI (spec section 5)"
  riverpod: "bloc is the canonical state management"
pure_dart_packages: [app_core]
packages:
  app_core: { kind: base, allowed_dependencies: [] }
  design_system: { kind: base, allowed_dependencies: [app_core] }
  feature_settings_api: { kind: feature_api, allowed_dependencies: [app_core] }
  feature_settings:
    { kind: feature_impl,
      allowed_dependencies: [feature_settings_api, app_core, design_system] }
  feature_home:
    { kind: feature_impl, allowed_dependencies: [app_core] }
  demo_app: { kind: app_root, allowed_dependencies: "*_all_members" }
''';

void main() {
  final g = PackageGraph.tryParse(_graph)!;

  group('packageNameFromUri', () {
    test('extracts package name', () {
      expect(packageNameFromUri('package:app_core/src/x.dart'), 'app_core');
    });
    test('null for dart: and relative URIs', () {
      expect(packageNameFromUri('dart:async'), isNull);
      expect(packageNameFromUri('src/local.dart'), isNull);
    });
  });

  group('boundaryViolation', () {
    String? check(String from, String to) =>
        boundaryViolation(fromKey: from, importedPackage: to, graph: g);

    test('impl importing sibling impl is a violation', () {
      expect(
        check('feature_home', 'feature_settings'),
        allOf(contains('feature_home'), contains('feature_settings')),
      );
    });
    test('impl importing api is allowed', () {
      expect(check('feature_settings', 'feature_settings_api'), isNull);
    });
    test('app_root (sentinel) may import anything graphed', () {
      expect(check('demo_app', 'feature_settings'), isNull);
    });
    test('self-import and external packages are ignored', () {
      expect(check('app_core', 'app_core'), isNull);
      expect(check('app_core', 'collection'), isNull);
    });
  });

  group('bannedViolation', () {
    test('banned package fires with reason', () {
      expect(
        bannedViolation(importedPackage: 'get_it', graph: g),
        contains('manual constructor DI'),
      );
    });
    test('canonical stack does not fire', () {
      expect(
        bannedViolation(importedPackage: 'flutter_bloc', graph: g),
        isNull,
      );
    });
  });

  group('pureCoreViolation', () {
    String? check(String from, String uri) =>
        pureCoreViolation(fromKey: from, importUri: uri, graph: g);

    test('pure package importing flutter* fires', () {
      expect(check('app_core', 'package:flutter/widgets.dart'), isNotNull);
      expect(
        check('app_core', 'package:flutter_bloc/flutter_bloc.dart'),
        isNotNull,
      );
    });
    test('pure package importing dart:ui fires', () {
      expect(check('app_core', 'dart:ui'), isNotNull);
      expect(check('app_core', 'dart:ui_web'), isNotNull);
    });
    test('non-pure package is exempt; pure importing pure deps is fine', () {
      expect(check('design_system', 'package:flutter/widgets.dart'), isNull);
      expect(check('app_core', 'dart:async'), isNull);
    });
  });
}
