import 'dbhelper.dart';
import 'gasto_repository.dart';
import '../model/model.dart';
import '../util/grupo_calculos.dart';

// Todo lo que cuelga de un grupo: participantes, gastos compartidos, partes de
// cada gasto y reembolsos registrados. Los saldos no se guardan: se calculan
// desde estos datos (ver DatosGrupo).
//
// Tu parte de cada gasto compartido se registra como un gasto personal (en
// Gastos, con categoria General) para que el Saldo total quede correcto. Los
// reembolsos NO crean movimientos: la parte propia ya quedo registrada.
class GrupoRepository {
  static const String _tablaGrupos = 'grupos';
  static const String _tablaParticipantes = 'grupo_participantes';
  static const String _tablaGastos = 'grupo_gastos';
  static const String _tablaPartes = 'grupo_gasto_partes';
  static const String _tablaAportes = 'grupo_gasto_aportes';
  static const String _tablaPagos = 'grupo_pagos';

  // READ: todos los grupos, ordenados por nombre.
  Future<List<Grupo>> getGrupos() async {
    final List<Map<String, dynamic>> filas =
        await DbHelper().listar(_tablaGrupos, orden: 'nombre ASC');
    return filas.map(Grupo.fromObject).toList();
  }

  // READ: datos completos de un grupo (para saldos y reembolsos).
  Future<DatosGrupo> cargarGrupo(Grupo grupo) async {
    final int id = grupo.id!;
    return DatosGrupo(
      grupo: grupo,
      participantes: await getParticipantes(id),
      gastos: await getGastos(id),
      partes: await _getPartes(id),
      aportes: await getAportes(id),
      pagos: await getPagos(id),
    );
  }

  // CREATE: crea el grupo con sus participantes. El primero debe ser el usuario.
  Future<int> crearGrupo(Grupo grupo, List<Participante> participantes) async {
    final int id = await DbHelper().insertar(_tablaGrupos, grupo.toMap());
    for (final Participante participante in participantes) {
      participante.grupoId = id;
      await DbHelper().insertar(_tablaParticipantes, participante.toMap());
    }
    return id;
  }

  // UPDATE: cambia el nombre o el emoji del grupo.
  Future<void> updateGrupo(Grupo grupo) async {
    await DbHelper().actualizar(_tablaGrupos, grupo.toMap());
  }

  // DELETE: borra el grupo con todo lo que contiene. Los gastos personales que
  // registraban tu parte tambien se borran, para que el Saldo total no quede
  // con movimientos de un grupo que ya no existe.
  Future<void> deleteGrupo(int id) async {
    final List<GastoGrupo> gastos = await getGastos(id);
    for (final GastoGrupo gasto in gastos) {
      await _borrarMovimiento(gasto);
    }
    await DbHelper().eliminarDonde(_tablaPagos, 'grupoId = ?', [id]);
    await DbHelper().eliminarDonde(_tablaAportes, 'grupoId = ?', [id]);
    await DbHelper().eliminarDonde(_tablaPartes, 'grupoId = ?', [id]);
    await DbHelper().eliminarDonde(_tablaGastos, 'grupoId = ?', [id]);
    await DbHelper().eliminarDonde(_tablaParticipantes, 'grupoId = ?', [id]);
    await DbHelper().eliminar(_tablaGrupos, id);
  }

  // READ: participantes del grupo, en el orden en que se cargaron.
  Future<List<Participante>> getParticipantes(int grupoId) async {
    final List<Map<String, dynamic>> filas = await DbHelper().listar(
      _tablaParticipantes,
      where: 'grupoId = ?',
      args: [grupoId],
      orden: 'id ASC',
    );
    return filas.map(Participante.fromObject).toList();
  }

  // CREATE: agrega una persona al grupo.
  Future<int> addParticipante(Participante participante) async {
    return await DbHelper().insertar(_tablaParticipantes, participante.toMap());
  }

