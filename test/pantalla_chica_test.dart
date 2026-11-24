// Test de pantallas angostas: recorre las secciones con el tamaño de un
// celular chico (320x568). Cualquier desborde de diseno (RenderFlex
// overflowed, etc.) hace fallar el test.
//
// Usa un directorio PROPIO porque flutter test ejecuta los archivos en
// paralelo y comparten la carpeta de bases de datos.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'codigo_test_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:flutter_application_1/data/dbhelper.dart';
import 'package:flutter_application_1/data/fuente_datos.dart';
import 'package:flutter_application_1/main.dart';

final String _dirTest =
    '${Directory.systemTemp.path}${Platform.pathSeparator}finanzapp_test_dbs_pantalla_chica';

Future<void> esperarBD(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
  await tester.pump();
}

// Espera (en tiempo real) a que aparezca un widget: el arranque abre y
// migra la base, y puede tardar mas que una espera fija.
Future<void> esperarHasta(WidgetTester tester, Finder buscado) async {
  for (int i = 0; i < 50 && buscado.evaluate().isEmpty; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    FuenteDatos.usarMock = false;
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    final Directory dir = Directory(_dirTest);
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
    dir.createSync(recursive: true);
    await databaseFactory.setDatabasesPath(dir.path);
    await DbHelper().marcarIntroduccionVista();
  });

  setUp(() async {
    await DbHelper().cerrarSesion();
  });

  testWidgets('Las secciones principales no desbordan en una pantalla chica', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const FinanzApp());
    await tester.pumpAndSettle();
    await esperarHasta(tester, find.widgetWithText(OutlinedButton, 'Crear cuenta'));

    // Se crea una cuenta para llegar a las pantallas principales.
    await tester.tap(find.widgetWithText(OutlinedButton, 'Crear cuenta'));
    await tester.pumpAndSettle();
    await esperarBD(tester);
    await tester.enterText(find.byType(TextFormField).at(0), 'Chica Prueba');
    await tester.enterText(find.byType(TextFormField).at(1), 'chica@test.com');
    await tester.enterText(find.byType(TextFormField).at(2), '123456');
    await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Crear cuenta'));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Crear cuenta'));
    await tester.pumpAndSettle();
    await cerrarCodigoRecuperacion(tester);
    await esperarHasta(tester, find.text('Inicio'));
    await tester.pumpAndSettle();
    await esperarBD(tester);

    // Recorrido por la barra inferior.
    for (final String seccion in <String>['Mes', 'Grupo', 'Ahorro', 'Inicio']) {
      await tester.tap(find.text(seccion));
      await tester.pumpAndSettle();
      await esperarBD(tester);
    }

    // Menu del "+": quedo solo con gasto e ingreso (los servicios del hogar
    // ahora son una seccion de la pantalla Mes).
    await tester.tap(find.text('Inicio'));
    await tester.pumpAndSettle();
    await esperarBD(tester);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('Nuevo gasto'), findsOneWidget);
    expect(find.text('Nuevo ingreso'), findsOneWidget);
    expect(find.text('Servicios del hogar'), findsNothing);
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();

    // Perfil desde el avatar.
    await tester.tap(find.byTooltip('Mi perfil'));
    await tester.pumpAndSettle();
    await esperarBD(tester);
    expect(find.text('Mi Perfil'), findsOneWidget);
  });

  testWidgets(
    'Con movimientos cargados no desborda en una pantalla muy angosta',
    (WidgetTester tester) async {
      // Mas angosta que un celular chico: reproduce el desborde real de los
      // items de la lista cuando el monto es largo y la ventana es minima.
      tester.view.physicalSize = const Size(240, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const FinanzApp());
      await tester.pumpAndSettle();
      await esperarHasta(tester, find.widgetWithText(OutlinedButton, 'Crear cuenta'));

      await tester.tap(find.widgetWithText(OutlinedButton, 'Crear cuenta'));
      await tester.pumpAndSettle();
      await esperarBD(tester);
      await tester.enterText(find.byType(TextFormField).at(0), 'Chica Angosta');
      await tester.enterText(find.byType(TextFormField).at(1), 'angosta@test.com');
      await tester.enterText(find.byType(TextFormField).at(2), '123456');
      await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Crear cuenta'));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Crear cuenta'));
      await tester.pumpAndSettle();
      await cerrarCodigoRecuperacion(tester);
      await esperarHasta(tester, find.text('Inicio'));
      await tester.pumpAndSettle();
      await esperarBD(tester);

      // Un ingreso con monto largo: es el caso que desbordaba el item.
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nuevo ingreso'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byType(TextFormField).at(0), 'Sueldo mensual completo');
      await tester.enterText(find.byType(TextFormField).at(1), '1500000');
      await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Guardar'));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar'));
      await tester.pumpAndSettle();
      await esperarBD(tester);
      // Deja pasar el SnackBar ("ingreso agregado"): tapa el boton "+".
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      // Y un gasto con monto largo.
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nuevo gasto'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byType(TextFormField).at(0), 'Supermercado del barrio');
      await tester.enterText(find.byType(TextFormField).at(1), '1250000');
      await tester.ensureVisible(
          find.widgetWithText(ElevatedButton, 'Guardar gasto'));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar gasto'));
      await tester.pumpAndSettle();
      await esperarBD(tester);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      // Recorrido por las secciones con datos cargados.
      for (final String seccion in <String>['Mes', 'Grupo', 'Ahorro', 'Inicio']) {
        await tester.tap(find.text(seccion));
        await tester.pumpAndSettle();
        await esperarBD(tester);
      }
    },
  );
}
