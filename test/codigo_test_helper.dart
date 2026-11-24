// Ayuda compartida por los tests de interfaz: al crear una cuenta aparece el
// codigo de recuperacion (se muestra una sola vez). Este helper espera a que
// aparezca y lo cierra con "Ya lo guardé".

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Espera (en tiempo real) a que aparezca un widget. El arranque de la app abre
// y migra la base y restaura la sesion: eso necesita varios ciclos de E/S real
// antes de mostrar la pantalla, mas de los que da una espera fija.
Future<void> esperarHasta(WidgetTester tester, Finder buscado) async {
  for (int i = 0; i < 50 && buscado.evaluate().isEmpty; i++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
  }
}

Future<void> cerrarCodigoRecuperacion(WidgetTester tester) async {
  final Finder boton = find.widgetWithText(ElevatedButton, 'Ya lo guardé');
  final Finder registro = find.text('Nueva cuenta');
  // El codigo se genera con una consulta a la base, asi que hay que esperar
  // en tiempo real. Si la pantalla de registro ya no esta, no hay codigo.
  for (int i = 0; i < 20; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
    if (boton.evaluate().isNotEmpty) {
      await tester.tap(boton);
      await tester.pumpAndSettle();
      return;
    }
    if (registro.evaluate().isEmpty) {
      return;
    }
  }
}
