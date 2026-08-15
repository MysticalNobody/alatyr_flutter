import 'package_graph.dart';

String? packageNameFromUri(String uri) {
  if (!uri.startsWith('package:')) return null;
  final name = uri.substring('package:'.length).split('/').first;
  return name.isEmpty ? null : name;
}

String? boundaryViolation({
  required String fromKey,
  required String importedPackage,
  required PackageGraph graph,
}) {
  if (importedPackage == fromKey) return null;
  if (!graph.kinds.containsKey(importedPackage)) return null;
  if (graph.allowsAll.contains(fromKey)) return null;
  if ((graph.allowed[fromKey] ?? const []).contains(importedPackage)) {
    return null;
  }
  final importedKind = graph.kinds[importedPackage];
  return "'$fromKey' must not import '$importedPackage' ($importedKind). "
      'Cross-feature dependencies go only through *_api packages; only the '
      'app root assembles implementations. Source of truth: '
      'docs/reference/package_graph.yaml.';
}

String? bannedViolation({
  required String importedPackage,
  required PackageGraph graph,
}) {
  final reason = graph.banned[importedPackage];
  if (reason == null) return null;
  return "'$importedPackage' is banned without an ADR - $reason.";
}

String? pureCoreViolation({
  required String fromKey,
  required String importUri,
  required PackageGraph graph,
}) {
  if (!graph.pure.contains(fromKey)) return null;
  final pkg = packageNameFromUri(importUri);
  final flutterPackage = pkg != null && pkg.startsWith('flutter');
  final uiLibrary = importUri.startsWith('dart:ui');
  if (!flutterPackage && !uiLibrary) return null;
  return "pure Dart package '$fromKey' must not import "
      "'${pkg ?? importUri}' (Flutter/UI dependency).";
}
