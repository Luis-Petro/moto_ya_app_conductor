/// Resultado tipado de una operación de datos. Evita que los errores de red se
/// filtren como excepciones crudas hacia la UI.
sealed class Result<T> {
  const Result();

  bool get isSuccess => this is Ok<T>;

  /// Valor o `null` si fue error.
  T? get valueOrNull => this is Ok<T> ? (this as Ok<T>).value : null;

  R when<R>({
    required R Function(T value) ok,
    required R Function(Failure failure) err,
  }) {
    final self = this;
    if (self is Ok<T>) return ok(self.value);
    return err((self as Err<T>).failure);
  }
}

class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;
}

class Err<T> extends Result<T> {
  const Err(this.failure);
  final Failure failure;
}

/// Error de dominio normalizado.
class Failure {
  const Failure(this.message, {this.statusCode, this.kind = FailureKind.unknown});

  final String message;
  final int? statusCode;
  final FailureKind kind;

  bool get isNetwork => kind == FailureKind.network;
  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => 'Failure($statusCode, $message)';
}

enum FailureKind { network, server, validation, unauthorized, notFound, unknown }
