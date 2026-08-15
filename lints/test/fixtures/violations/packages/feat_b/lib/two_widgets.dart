// Fires alatyr_one_widget_per_file exactly once: two public
// StatelessWidget subclasses in one file. The rule reports on every class
// from the 2nd onward, so exactly one diagnostic (on HomePage) for exactly
// two classes.
import 'stubs.dart';

class HomeCard extends StatelessWidget {}

class HomePage extends StatelessWidget {}
