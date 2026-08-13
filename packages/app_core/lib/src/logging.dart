enum LogLevel { debug, info, warn, error }

abstract class AppLogger {
  const AppLogger();

  void log(LogLevel level, String message, {Object? error, StackTrace? stackTrace});

  void debug(String message) => log(LogLevel.debug, message);
  void info(String message) => log(LogLevel.info, message);
  void warn(String message, {Object? error}) =>
      log(LogLevel.warn, message, error: error);
  void error(String message, {Object? error, StackTrace? stackTrace}) =>
      log(LogLevel.error, message, error: error, stackTrace: stackTrace);
}

final class ConsoleLogger extends AppLogger {
  const ConsoleLogger();
  @override
  void log(LogLevel level, String message, {Object? error, StackTrace? stackTrace}) {
    // ignore: avoid_print - the console IS this logger's sink.
    print('[${level.name}] $message${error == null ? '' : ' | $error'}');
  }
}

final class NoopLogger extends AppLogger {
  const NoopLogger();
  @override
  void log(LogLevel level, String message, {Object? error, StackTrace? stackTrace}) {}
}
