// Two independent violations, one each:
//  - alatyr_boundary_import: feat_a has allowed_dependencies: [] in the
//    mini graph, so importing feat_b (a graphed sibling package) crosses
//    the boundary.
//  - alatyr_banned_dependency: get_it is listed under banned_packages.
// Both `package:` URIs are deliberately unresolvable (zero pubspec deps) -
// the rules are syntactic and only read the URI text.
import 'package:feat_b/stubs.dart';
import 'package:get_it/get_it.dart';
