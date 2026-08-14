/// Stable, machine-readable failure value carried across layer boundaries.
final class AppFailure {
  const AppFailure({required this.code, required this.message, this.cause});

  /// Stable code, `<area>.<reason>` (e.g. `config.invalid-url`).
  final String code;
  final String message;
  final Object? cause;

  @override
  bool operator ==(Object other) =>
      other is AppFailure && other.code == code && other.message == message;

  @override
  int get hashCode => Object.hash(code, message);

  @override
  String toString() => 'AppFailure($code: $message)';
}
