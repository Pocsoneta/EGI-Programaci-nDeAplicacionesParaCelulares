// Tests del modo oscuro: la paleta clara/oscura, los temas de Material y el
// boton de la cabecera que enciende y apaga el modo (con su persistencia).
//
// Usa un directorio PROPIO porque flutter test ejecuta los archivos en
// paralelo y comparten la carpeta de bases de datos.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'codigo_test_helper.dart';
import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/data/dbhelper.dart';
import 'package:flutter_application_1/data/fuente_datos.dart';
import 'package:flutter_application_1/util/tema.dart';

final String _dirTest =
    '${Directory.systemTemp.path}${Platform.pathSeparator}finanzapp_test_dbs_tema';

Future<void> esperarBD(WidgetTester tester) async {
  await tester
      .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
  await tester.pump();
}

// Crea una cuenta y deja la app en el inicio (misma secuencia que el resto).
Future<void> crearCuenta(WidgetTester tester,
    {required String nombre, required String email}) async {
  await esperarHasta(tester, find.widgetWithText(OutlinedButton, 'Crear cuenta'));
  await tester.tap(find.widgetWithText(OutlinedButton, 'Crear cuenta'));
  await tester.pumpAndSettle();
  await esperarBD(tester);

  await tester.enterText(find.byType(TextFormField).at(0), nombre);
  await tester.enterText(find.byType(TextFormField).at(1), email);
  await tester.enterText(find.byType(TextFormField).at(2), '123456');

  await tester.tap(find.widgetWithText(ElevatedButton, 'Crear cuenta'));
  await tester.pumpAndSettle();
  await cerrarCodigoRecuperacion(tester);
  await esperarHasta(tester, find.text('Saldo total'));
  await esperarBD(tester);
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

  // Cada test arranca en claro (el control es un singleton que persiste).
  setUp(() async {
    await DbHelper().cerrarSesion();
    await DbHelper().guardarTemaOscuro(false);
    await TemaControl.instancia.cargar();
  });

  test('La paleta clara conserva los colores originales', () {
    expect(AppColores.claro.fondo, const Color(0xFFF6F8FC));
    expect(AppColores.claro.superficie, const Color(0xFFFFFFFF));
    expect(AppColores.claro.titulo, const Color(0xFF1E3C72));
  });

  test('El tema oscuro tiene brillo oscuro y fondo oscuro', () {
    final ThemeData claro = temaClaro();
    final ThemeData oscuro = temaOscuro();
    expect(claro.brightness, Brightness.light);
    expect(oscuro.brightness, Brightness.dark);
    expect(oscuro.scaffoldBackgroundColor, AppColores.oscuro.fondo);
    expect(oscuro.extension<AppColores>(), AppColores.oscuro);
    // El fondo oscuro es claramente mas oscuro que el claro.
    expect(AppColores.oscuro.fondo.computeLuminance(),
        lessThan(AppColores.claro.fondo.computeLuminance()));
  });

  testWidgets(
    'El boton de la cabecera enciende el modo oscuro y lo recuerda',
    (WidgetTester tester) async {
      await tester.pumpWidget(const FinanzApp());
      await tester.pumpAndSettle();
      await crearCuenta(tester, nombre: 'Tema Prueba', email: 'tema@test.com');
      // Deja asentar el marco de la barra inferior antes de tocar la cabecera.
      await tester.pumpAndSettle();

      // Arranca en claro: el boton ofrece pasar a oscuro.
      expect(find.byTooltip('Modo oscuro'), findsOneWidget);
      expect(find.byTooltip('Modo claro'), findsNothing);
      expect(TemaControl.instancia.oscuro, isFalse);

      await tester.tap(find.byTooltip('Modo oscuro'));
      await tester.pumpAndSettle();
      await esperarBD(tester);

      // Queda en oscuro y el boton ahora ofrece volver a claro.
      expect(TemaControl.instancia.oscuro, isTrue);
      expect(find.byTooltip('Modo claro'), findsOneWidget);
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.dark,
      );

      // La eleccion se guardo en disco para el proximo arranque.
      final bool guardado = await tester
              .runAsync(() => DbHelper().temaOscuroGuardado()) ??
          false;
      expect(guardado, isTrue);

      // Y se puede volver a claro.
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Modo claro'));
      await tester.pumpAndSettle();
      await esperarBD(tester);
      expect(TemaControl.instancia.oscuro, isFalse);
      expect(find.byTooltip('Modo oscuro'), findsOneWidget);
    },
  );
}