  // READ: gastos del grupo, del mas nuevo al mas viejo.
  Future<List<GastoGrupo>> getGastos(int grupoId) async {
    final List<Map<String, dynamic>> filas = await DbHelper().listar(
      _tablaGastos,
      where: 'grupoId = ?',
      args: [grupoId],
      orden: 'fecha DESC, id DESC',
    );
    return filas.map(GastoGrupo.fromObject).toList();
  }

  Future<List<ParteGasto>> _getPartes(int grupoId) async {
    final List<Map<String, dynamic>> filas = await DbHelper().listar(
      _tablaPartes,
      where: 'grupoId = ?',
      args: [grupoId],
    );
    return filas.map(ParteGasto.fromObject).toList();
  }

  // READ: quien puso plata y cuanto, de todo el grupo.
  Future<List<AporteGasto>> getAportes(int grupoId) async {
    final List<Map<String, dynamic>> filas = await DbHelper().listar(
      _tablaAportes,
      where: 'grupoId = ?',
      args: [grupoId],
    );
    return filas.map(AporteGasto.fromObject).toList();
  }

  // READ: partes de un gasto concreto (para editarlo).
  Future<List<ParteGasto>> getPartesDeGasto(int gastoId) async {
    final List<Map<String, dynamic>> filas = await DbHelper().listar(
      _tablaPartes,
      where: 'gastoId = ?',
      args: [gastoId],
    );
    return filas.map(ParteGasto.fromObject).toList();
  }

  // READ: reembolsos registrados del grupo.
  Future<List<PagoGrupo>> getPagos(int grupoId) async {
    final List<Map<String, dynamic>> filas = await DbHelper().listar(
      _tablaPagos,
      where: 'grupoId = ?',
      args: [grupoId],
      orden: 'id ASC',
    );
    return filas.map(PagoGrupo.fromObject).toList();
  }

  // CREATE / UPDATE: guarda un gasto compartido con sus partes, quien puso
  // plata (aportes) y sincroniza tu parte en el Saldo total. `yoId` es el
  // participante que es el usuario. La suma de los aportes debe ser el monto.
  Future<void> guardarGasto({
    required GastoGrupo gasto,
    required List<ParteGasto> partes,
    required List<AporteGasto> aportes,
    required int? yoId,
    required String nombreGrupo,
  }) async {
    if (gasto.id != null) {
      final GastoGrupo anterior = GastoGrupo.withId(
        gasto.id,
        gasto.grupoId,
        gasto.titulo,
        gasto.monto,
        gasto.pagadoPor,
        gasto.fecha,
        gasto.movimientoId,
      );
      await _borrarMovimiento(anterior);
      gasto.movimientoId = 0;
      await DbHelper().actualizar(_tablaGastos, gasto.toMap());
      await DbHelper().eliminarDonde(_tablaPartes, 'gastoId = ?', [gasto.id]);
      await DbHelper().eliminarDonde(_tablaAportes, 'gastoId = ?', [gasto.id]);
    } else {
      gasto.id = await DbHelper().insertar(_tablaGastos, gasto.toMap());
    }

    for (final ParteGasto parte in partes) {
      parte.gastoId = gasto.id!;
      parte.grupoId = gasto.grupoId;
      await DbHelper().insertar(_tablaPartes, parte.toMap());
    }
    for (final AporteGasto aporte in aportes) {
      aporte.gastoId = gasto.id!;
      aporte.grupoId = gasto.grupoId;
      await DbHelper().insertar(_tablaAportes, aporte.toMap());
    }

    final double miParte = partes
        .where((ParteGasto p) => p.participanteId == yoId)
        .fold(0.0, (double total, ParteGasto p) => total + p.monto);
    if (miParte > 0) {
      gasto.movimientoId = await GastoRepository().addGasto(Gasto(
        '$nombreGrupo: ${gasto.titulo}',
        miParte,
        'General',
        gasto.fecha,
        0,
        0,
        0,
      ));
    }
    await DbHelper().actualizar(_tablaGastos, gasto.toMap());
  }

