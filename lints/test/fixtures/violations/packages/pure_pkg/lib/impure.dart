// Fires alatyr_pure_core exactly once: pure_pkg is declared a pure Dart
// package in the mini graph, and this is a Flutter/UI import. The import
// is deliberately unresolvable (this fixture has zero pubspec deps) - the
// rule is purely syntactic and checks the URI text, not a resolved
// element, so an `uri_does_not_exist` analyzer error alongside the plugin
// warning is expected and does not collide with the integration script's
// grep.
import 'package:flutter/widgets.dart';
