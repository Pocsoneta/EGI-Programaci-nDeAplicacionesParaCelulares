// Entidades de datos de la aplicacion FinanzApp.
//
// Todas siguen el mismo patron:
//  * `id` nullable (todavia no persistido hasta que se guarda en SQLite)
//  * Constructor estandar `X(...)`    -> objetos nuevos creados en la UI
//  * Constructor nombrado `X.withId(...)` -> objetos recuperados de la base
//  * `toMap()`     -> Objeto Dart -> Map<String, dynamic> (fila de SQLite)
//  * `fromObject()` -> Map<String, dynamic> -> Objeto Dart tipado

/// Representacion logica de un gasto financiero.
class Gasto {
  int? id; // Identificador autoincremental de la DB (null antes de persistir)
  String concepto; // Concepto del gasto (ej. "Alquiler")
  double monto; // Monto del gasto
  String categoria; // Categoria del gasto (ej. "Servicios")
  String expiration; // Fecha del gasto (cuando se pago) en formato YYYY-MM-DD
  // Flags de alerta. Quedan por compatibilidad con las bases existentes: ya
  // no generan notificaciones (los gastos no vencen).
  int fqYear;
  int fqHalfYear;
  int fqMonth;

  // Constructor estandar: para gastos nuevos creados en la interfaz visual.
  Gasto(this.concepto, this.monto, this.categoria, this.expiration, this.fqYear,
      this.fqHalfYear, this.fqMonth, [this.id]);

  // Constructor nombrado: para gastos recuperados desde la base de datos.
  Gasto.withId(this.id, this.concepto, this.monto, this.categoria,
      this.expiration, this.fqYear, this.fqHalfYear, this.fqMonth);

  // Serializacion: Objeto Dart -> Map<String, dynamic> (fila de SQLite)
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};
    if (id != null) {
      map['id'] = id;
    }
    map['concepto'] = concepto;
    map['monto'] = monto;
    map['categoria'] = categoria;
    map['expiration'] = expiration;
    map['fqYear'] = fqYear;
    map['fqHalfYear'] = fqHalfYear;
    map['fqMonth'] = fqMonth;
    return map;
  }

  // Deserializacion: Map<String, dynamic> (fila de SQLite) -> Objeto Dart tipado
  factory Gasto.fromObject(dynamic o) => Gasto.withId(
        o['id'],
        o['concepto'] ?? '',
        (o['monto'] as num?)?.toDouble() ?? 0.0,
        o['categoria'] ?? '',
        o['expiration'] ?? '',
        (o['fqYear'] as num?)?.toInt() ?? 0,
        (o['fqHalfYear'] as num?)?.toInt() ?? 0,
        (o['fqMonth'] as num?)?.toInt() ?? 0,
      );
}

/// Ingreso economico del usuario (sueldo, venta, freelance, etc.).
class Ingreso {
  int? id; // null hasta persistir
  String concepto; // Descripcion del ingreso (ej. "Sueldo")
  double monto; // Monto recibido
  String fecha; // Fecha en formato String YYYY-MM-DD

  // Constructor estandar: para ingresos nuevos creados en la interfaz visual.
  Ingreso(this.concepto, this.monto, this.fecha, [this.id]);

  // Constructor nombrado: para ingresos recuperados desde la base de datos.
  Ingreso.withId(this.id, this.concepto, this.monto, this.fecha);

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};
    if (id != null) {
      map['id'] = id;
    }
    map['concepto'] = concepto;
    map['monto'] = monto;
    map['fecha'] = fecha;
    return map;
  }

  factory Ingreso.fromObject(dynamic o) => Ingreso.withId(
        o['id'],
        o['concepto'] ?? '',
        (o['monto'] as num?)?.toDouble() ?? 0.0,
        o['fecha'] ?? '',
      );
}

/// Meta de ahorro del usuario (ej. "Vacaciones de Verano").
class MetaAhorro {
  int? id; // null hasta persistir
  String titulo; // Nombre de la meta
  String categoria; // Categoria de la meta (ej. "Viajes")
  double montoObjetivo; // Monto que se quiere alcanzar
  double montoAhorrado; // Monto acumulado hasta ahora
  String fechaObjetivo; // Fecha limite en formato String YYYY-MM-DD

  // Constructor estandar: para metas nuevas creadas en la interfaz visual.
  MetaAhorro(this.titulo, this.categoria, this.montoObjetivo,
      this.montoAhorrado, this.fechaObjetivo, [this.id]);

  // Constructor nombrado: para metas recuperadas desde la base de datos.
  MetaAhorro.withId(this.id, this.titulo, this.categoria, this.montoObjetivo,
      this.montoAhorrado, this.fechaObjetivo);

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};
    if (id != null) {
      map['id'] = id;
    }
    map['titulo'] = titulo;
    map['categoria'] = categoria;
    map['montoObjetivo'] = montoObjetivo;
    map['montoAhorrado'] = montoAhorrado;
    map['fechaObjetivo'] = fechaObjetivo;
    return map;
  }

  factory MetaAhorro.fromObject(dynamic o) => MetaAhorro.withId(
        o['id'],
        o['titulo'] ?? '',
        o['categoria'] ?? '',
        (o['montoObjetivo'] as num?)?.toDouble() ?? 0.0,
        (o['montoAhorrado'] as num?)?.toDouble() ?? 0.0,
        o['fechaObjetivo'] ?? '',
      );
}