  // DELETE: borra un gasto compartido, sus partes, aportes y movimiento personal.
  Future<void> eliminarGasto(GastoGrupo gasto) async {
    await _borrarMovimiento(gasto);
    await DbHelper().eliminarDonde(_tablaPartes, 'gastoId = ?', [gasto.id]);
    await DbHelper().eliminarDonde(_tablaAportes, 'gastoId = ?', [gasto.id]);
    await DbHelper().eliminar(_tablaGastos, gasto.id!);
  }

  // CREATE: registra un reembolso (deudor le pagó al acreedor).
  Future<int> registrarPago(PagoGrupo pago) async {
    return await DbHelper().insertar(_tablaPagos, pago.toMap());
  }

  // DELETE: quita un reembolso registrado por error.
  Future<void> eliminarPago(int id) async {
    await DbHelper().eliminar(_tablaPagos, id);
  }

  Future<void> _borrarMovimiento(GastoGrupo gasto) async {
    if (gasto.movimientoId > 0) {
      await GastoRepository().deleteGasto(gasto.movimientoId);
    }
  }
}

// Datos de un grupo ya cargados, con los saldos y reembolsos calculados.
class DatosGrupo {
  final Grupo grupo;
  final List<Participante> participantes;
  final List<GastoGrupo> gastos;
  final List<ParteGasto> partes;
  final List<AporteGasto> aportes;
  final List<PagoGrupo> pagos;

  const DatosGrupo({
    required this.grupo,
    required this.participantes,
    required this.gastos,
    required this.partes,
    required this.aportes,
    required this.pagos,
  });

  // Participante que es el usuario (null si el grupo quedo sin el).
  int? get yoId {
    for (final Participante p in participantes) {
      if (p.esYo) {
        return p.id;
      }
    }
    return null;
  }

  // Neto de cada participante en centavos (+ le deben, - debe).
  Map<int, int> get netosEnCentavos => saldosNetosEnCentavos(
        participantes: participantes,
        gastos: gastos,
        partes: partes,
        pagos: pagos,
        aportes: aportes,
      );

  // Quienes pusieron plata para un gasto y cuanto, en el orden en que se
  // cargaron. Si el gasto no tiene aportes (base vieja), el que pago.
  List<AporteGasto> aportesDe(GastoGrupo gasto) {
    final List<AporteGasto> suyos =
        aportes.where((AporteGasto a) => a.gastoId == gasto.id).toList();
    if (suyos.isNotEmpty) {
      return suyos;
    }
    return <AporteGasto>[
      AporteGasto(gasto.id ?? 0, gasto.grupoId, gasto.pagadoPor, gasto.monto),
    ];
  }

  // Frase de quien pago: "Pagó Ana" o "Pusieron Ana y Beto".
  String fraseQuienPago(GastoGrupo gasto) {
    final List<AporteGasto> suyos = aportesDe(gasto);
    if (suyos.length == 1) {
      return 'Pagó ${nombreDe(suyos.first.participanteId)}';
    }
    final String nombres = suyos
        .map((AporteGasto a) => nombreDe(a.participanteId))
        .join(' y ');
    return 'Pusieron $nombres';
  }

  // Tu neto en pesos (+ te deben, - debés).
  double get miSaldo {
    final int? yo = yoId;
    if (yo == null) {
      return 0;
    }
    return (netosEnCentavos[yo] ?? 0) / 100;
  }

  // Reembolsos pendientes para dejar el grupo en cero.
  List<Reembolso> get reembolsos => calcularReembolsos(netosEnCentavos);

  // Nombre sin marcas (para las frases tipo "X le debe a Y").
  String nombreSimple(int participanteId) {
    for (final Participante p in participantes) {
      if (p.id == participanteId) {
        return p.nombre;
      }
    }
    return '';
  }

  // Nombre de un participante por id (vacio si no existe).
  String nombreDe(int participanteId) {
    for (final Participante p in participantes) {
      if (p.id == participanteId) {
        return p.esYo ? '${p.nombre} (yo)' : p.nombre;
      }
    }
    return '';
  }
}
