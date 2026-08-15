// Fires alatyr_no_widget_returning_function exactly once: buildHeader
// returns a bare Widget and isn't named `build`, so it fires. The
// top-level `build` function is the control - same shape, but exempt by
// name - and must stay clean.
import 'stubs.dart';

Widget buildHeader() => Widget();

Widget build() => Widget();
