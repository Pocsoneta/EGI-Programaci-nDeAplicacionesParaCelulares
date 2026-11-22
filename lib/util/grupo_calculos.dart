// Calculos de los grupos de gastos compartidos. Son logica pura: no usan base
// de datos ni interfaz.
//
// Trabajan con centavos enteros para que las sumas sean exactas. Los saldos
// salen de los gastos: el neto de cada persona es lo que pagó menos lo que le
// toca, mas los reembolsos que hizo, menos los que recibió.

import '../model/model.dart';

/// Un reembolso: `deudor` le debe `monto` a `acreedor`.
class Reembolso {
  final int deudorId;
  final int acreedorId;
  final double monto;

  const Reembolso(this.deudorId, this.acreedorId, this.monto);
}

/// Neto de cada participante en centavos: positivo = le deben, negativo = debe.
/// Lo que se acredita a cada persona es lo que puso para cada gasto: los
/// aportes de `aportes`, o el total para `pagadoPor` si el gasto no tiene
/// aportes cargados (bases antiguas).
Map<int, int> saldosNetosEnCentavos({
  required List<Participante> participantes,
  required List<GastoGrupo> gastos,
  required List<ParteGasto> partes,
  required List<PagoGrupo> pagos,
  List<AporteGasto> aportes = const <AporteGasto>[],
}) {
  final Map<int, int> netos = <int, int>{
    for (final Participante p in participantes) p.id!: 0,
  };

  void sumar(int participanteId, int centavos) {
    if (netos.containsKey(participanteId)) {
      netos[participanteId] = netos[participanteId]! + centavos;
    }
  }

  final Map<int, List<AporteGasto>> aportesPorGasto = <int, List<AporteGasto>>{};
  for (final AporteGasto aporte in aportes) {
    aportesPorGasto.putIfAbsent(aporte.gastoId, () => <AporteGasto>[]).add(aporte);
  }
  for (final GastoGrupo gasto in gastos) {
    final List<AporteGasto> suyos = aportesPorGasto[gasto.id] ?? <AporteGasto>[];
    if (suyos.isEmpty) {
      sumar(gasto.pagadoPor, _aCentavos(gasto.monto));
    } else {
      for (final AporteGasto aporte in suyos) {
        sumar(aporte.participanteId, _aCentavos(aporte.monto));
      }
    }
  }
  for (final ParteGasto parte in partes) {
    sumar(parte.participanteId, -_aCentavos(parte.monto));
  }
  for (final PagoGrupo pago in pagos) {
    sumar(pago.deudorId, _aCentavos(pago.monto));
    sumar(pago.acreedorId, -_aCentavos(pago.monto));
  }
  return netos;
}

/// Reembolsos necesarios para dejar a todos en cero. Empareja a los que
/// deben con los que tienen que cobrar, de mayor a menor monto.
List<Reembolso> calcularReembolsos(Map<int, int> netosEnCentavos) {
  final List<MapEntry<int, int>> deudores = netosEnCentavos.entries
      .where((MapEntry<int, int> e) => e.value < 0)
      .map((MapEntry<int, int> e) => MapEntry<int, int>(e.key, -e.value))
      .toList()
    ..sort((MapEntry<int, int> a, MapEntry<int, int> b) => b.value.compareTo(a.value));
  final List<MapEntry<int, int>> acreedores = netosEnCentavos.entries
      .where((MapEntry<int, int> e) => e.value > 0)
      .map((MapEntry<int, int> e) => MapEntry<int, int>(e.key, e.value))
      .toList()
    ..sort((MapEntry<int, int> a, MapEntry<int, int> b) => b.value.compareTo(a.value));

  final List<Reembolso> reembolsos = <Reembolso>[];
  int i = 0;
  int j = 0;
  final List<int> restoDeudores = deudores.map((MapEntry<int, int> e) => e.value).toList();
  final List<int> restoAcreedores = acreedores.map((MapEntry<int, int> e) => e.value).toList();

  while (i < deudores.length && j < acreedores.length) {
    final int monto = restoDeudores[i] < restoAcreedores[j]
        ? restoDeudores[i]
        : restoAcreedores[j];
    reembolsos.add(Reembolso(
      deudores[i].key,
      acreedores[j].key,
      monto / 100,
    ));
    restoDeudores[i] -= monto;
    restoAcreedores[j] -= monto;
    if (restoDeudores[i] == 0) {
      i++;
    }
    if (restoAcreedores[j] == 0) {
      j++;
    }
  }
  return reembolsos;
}

/// Reparte `monto` entre `cantidad` personas en partes iguales, con centavos
/// exactos: la suma de las partes es siempre `monto`. Si sobra algún centavo,
/// va a las primeras partes.
List<double> dividirIgual(double monto, int cantidad) {
  if (cantidad <= 0) {
    return <double>[];
  }
  final int total = _aCentavos(monto);
  final int base = total ~/ cantidad;
  final int resto = total % cantidad;
  return List<double>.generate(
    cantidad,
    (int i) => (base + (i < resto ? 1 : 0)) / 100,
  );
}

int _aCentavos(double monto) => (monto * 100).round();
