import 'package_graph.dart';

/// Maps an absolute file path to its package-graph key, or null when the
/// file lives outside any graphed package (tool/, root test/, ...).
String? graphKeyForPath({
  required String filePath,
  required PackageGraph graph,
}) {
  final segments = filePath.replaceAll(r'\', '/').split('/');
  for (var i = 0; i < segments.length - 1; i++) {
    if (segments[i] == 'packages' && graph.kinds.containsKey(segments[i + 1])) {
      return segments[i + 1];
    }
  }
  if (segments.contains('app')) {
    final appRoots = graph.kinds.entries
        .where((e) => e.value == 'app_root')
        .toList();
    if (appRoots.length == 1) return appRoots.single.key;
  }
  return null;
}
