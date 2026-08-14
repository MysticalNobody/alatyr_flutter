import 'package:app_core/app_core.dart';
import 'package:test/test.dart';

void main() {
  const failure = AppFailure(code: 'demo.failed', message: 'demo');

  test('Ok exposes value and folds through ok branch', () {
    const Result<int> r = Ok(42);
    expect(r.isOk, isTrue);
    expect(r.valueOrNull, 42);
    expect(r.failureOrNull, isNull);
    expect(r.fold(ok: (v) => v + 1, err: (_) => 0), 43);
  });

  test('Err exposes failure and folds through err branch', () {
    const Result<int> r = Err(failure);
    expect(r.isOk, isFalse);
    expect(r.valueOrNull, isNull);
    expect(r.failureOrNull, failure);
    expect(r.fold(ok: (_) => 'ok', err: (f) => f.code), 'demo.failed');
  });

  test('AppFailure equality is by code and message', () {
    expect(failure, const AppFailure(code: 'demo.failed', message: 'demo'));
    expect(failure, isNot(const AppFailure(code: 'demo.failed', message: 'x')));
  });
}
