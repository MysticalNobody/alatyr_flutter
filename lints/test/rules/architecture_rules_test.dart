import 'dart:io';

import 'package:alatyr_lints/src/graph/graph_loader.dart';
import 'package:alatyr_lints/src/rules/banned_dependency_rule.dart';
import 'package:alatyr_lints/src/rules/boundary_import_rule.dart';
import 'package:alatyr_lints/src/rules/pure_core_rule.dart';
import 'package:analyzer/error/error.dart';
// ignore: implementation_imports
import 'package:analyzer/src/diagnostic/diagnostic.dart' as diag;
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:path/path.dart' as p;
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(BannedDependencyRuleTest);
    defineReflectiveTests(BoundaryImportRuleTest);
    defineReflectiveTests(BoundaryImportRuleOutsidePackageTest);
    defineReflectiveTests(PureCoreRuleTest);
    defineReflectiveTests(MissingGraphRuleTest);
  });
}

const _boundaryGraph = '''
packages:
  pkg:
    kind: impl
    allowed_dependencies:
      - foo_api
  foo_api:
    kind: api
    allowed_dependencies: []
  bar_impl:
    kind: impl
    allowed_dependencies: []
banned_packages:
  banned_pkg: "no ADR on file"
''';

const _pureGraph = '''
packages:
  pkg:
    kind: core
    allowed_dependencies: []
  foo_api:
    kind: api
    allowed_dependencies: []
pure_dart_packages:
  - pkg
''';

/// Wires a REAL on-disk temp directory into the harness.
///
/// [AnalysisRuleTest] analyzes files through an in-memory
/// [MemoryResourceProvider] that has no relationship to the real disk.
/// [GraphLoader], however, reads `docs/reference/package_graph.yaml` via
/// `dart:io` on the real filesystem (by design: it is shared with the CLI
/// tool, which must work outside any analyzer resource-provider context).
///
/// To exercise the rules honestly (not just their adapter functions in
/// isolation), this fixture points [workspaceRootPath] at a real temporary
/// directory and writes a REAL graph file into it with `dart:io`, at the
/// same absolute path string the in-memory analyzer also uses for
/// `context.definingUnit.file.path`. Both filesystems agree on paths, so
/// the rule under test performs a genuine disk read exactly as it would
/// under the real plugin host, while everything else about the analyzed
/// package (source files, `package_config.json`, `pubspec.yaml`) stays
/// in-memory as the harness intends.
///
/// See the Task 3 report for the alternatives considered and why this one
/// was chosen over a physical-tempdir-plus-`dart analyze` fallback.
mixin _RealDiskGraphFixture on AnalysisRuleTest {
  late final Directory _tempDir;

  @override
  String get workspaceRootPath => _tempDir.path;

  // Every fixture file here is a single, deliberately-unused import (the
  // point is the import directive itself, not what it imports) — silence
  // the unrelated `unused_import` hint so expectations stay focused on the
  // rule under test.
  @override
  List<DiagnosticCode> get ignoredDiagnosticCodes => [
    ...super.ignoredDiagnosticCodes,
    diag.unusedImport,
  ];

  /// Must be called first thing in `setUp()`, before `super.setUp()`, since
  /// `workspaceRootPath` is read while the superclass builds paths.
  void _initTempDir() {
    _tempDir = Directory.systemTemp.createTempSync('alatyr_lints_test_');
    GraphLoader.instance.clearForTesting();
  }

  void _writeGraph(String yaml) {
    final file = File(
      p.join(_tempDir.path, 'docs', 'reference', 'package_graph.yaml'),
    );
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(yaml);
  }

  @override
  Future<void> tearDown() async {
    await super.tearDown();
    GraphLoader.instance.clearForTesting();
    if (_tempDir.existsSync()) {
      _tempDir.deleteSync(recursive: true);
    }
  }
}

@reflectiveTest
class BannedDependencyRuleTest extends AnalysisRuleTest
    with _RealDiskGraphFixture {
  @override
  String get testPackageRootPath => '$workspaceRootPath/packages/pkg';

  @override
  void setUp() {
    rule = BannedDependencyRule();
    _initTempDir();
    newPackage('banned_pkg').addFile('lib/banned_pkg.dart', 'const x = 1;\n');
    newPackage('foo_api').addFile('lib/foo_api.dart', 'const x = 1;\n');
    super.setUp();
    _writeGraph(_boundaryGraph);
  }

  Future<void> test_bannedImport_firesWithReason() async {
    await assertDiagnostics(
      r'''
import 'package:banned_pkg/banned_pkg.dart';
''',
      [
        lint(0, 44, messageContainsAll: ['banned_pkg', 'no ADR on file']),
      ],
    );
  }

  Future<void> test_nonBannedImport_noDiagnostics() async {
    await assertNoDiagnostics(r'''
import 'package:foo_api/foo_api.dart';
''');
  }

  Future<void> test_dartImport_noDiagnostics() async {
    await assertNoDiagnostics(r'''
import 'dart:convert';
''');
  }

  Future<void> test_bannedExport_firesWithReason() async {
    await assertDiagnostics(
      r'''
export 'package:banned_pkg/banned_pkg.dart';
''',
      [
        lint(0, 44, messageContainsAll: ['banned_pkg', 'no ADR on file']),
      ],
    );
  }

  Future<void> test_conditionalImportBannedBranch_fires() async {
    await assertDiagnostics(
      r'''
import 'package:foo_api/foo_api.dart'
    if (dart.library.io) 'package:banned_pkg/banned_pkg.dart';
''',
      [
        lint(42, 57, messageContainsAll: ['banned_pkg', 'no ADR on file']),
      ],
    );
  }
}

