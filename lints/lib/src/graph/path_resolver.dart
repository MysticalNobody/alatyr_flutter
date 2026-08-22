import 'package_graph.dart';

/// Maps an absolute file path to its package-graph key, or null when the
/// file lives outside any graphed package (tool/, root test/, ...).
///
/// [root] is the repo root that [GraphLoader] discovered for this file (the
/// directory holding docs/reference/package_graph.yaml). Resolution is
/// anchored there: only the FIRST path segments below the root decide the
/// key - `packages/<name>/...` maps to `<name>` when the graph knows it, and
/// `app/...` maps to the single `app_root` entry. Segments above the root
/// (a clone living at `/home/u/app/...` or `/srv/packages/app_core/...`)
/// and segments deeper inside a package (`lib/packages/x/`) never take
/// part, which is what a left-to-right scan of the full path got wrong.
String? graphKeyForPath({
  required String filePath,
  required PackageGraph graph,
  required String root,
}) {
  final file = _normalize(filePath);
  var base = _normalize(root);
  if (!base.endsWith('/')) base = '$base/';
  if (!file.startsWith(base)) return null;
  final segments = file.substring(base.length).split('/');
  if (segments.length < 3) return null; // <dir>/<name>/<file> at minimum
  if (segments[0] == 'packages' && graph.kinds.containsKey(segments[1])) {
    return segments[1];
  }
  if (segments[0] == 'app') {
    final appRoots = graph.kinds.entries
        .where((e) => e.value == 'app_root')
        .toList();
    if (appRoots.length == 1) return appRoots.single.key;
  }
  return null;
}

String _normalize(String path) => path.replaceAll(r'\', '/');
