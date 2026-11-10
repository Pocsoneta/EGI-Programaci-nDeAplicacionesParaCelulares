// Tests de la logica del plan de ahorro (cuanto ahorrar por semana y por mes).
// Son logica pura: no usan base de datos ni interfaz.

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/model/model.dart';
import 'package:flutter_application_1/util/utils.dart';

String _iso(DateTime fecha) {
  final String mes = fecha.month.toString().padLeft(2, '0');
  final String dia = fecha.day.toString().padLeft(2, '0');
  return '${fecha.year}-$mes-$dia';
}

void main() {
  final DateTime hoy = DateTime(2026, 11, 10);

  group('calcularPlanAhorro', () {
    test('Reparte lo que falta entre las semanas y los meses que quedan', () {
      // 70 dias: 10 semanas y 3 meses (redondeando hacia arriba).
      final MetaAhorro meta = MetaAhorro(
        'Vacaciones', 'Viajes', 15000, 0, _iso(hoy.add(const Duration(days: 70))));

      final PlanAhorro? plan = calcularPlanAhorro(meta, hoy);

      expect(plan, isNotNull);
      expect(plan!.estado, EstadoPlanAhorro.enCurso);
      expect(plan.faltante, 15000);
      expect(plan.semanas, 10);
      expect(plan.meses, 3);
      expect(plan.porSemana, 1500);
      expect(plan.porMes, 5000);
    });

    test('Descuenta lo ya ahorrado del importe', () {
      final MetaAhorro meta = MetaAhorro(
        'Auto', 'Otros', 10000, 4000, _iso(hoy.add(const Duration(days: 14))));

      final PlanAhorro plan = calcularPlanAhorro(meta, hoy)!;

      expect(plan.faltante, 6000);
      expect(plan.semanas, 2);
      expect(plan.porSemana, 3000);
      expect(plan.meses, 1);
      expect(plan.porMes, 6000);
    });

    test('Redondea hacia arriba: 8 dias son 2 semanas, nunca subestima', () {
      final MetaAhorro meta = MetaAhorro(
        'Regalo', 'Otros', 1000, 0, _iso(hoy.add(const Duration(days: 8))));

      final PlanAhorro plan = calcularPlanAhorro(meta, hoy)!;

      expect(plan.semanas, 2);
      expect(plan.porSemana, 500);
    });

    test('Una meta ya cumplida queda completada sin plan', () {
      final MetaAhorro meta = MetaAhorro(
        'Listo', 'Otros', 5000, 7000, _iso(hoy.add(const Duration(days: 30))));

      final PlanAhorro plan = calcularPlanAhorro(meta, hoy)!;

      expect(plan.estado, EstadoPlanAhorro.completada);
      expect(plan.faltante, 0);
      expect(plan.porSemana, 0);
      expect(plan.porMes, 0);
    });

    test('Una fecha que ya pasó (o es hoy) queda vencida', () {
      final MetaAhorro ayer = MetaAhorro(
        'Viejo', 'Otros', 1000, 100, _iso(hoy.subtract(const Duration(days: 1))));
      final MetaAhorro hoyMismo = MetaAhorro('Hoy', 'Otros', 1000, 100, _iso(hoy));

      expect(calcularPlanAhorro(ayer, hoy)!.estado, EstadoPlanAhorro.vencida);
      expect(calcularPlanAhorro(hoyMismo, hoy)!.estado, EstadoPlanAhorro.vencida);
    });

    test('Una fecha invalida no genera plan', () {
      final MetaAhorro meta = MetaAhorro('Sin fecha', 'Otros', 1000, 0, 'manana');

      expect(calcularPlanAhorro(meta, hoy), isNull);
    });
  });
}
