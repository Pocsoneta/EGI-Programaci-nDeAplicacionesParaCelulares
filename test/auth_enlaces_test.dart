// Tests de los enlaces entre login y registro.
//
// Usa un directorio PROPIO porque flutter test ejecuta los archivos en
// paralelo y comparten la carpeta de bases de datos.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:flutter_application_1/data/dbhelper.dart';
import 'package:flutter_application_1/data/fuente_datos.dart';
import 'package:flutter_application_1/main.dart';

final String _dirTest =
    '${Directory.systemTemp.path}${Platform.pathSeparator}finanzapp_test_dbs_auth_enlaces';

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

  testWidgets('Desde el registro se puede pasar a iniciar sesion', (WidgetTester tester) async {
    await tester.pumpWidget(const FinanzApp());
    await tester.pumpAndSettle();
    await esperarHasta(tester, find.widgetWithText(OutlinedButton, 'Crear cuenta'));

    await tester.tap(find.widgetWithText(OutlinedButton, 'Crear cuenta'));
    await tester.pumpAndSettle();
    await esperarBD(tester);
    expect(find.text('Nueva cuenta'), findsOneWidget);

    await tester.ensureVisible(find.text('¿Ya tenés una cuenta? Iniciá sesión'));
    await tester.tap(find.text('¿Ya tenés una cuenta? Iniciá sesión'));
    await tester.pumpAndSettle();
    await esperarBD(tester);

    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Entrar'), findsOneWidget);
  });

  testWidgets('Desde iniciar sesion se puede pasar al registro', (WidgetTester tester) async {
    await tester.pumpWidget(const FinanzApp(key: ValueKey('login-registro')));
    await tester.pumpAndSettle();
    await esperarHasta(tester, find.widgetWithText(OutlinedButton, 'Crear cuenta'));

    await tester.tap(find.widgetWithText(ElevatedButton, 'Iniciar sesión'));
    await tester.pumpAndSettle();
    await esperarBD(tester);
    expect(find.text('Iniciar sesión'), findsOneWidget);

    await tester.ensureVisible(find.text('¿No tenés una cuenta? Registrate'));
    await tester.tap(find.text('¿No tenés una cuenta? Registrate'));
    await tester.pumpAndSettle();
    await esperarBD(tester);

    expect(find.text('Nueva cuenta'), findsOneWidget);
  });
}
