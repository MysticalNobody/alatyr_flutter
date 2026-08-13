import 'package:app_core/app_core.dart';
import 'package:test/test.dart';

final class _RecordingLogger extends AppLogger {
  final List<String> lines = [];
  @override
  void log(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    lines.add('${level.name}: $message');
  }
}

void main() {
  test('level helpers delegate to log', () {
    final logger = _RecordingLogger()
      ..debug('d')
      ..info('i')
      ..warn('w')
      ..error('e');
    expect(logger.lines, ['debug: d', 'info: i', 'warn: w', 'error: e']);
  });

  test('NoopLogger swallows everything', () {
    expect(() => const NoopLogger().error('boom'), returnsNormally);
  });
}
