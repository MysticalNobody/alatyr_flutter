# 05 — Error handling

Two types carry every recoverable failure across a layer boundary:
`Result<T>` and `AppFailure`. Everything unrecoverable is a Dart `Error`
and is left to propagate.

## `Result<T>` — `Ok` or `Err`, nothing else

```dart
sealed class Result<T> {
  R fold<R>({
    required R Function(T value) ok,
    required R Function(AppFailure failure) err,
  });
}
final class Ok<T> extends Result<T> { final T value; }
final class Err<T> extends Result<T> { final AppFailure failure; }
```

`Result` deliberately has **no `operator ==` override**: two `Result`
values are compared by pattern-matching their shape (`isA<Ok<T>>()`, or
`fold`), not by equality — an equality override here would invite tests
that compare a whole `Result` against a literal and silently ignore which
branch actually matched.

## `AppFailure` — a stable, loggable value

```dart
final class AppFailure {
  const AppFailure({required this.code, required this.message, this.cause});
  final String code;    // `<area>.<reason>`
  final String message; // human-readable, safe to log
  final Object? cause;
}
```

Unlike `Result`, `AppFailure` **does** have value equality: `==` and
`hashCode` cover `code` and `message` only, with `cause` deliberately
excluded (an arbitrary `Object?` has no useful equality). So
`expect(failure, const AppFailure(code: ..., message: ...))` works and
ignores whatever exception was wrapped.

Codes so far: `config.invalid-env`, `config.invalid-url` (`app_config`),
`settings.load-failed`, `settings.save-failed` (`feature_settings`),
`secure.read-failed`, `secure.write-failed`, `secure.delete-failed`
(`data_secure`). The `<area>.<reason>` shape is a convention, not an enum —
a new area or reason needs no shared registry edit.

## Adapters convert exceptions only; `Error`s propagate

A port implementation catches `on Exception` and maps it to an `Err`;
anything that is not an `Exception` (an `Error` — a programming fault) is
left to crash. `SettingsRepository.saveThemeMode` states the rule in its
own doc comment:

> Converts exceptions only - `Error`s (e.g. drift's `StateError` on a
> closed database) are programming faults and propagate.

`FlutterSecureStore` follows the same shape: every operation is `async`
and guarded by `on Exception`, because the underlying plugin's
`PlatformException`/`MissingPluginException` surface as a rejected future
rather than a synchronous throw once wrapped in `async`.

## Failure messages never carry keys or values

`AppFailure.message` names the failed operation ("Secure storage read
failed", "Could not persist the theme mode") and never the key or the
value involved — a failure is as likely to end up in a log line as in the
UI, and a stored value can itself be sensitive.

## Where a failure surfaces

`SettingsBloc` keeps the failure on its `SettingsReady.lastFailure` field
rather than as a one-shot event, so a rebuild after the failure still shows
it: the settings screen reads `lastFailure` from state and renders it
through `SettingsKeys.failureBanner` (see [03](03-feature-contract.md)).
There is deliberately no dismiss action: the banner remains until
persistence emits a changed stored value, which creates a fresh
`SettingsReady` without `lastFailure`.
`AppLogger` carries the cases a user does not need to see: a corrupted
stored theme mode falls back to `ThemeMode.system` and logs a warning
instead of surfacing an `AppFailure`, and `App` logs a warning if the theme
mode stream itself ever errors (the port's own doc says it never should).