/// Grupo de gastos compartidos (ej. "Asado Fin de Semana").
class Grupo {
  int? id; // null hasta persistir
  String nombre; // Nombre del grupo
  String emoji; // Icono del grupo (un emoji)

  Grupo(this.nombre, this.emoji, [this.id]);

  Grupo.withId(this.id, this.nombre, this.emoji);

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};
    if (id != null) {
      map['id'] = id;
    }
    map['nombre'] = nombre;
    map['emoji'] = emoji;
    return map;
  }

  factory Grupo.fromObject(dynamic o) => Grupo.withId(
        o['id'],
        o['nombre'] ?? '',
        o['emoji'] ?? '🧾',
      );
}

/// Persona que participa de un grupo. `esYo` marca al usuario de la cuenta.
class Participante {
  int? id; // null hasta persistir
  int grupoId; // Grupo al que pertenece
  String nombre; // Nombre de la persona
  bool esYo; // true para el usuario de la cuenta

  Participante(this.grupoId, this.nombre, this.esYo, [this.id]);

  Participante.withId(this.id, this.grupoId, this.nombre, this.esYo);

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};
    if (id != null) {
      map['id'] = id;
    }
    map['grupoId'] = grupoId;
    map['nombre'] = nombre;
    map['esYo'] = esYo ? 1 : 0;
    return map;
  }

  factory Participante.fromObject(dynamic o) => Participante.withId(
        o['id'],
        (o['grupoId'] as num?)?.toInt() ?? 0,
        o['nombre'] ?? '',
        (o['esYo'] as num?)?.toInt() == 1,
      );
}

/// Gasto compartido: lo pagó un participante y se divide entre varios.
/// `movimientoId` apunta al gasto personal que registra TU parte en el Saldo
/// total (0 si no te toca ninguna parte).
class GastoGrupo {
  int? id; // null hasta persistir
  int grupoId; // Grupo al que pertenece
  String titulo; // Descripcion (ej. "Carne")
  double monto; // Total del gasto
  int pagadoPor; // Id del participante que pago
  String fecha; // YYYY-MM-DD
  int movimientoId; // Gasto personal con tu parte (0 si no hay)

  GastoGrupo(this.grupoId, this.titulo, this.monto, this.pagadoPor, this.fecha,
      [this.id, this.movimientoId = 0]);

  GastoGrupo.withId(this.id, this.grupoId, this.titulo, this.monto,
      this.pagadoPor, this.fecha, this.movimientoId);

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};
    if (id != null) {
      map['id'] = id;
    }
    map['grupoId'] = grupoId;
    map['titulo'] = titulo;
    map['monto'] = monto;
    map['pagadoPor'] = pagadoPor;
    map['fecha'] = fecha;
    map['movimientoId'] = movimientoId;
    return map;
  }

  factory GastoGrupo.fromObject(dynamic o) => GastoGrupo.withId(
        o['id'],
        (o['grupoId'] as num?)?.toInt() ?? 0,
        o['titulo'] ?? '',
        (o['monto'] as num?)?.toDouble() ?? 0.0,
        (o['pagadoPor'] as num?)?.toInt() ?? 0,
        o['fecha'] ?? '',
        (o['movimientoId'] as num?)?.toInt() ?? 0,
      );
}

/// Parte de un gasto compartido que le toca a un participante.
class ParteGasto {
  int? id; // null hasta persistir
  int gastoId; // Gasto compartido al que pertenece
  int grupoId; // Grupo (para consultar las partes de todo el grupo)
  int participanteId; // Quien debe esta parte
  double monto; // Cuanto le toca

  ParteGasto(this.gastoId, this.grupoId, this.participanteId, this.monto,
      [this.id]);

  ParteGasto.withId(this.id, this.gastoId, this.grupoId, this.participanteId,
      this.monto);

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};
    if (id != null) {
      map['id'] = id;
    }
    map['gastoId'] = gastoId;
    map['grupoId'] = grupoId;
    map['participanteId'] = participanteId;
    map['monto'] = monto;
    return map;
  }

  factory ParteGasto.fromObject(dynamic o) => ParteGasto.withId(
        o['id'],
        (o['gastoId'] as num?)?.toInt() ?? 0,
        (o['grupoId'] as num?)?.toInt() ?? 0,
        (o['participanteId'] as num?)?.toInt() ?? 0,
        (o['monto'] as num?)?.toDouble() ?? 0.0,
      );
}

/// Cuánto puso una persona para pagar un gasto compartido. Un gasto puede
/// tener varios: la suma de los aportes es el monto total del gasto.
class AporteGasto {
  int? id; // null hasta persistir
  int gastoId; // Gasto compartido al que pertenece
  int grupoId; // Grupo (para consultar los aportes de todo el grupo)
  int participanteId; // Quien puso plata
  double monto; // Cuanto puso

