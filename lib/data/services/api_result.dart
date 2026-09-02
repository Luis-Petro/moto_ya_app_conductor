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
  const Failure(
    this.message, {
    this.statusCode,
    this.codigo,
    this.kind = FailureKind.unknown,
  });

  final String message;
  final int? statusCode;

  /// Marca estable del caso, cuando el servidor la manda.
  ///
  /// Existe para los pocos sitios donde la app tiene que **reaccionar distinto** a
  /// dos errores del mismo código HTTP — hoy solo uno: el registro con un celular
  /// que ya tiene cuenta, que lleva a esa persona a entrar con su código en vez de
  /// a un muro. Comparar el texto del mensaje también "funcionaría", y dejaría de
  /// hacerlo el día que alguien le corrija una tilde en el servidor, sin que nada
  /// fallara aquí.
  final String? codigo;
  final FailureKind kind;

  bool get isNetwork => kind == FailureKind.network;
  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => 'Failure($statusCode, $message)';
}

enum FailureKind { network, server, validation, unauthorized, notFound, unknown }
