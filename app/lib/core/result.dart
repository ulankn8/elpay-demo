import 'failure.dart';

/// Результат операции: либо данные, либо [AppFailure].
///
/// Репозитории возвращают `Result`, а не бросают исключения, —
/// тогда экран обязан обработать ошибку, иначе код не скомпилируется.
sealed class Result<T> {
  const Result();

  const factory Result.ok(T value) = Ok<T>;
  const factory Result.fail(AppFailure failure) = Fail<T>;

  bool get isOk => this is Ok<T>;
  bool get isFail => this is Fail<T>;

  /// Данные или null — для мест, где ошибка уже обработана отдельно.
  T? get valueOrNull => switch (this) {
        Ok<T>(:final value) => value,
        Fail<T>() => null,
      };

  AppFailure? get failureOrNull => switch (this) {
        Ok<T>() => null,
        Fail<T>(:final failure) => failure,
      };

  R fold<R>(R Function(T value) onOk, R Function(AppFailure failure) onFail) =>
      switch (this) {
        Ok<T>(:final value) => onOk(value),
        Fail<T>(:final failure) => onFail(failure),
      };

  Result<R> map<R>(R Function(T value) f) => switch (this) {
        Ok<T>(:final value) => Ok<R>(f(value)),
        Fail<T>(:final failure) => Fail<R>(failure),
      };

  /// Разворачивает значение, бросая [AppFailure]. Только там, где
  /// вызывающий код ловит ошибку сам (например, в AsyncNotifier).
  T unwrap() => switch (this) {
        Ok<T>(:final value) => value,
        Fail<T>(:final failure) => throw failure,
      };
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;
}

final class Fail<T> extends Result<T> {
  const Fail(this.failure);
  final AppFailure failure;
}

/// Оборачивает вызов, превращая исключения в [AppFailure].
Future<Result<T>> guard<T>(Future<T> Function() body) async {
  try {
    return Ok(await body());
  } on AppFailure catch (e) {
    return Fail(e);
  } catch (e) {
    return Fail(AppFailure(FailureKind.unknown, message: '$e', cause: e));
  }
}