  AporteGasto(this.gastoId, this.grupoId, this.participanteId, this.monto,
      [this.id]);

  AporteGasto.withId(this.id, this.gastoId, this.grupoId, this.participanteId,
      this.monto);

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};
    if (id != null) {
      map['id'] = id;
    }
    map['gastoId'] = gastoId;
    map['grupoId'] = grupoId;
    map['participanteId'] = participanteId;
    map['monto'] = monto;
    return map;
  }

  factory AporteGasto.fromObject(dynamic o) => AporteGasto.withId(
        o['id'],
        (o['gastoId'] as num?)?.toInt() ?? 0,
        (o['grupoId'] as num?)?.toInt() ?? 0,
        (o['participanteId'] as num?)?.toInt() ?? 0,
        (o['monto'] as num?)?.toDouble() ?? 0.0,
      );
}

/// Reembolso registrado: `deudor` le pagó `monto` a `acreedor` dentro del grupo.
/// No cambia el Saldo total: la parte propia ya se registró al crear el gasto.
class PagoGrupo {
  int? id; // null hasta persistir
  int grupoId; // Grupo al que pertenece
  int deudorId; // Quien pago
  int acreedorId; // Quien recibio
  double monto; // Monto pagado
  String fecha; // YYYY-MM-DD

  PagoGrupo(this.grupoId, this.deudorId, this.acreedorId, this.monto, this.fecha,
      [this.id]);

  PagoGrupo.withId(this.id, this.grupoId, this.deudorId, this.acreedorId,
      this.monto, this.fecha);

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};
    if (id != null) {
      map['id'] = id;
    }
    map['grupoId'] = grupoId;
    map['deudorId'] = deudorId;
    map['acreedorId'] = acreedorId;
    map['monto'] = monto;
    map['fecha'] = fecha;
    return map;
  }

  factory PagoGrupo.fromObject(dynamic o) => PagoGrupo.withId(
        o['id'],
        (o['grupoId'] as num?)?.toInt() ?? 0,
        (o['deudorId'] as num?)?.toInt() ?? 0,
        (o['acreedorId'] as num?)?.toInt() ?? 0,
        (o['monto'] as num?)?.toDouble() ?? 0.0,
        o['fecha'] ?? '',
      );
}

/// Servicio o gasto fijo del hogar (ej. "Luz (Edemsa)").
class ServicioHogar {
  int? id; // null hasta persistir
  String titulo; // Nombre del servicio
  String detalle; // Detalle (ej. "Vence el 22/09 • Pendiente")
  double monto; // Monto del servicio
  int pagado; // 1 si esta pagado, 0 si esta pendiente
  // Id del gasto que se creo al marcar el servicio como pagado (0 si no
  // tiene): permite reflejar el pago en gastos y deshacerlo al desmarcar.
  int gastoId;

  // Constructor estandar: para servicios nuevos creados en la interfaz visual.
  ServicioHogar(this.titulo, this.detalle, this.monto, this.pagado,
      [this.id, this.gastoId = 0]);

  // Constructor nombrado: para servicios recuperados desde la base de datos.
  ServicioHogar.withId(this.id, this.titulo, this.detalle, this.monto,
      this.pagado,
      [this.gastoId = 0]);

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};
    if (id != null) {
      map['id'] = id;
    }
    map['titulo'] = titulo;
    map['detalle'] = detalle;
    map['monto'] = monto;
    map['pagado'] = pagado;
    map['gastoId'] = gastoId;
    return map;
  }

  factory ServicioHogar.fromObject(dynamic o) => ServicioHogar.withId(
        o['id'],
        o['titulo'] ?? '',
        o['detalle'] ?? '',
        (o['monto'] as num?)?.toDouble() ?? 0.0,
        (o['pagado'] as num?)?.toInt() ?? 0,
        (o['gastoId'] as num?)?.toInt() ?? 0,
      );
}

/// Entidad que representa un usuario de la aplicacion.
class Usuario {
  int? id; // Identificador del usuario (unico en el registro global)
  String nombre; // Nombre del usuario
  String email; // Correo electronico de la cuenta
  String password; // Contrasena de la cuenta

  // Constructor estandar: para usuarios nuevos (sin id asignado todavia).
  Usuario(this.nombre, this.email, this.password, [this.id]);

  // Constructor nombrado: para usuarios recuperados desde la base de datos.
  Usuario.withId(this.id, this.nombre, this.email, this.password);

  // Serializacion: Objeto Dart -> Map<String, dynamic> (fila de SQLite)
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};
    if (id != null) {
      map['id'] = id;
    }
    map['nombre'] = nombre;
    map['email'] = email;
    map['password'] = password;
    return map;
  }

  // Deserializacion: Map<String, dynamic> (fila de SQLite) -> Objeto Dart tipado
  factory Usuario.fromObject(dynamic o) => Usuario.withId(
        o['id'],
        o['nombre'] ?? '',
        o['email'] ?? '',
        o['password'] ?? '',
      );
}