@reflectiveTest
class BoundaryImportRuleTest extends AnalysisRuleTest
    with _RealDiskGraphFixture {
  @override
  String get testPackageRootPath => '$workspaceRootPath/packages/pkg';

  @override
  void setUp() {
    rule = BoundaryImportRule();
    _initTempDir();
    newPackage('foo_api').addFile('lib/foo_api.dart', 'const x = 1;\n');
    newPackage('bar_impl').addFile('lib/bar_impl.dart', 'const x = 1;\n');
    super.setUp();
    _writeGraph(_boundaryGraph);
  }

  Future<void> test_implToImpl_fires() async {
    await assertDiagnostics(
      r'''
import 'package:bar_impl/bar_impl.dart';
''',
      [
        lint(0, 40, messageContainsAll: ['boundary', 'pkg', 'bar_impl']),
      ],
    );
  }

  Future<void> test_apiImport_passes() async {
    await assertNoDiagnostics(r'''
import 'package:foo_api/foo_api.dart';
''');
  }

  Future<void> test_implToImplExport_fires() async {
    await assertDiagnostics(
      r'''
export 'package:bar_impl/bar_impl.dart';
''',
      [
        lint(0, 40, messageContainsAll: ['boundary', 'pkg', 'bar_impl']),
      ],
    );
  }

  Future<void> test_reexportAllowedApi_passes() async {
    await assertNoDiagnostics(r'''
export 'package:foo_api/foo_api.dart';
''');
  }
}

@reflectiveTest
class BoundaryImportRuleOutsidePackageTest extends AnalysisRuleTest
    with _RealDiskGraphFixture {
  // Deliberately do NOT override testPackageRootPath: the default test file
  // lives at `$workspaceRootPath/test/lib/test.dart`, which has neither a
  // `packages/<name>` nor an `app` path segment, so graphKeyForPath returns
  // null and the rule must silently no-op even though a valid graph exists
  // and the import below would otherwise violate the boundary.

  @override
  void setUp() {
    rule = BoundaryImportRule();
    _initTempDir();
    newPackage('bar_impl').addFile('lib/bar_impl.dart', 'const x = 1;\n');
    super.setUp();
    _writeGraph(_boundaryGraph);
  }

  Future<void> test_fileOutsideAnyPackage_noDiagnostics() async {
    await assertNoDiagnostics(r'''
import 'package:bar_impl/bar_impl.dart';
''');
  }
}

@reflectiveTest
class PureCoreRuleTest extends AnalysisRuleTest with _RealDiskGraphFixture {
  @override
  bool get addFlutterPackageDep => true;

  @override
  String get testPackageRootPath => '$workspaceRootPath/packages/pkg';

  @override
  void setUp() {
    rule = PureCoreRule();
    _initTempDir();
    newPackage('foo_api').addFile('lib/foo_api.dart', 'const x = 1;\n');
    super.setUp();
    _writeGraph(_pureGraph);
  }

  Future<void> test_flutterImport_firesFromPurePackage() async {
    await assertDiagnostics(
      r'''
import 'package:flutter/material.dart';
''',
      [
        lint(0, 39, messageContainsAll: ['purity', 'pkg', 'flutter']),
      ],
    );
  }

  Future<void> test_nonFlutterImport_passes() async {
    await assertNoDiagnostics(r'''
import 'package:foo_api/foo_api.dart';
''');
  }

  Future<void> test_flutterExport_firesFromPurePackage() async {
    await assertDiagnostics(
      r'''
export 'package:flutter/material.dart';
''',
      [
        lint(0, 39, messageContainsAll: ['purity', 'pkg', 'flutter']),
      ],
    );
  }
}

@reflectiveTest
class MissingGraphRuleTest extends AnalysisRuleTest with _RealDiskGraphFixture {
  @override
  String get testPackageRootPath => '$workspaceRootPath/packages/pkg';

  @override
  void setUp() {
    rule = BannedDependencyRule();
    _initTempDir();
    newPackage('banned_pkg').addFile('lib/banned_pkg.dart', 'const x = 1;\n');
    super.setUp();
    // Deliberately do NOT write docs/reference/package_graph.yaml:
    // GraphLoader.graphFor must return null, and the rule must silently
    // no-op even for an import that would otherwise be banned.
  }

  Future<void> test_missingGraph_noDiagnostics() async {
    await assertNoDiagnostics(r'''
import 'package:banned_pkg/banned_pkg.dart';
''');
  }
}
