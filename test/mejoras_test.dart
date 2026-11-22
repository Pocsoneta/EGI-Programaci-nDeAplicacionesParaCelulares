// Tests de las mejoras del proyecto FinanzApp:
//   1. Una cuenta nueva arranca con el menu totalmente vacio.
//   2. El boton de perfil funciona: ver datos, editarlos y cerrar sesion.
//   3. Los gastos/ingresos y las entidades nuevas (metas, servicios, grupos)
//      se guardan de verdad en SQLite y se reflejan en la interfaz.
//   4. Gastos e ingresos se pueden editar y eliminar desde el inicio, y los
//      cambios quedan grabados en SQLite.
//   5. Los servicios del hogar se pueden editar sin perder su estado
//      pagado/pendiente.
//
// Se usa SQLite real (FFI, en el mismo proceso) sobre un directorio PROPIO:
// flutter test ejecuta los archivos de test en paralelo, asi que no se puede
// compartir la carpeta con widget_test.dart.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'codigo_test_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/data/dbhelper.dart';
import 'package:flutter_application_1/data/fuente_datos.dart';
import 'package:flutter_application_1/data/gasto_repository.dart';
import 'package:flutter_application_1/data/grupo_repository.dart';
import 'package:flutter_application_1/data/ingreso_repository.dart';
import 'package:flutter_application_1/data/meta_ahorro_repository.dart';
import 'package:flutter_application_1/model/model.dart';
import 'package:flutter_application_1/data/servicio_hogar_repository.dart';
import 'package:flutter_application_1/data/usuario_repository.dart';
import 'package:flutter_application_1/util/utils.dart';

// Ruta aislada para las bases de datos de estos tests.
final String _dirTest =
    '${Directory.systemTemp.path}${Platform.pathSeparator}finanzapp_test_dbs_mejoras';

// Las operaciones de SQLite hacen E/S real (abrir archivos, escribir), por lo
// que NO alcanza con pumpAndSettle: hay que dar vueltas al event loop real del
// sistema y recien despues redibujar la UI.
Future<void> esperarBD(WidgetTester tester) async {
  for (int i = 0; i < 6; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pumpAndSettle();
}

// Abre la pantalla de bienvenida y crea una cuenta nueva, quedando en el Inicio.
Future<void> crearCuenta(
  WidgetTester tester, {
  required String nombre,
  required String email,
}) async {
  await tester.pumpWidget(const FinanzApp());
  await tester.pumpAndSettle();
  await esperarBD(tester);

  await tester.tap(find.widgetWithText(OutlinedButton, 'Crear cuenta'));
  await tester.pumpAndSettle();
  await esperarBD(tester);

  await tester.enterText(find.byType(TextFormField).at(0), nombre);
  await tester.enterText(find.byType(TextFormField).at(1), email);
  await tester.enterText(find.byType(TextFormField).at(2), '123456');

  await tester.tap(find.widgetWithText(ElevatedButton, 'Crear cuenta'));
  await tester.pumpAndSettle();
  await cerrarCodigoRecuperacion(tester);
  await esperarBD(tester);
}

// Los servicios del hogar ya no estan en la barra: se abren desde Inicio
// como pantalla propia.
Future<void> abrirHogar(WidgetTester tester) async {
  await tester.tap(find.text('Inicio'));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(FloatingActionButton));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Servicios del hogar'));
  await tester.pumpAndSettle();
  await esperarBD(tester);
}

Future<void> volverDeHogar(WidgetTester tester) async {
  tester.state<NavigatorState>(find.byType(Navigator).first).pop();
  await tester.pumpAndSettle();
  await esperarBD(tester);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Estos tests verifican la PERSISTENCIA REAL: se desactiva el modo demo.
    FuenteDatos.usarMock = false;

    // SQLite corriendo en el mismo proceso: evita hilos/excepciones que
    // compliquen el control de tiempo de los tests.
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;

    // Se arranca siempre desde cero para que los resultados sean deterministas.
    final Directory dir = Directory(_dirTest);
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
    dir.createSync(recursive: true);
    await databaseFactory.setDatabasesPath(dir.path);
    await DbHelper().marcarIntroduccionVista();
  });

  // La sesion guardada en disco hace que la app arranque directo en el
  // inicio: cada test tiene que partir de la pantalla de bienvenida.
  setUp(() async {
    await DbHelper().cerrarSesion();
  });

  testWidgets(
    'Cuenta nueva: el menu arranca vacio en todas las pantallas',
    (WidgetTester tester) async {
      await crearCuenta(tester, nombre: 'Carla Ruiz', email: 'carla@test.com');

      // ---------------------------------------------------------------
      // INICIO: sin gastos, sin ingresos y todas las tarjetas en $0.
      // ---------------------------------------------------------------
      expect(find.text('Sin gastos registrados este mes'), findsOneWidget);
      expect(find.text('Sin gastos para mostrar'), findsOneWidget);
      expect(find.text('Aun no hay gastos registrados.'), findsOneWidget);
      expect(find.text('\$0'), findsWidgets);

      // ---------------------------------------------------------------
      // MES: sin movimientos en el periodo.
      // ---------------------------------------------------------------
      await tester.tap(find.text('Mes'));
      await tester.pumpAndSettle();
      await esperarBD(tester);
      expect(find.text('Sin gastos en este período.'), findsOneWidget);
      expect(find.text('Ingresos: \$0'), findsOneWidget);
      expect(find.text('Balance: \$0'), findsOneWidget);

      // ---------------------------------------------------------------
      // HOGAR: sin servicios cargados.
      // ---------------------------------------------------------------
      await abrirHogar(tester);
      await tester.pumpAndSettle();
      await esperarBD(tester);
      expect(
        find.text('Aún no hay servicios cargados. Agregá uno con el botón de arriba.'),
        findsOneWidget,
      );
      expect(find.text('Total Servicios y Hogar'), findsOneWidget);
      expect(find.text('\$0'), findsWidgets);

      // ---------------------------------------------------------------
      // GRUPO: sin grupos creados.
      // ---------------------------------------------------------------
      await volverDeHogar(tester);
      await tester.tap(find.text('Grupo'));
      await tester.pumpAndSettle();
      await esperarBD(tester);
      expect(
        find.text('Aún no tenés grupos. Creá uno con el botón de arriba.'),
        findsOneWidget,
      );

      // ---------------------------------------------------------------
      // AHORRO: sin metas creadas.
      // ---------------------------------------------------------------
      await tester.tap(find.text('Ahorro'));
      await tester.pumpAndSettle();
      await esperarBD(tester);
      expect(
        find.text('Aún no tenés metas de ahorro. Creá una para empezar.'),
        findsOneWidget,
      );
      expect(find.text('Total acumulado en metas'), findsOneWidget);
      expect(find.text('\$0'), findsOneWidget);
    },
  );

  testWidgets(
    'Perfil: muestra los datos, permite editarlos y cerrar sesion',
    (WidgetTester tester) async {
      await crearCuenta(tester, nombre: 'Diego Sosa', email: 'diego@test.com');

      // ---------------------------------------------------------------
      // 1. EL BOTON DE PERFIL ABRE LA PANTALLA CON LOS DATOS DE LA CUENTA
      // ---------------------------------------------------------------
      await tester.tap(find.byTooltip('Mi perfil'));
      await tester.pumpAndSettle();
      await esperarBD(tester);

      expect(find.text('Mi Perfil'), findsOneWidget);
      expect(find.text('Datos de la cuenta'), findsOneWidget);
      // El nombre y el correo aparecen en la cabecera y en los datos.
      expect(find.text('Diego Sosa'), findsWidgets);
      expect(find.text('diego@test.com'), findsWidgets);
      expect(find.text('Editar datos'), findsOneWidget);
      expect(find.text('Cerrar sesión'), findsOneWidget);

      // ---------------------------------------------------------------
      // 2. SE EDITA EL NOMBRE Y SE PERSISTE EN SQLITE
      // ---------------------------------------------------------------
      await tester.tap(find.widgetWithText(OutlinedButton, 'Editar datos'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'Diego Modificado');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar cambios'));
      await tester.pumpAndSettle();
      await esperarBD(tester);

      // Se deja pasar el snackbar de confirmacion: si no, tapa los botones
      // que quedan al pie de la pantalla.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      // La cabecera refleja el cambio inmediatamente (cabecera + dato).
      expect(find.text('Diego Modificado'), findsWidgets);

      // Ademas el cambio quedo grabado en la base de datos global.
      final int? id = DbHelper().currentUserId;
      expect(id, isNotNull);
      final Usuario? guardado =
          await tester.runAsync<Usuario?>(
              () => UsuarioRepository().getUsuario(id!));
      expect(guardado, isNotNull);
      expect(guardado!.nombre, 'Diego Modificado');

      // ---------------------------------------------------------------
      // 3. CERRAR SESION VUELVE A LA BIENVENIDA
      // ---------------------------------------------------------------
      // El boton queda al fondo de la pantalla: hay que asegurar que este visible.
      await tester.ensureVisible(find.widgetWithText(OutlinedButton, 'Cerrar sesión'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Cerrar sesión'));
      await tester.pumpAndSettle();
      await esperarBD(tester);

      expect(find.text('FinanzApp'), findsOneWidget);
      expect(find.text('Iniciar sesión'), findsOneWidget);
      expect(find.text('Crear cuenta'), findsOneWidget);
      expect(find.text('Mi Perfil'), findsNothing);
    },
  );

  testWidgets(
    'Ingresos y metas de ahorro se guardan en SQLite',
    (WidgetTester tester) async {
      await crearCuenta(tester, nombre: 'Elena Paz', email: 'elena@test.com');

      // ---------------------------------------------------------------
      // 1. ALTA DE UN INGRESO DESDE EL INICIO
      // ---------------------------------------------------------------
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nuevo ingreso'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'Sueldo');
      await tester.enterText(find.byType(TextFormField).at(1), '50000');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar'));
      await tester.pumpAndSettle();
      await esperarBD(tester);

      // La tarjeta de Ingresos del inicio se actualiza con el valor real
      // (el mismo numero puede repetirse en la tarjeta de saldo total).
      expect(find.text('\$50.000'), findsWidgets);

      final List<Ingreso> ingresos = await tester
              .runAsync<List<Ingreso>>(() => IngresoRepository().getIngresos()) ??
          <Ingreso>[];
      expect(ingresos, hasLength(1));
      expect(ingresos.first.concepto, 'Sueldo');
      expect(ingresos.first.monto, 50000);

      // ---------------------------------------------------------------
      // 2. ALTA DE UNA META DE AHORRO
      // ---------------------------------------------------------------
      await tester.tap(find.text('Ahorro'));
      await tester.pumpAndSettle();
      await esperarBD(tester);

      await tester.tap(find.widgetWithText(TextButton, 'Nueva meta'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'Vacaciones');
      await tester.enterText(find.byType(TextFormField).at(1), '20000');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Crear meta'));
      await tester.pumpAndSettle();
      await esperarBD(tester);

      expect(find.text('Vacaciones'), findsOneWidget);

      final List<MetaAhorro> metas = await tester
              .runAsync<List<MetaAhorro>>(() => MetaAhorroRepository().getMetas()) ??
          <MetaAhorro>[];
      expect(metas, hasLength(1));
      expect(metas.first.titulo, 'Vacaciones');
      expect(metas.first.montoObjetivo, 20000);
      expect(metas.first.montoAhorrado, 0);

      // ---------------------------------------------------------------
      // 3. DEPOSITAR AHORRO ACTUALIZA LA META EN LA BASE
      // ---------------------------------------------------------------
      await tester.ensureVisible(find.byTooltip('Acciones de la meta'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Acciones de la meta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Depositar'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), '5000');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Depositar'));
      await tester.pumpAndSettle();
      await esperarBD(tester);

      expect(find.text('Ahorrado: \$5.000'), findsOneWidget);
      expect(find.text('25%'), findsWidgets);

      final List<MetaAhorro> metasActualizadas = await tester
              .runAsync<List<MetaAhorro>>(() => MetaAhorroRepository().getMetas()) ??
          <MetaAhorro>[];
      expect(metasActualizadas.first.montoAhorrado, 5000);

      // ---------------------------------------------------------------
      // 4. EL SALDO DEL INICIO REFLEJA EL DEPOSITO (todo conectado)
      // ---------------------------------------------------------------
      // Ingresos 50000 - gastos 0 - depositado 5000 = 45000 disponibles.
      await tester.tap(find.text('Inicio'));
      await tester.pumpAndSettle();
      await esperarBD(tester);

      expect(find.text('\$45.000'), findsOneWidget);
      expect(
        find.text('Plata que tenés disponible para gastar'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Servicios del hogar se guardan en SQLite',
    (WidgetTester tester) async {
      await crearCuenta(tester, nombre: 'Federico Luna', email: 'fede@test.com');

      // ---------------------------------------------------------------
      // 1. ALTA DE UN SERVICIO DEL HOGAR
      // ---------------------------------------------------------------
      await abrirHogar(tester);
      await tester.pumpAndSettle();
      await esperarBD(tester);

      await tester.tap(find.byTooltip('Nuevo servicio'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'Luz');
      await tester.enterText(find.byType(TextFormField).at(1), 'Vence el 22');
      await tester.enterText(find.byType(TextFormField).at(2), '8500');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar'));
      await tester.pumpAndSettle();
      await esperarBD(tester);

      expect(find.text('Luz'), findsOneWidget);
      expect(find.text('\$8.500'), findsWidgets);

      List<ServicioHogar> servicios = await tester
              .runAsync<List<ServicioHogar>>(
                  () => ServicioHogarRepository().getServicios()) ??
          <ServicioHogar>[];
      expect(servicios, hasLength(1));
      expect(servicios.first.monto, 8500);
      expect(servicios.first.pagado, 0);

      // ---------------------------------------------------------------
      // 2. MARCAR COMO PAGADO SE REFLEJA EN SQLITE
      // ---------------------------------------------------------------
      await tester.tap(find.byTooltip('Marcar como pagado'));
      await tester.pumpAndSettle();
      await esperarBD(tester);

      expect(find.byIcon(Icons.check_circle), findsOneWidget);

      servicios = await tester
              .runAsync<List<ServicioHogar>>(
                  () => ServicioHogarRepository().getServicios()) ??
          <ServicioHogar>[];
      expect(servicios.first.pagado, 1);

      // ---------------------------------------------------------------
      // 3. EL RESUMEN SUMA LOS SERVICIOS REALES
      // ---------------------------------------------------------------
      await tester.tap(find.byTooltip('Nuevo servicio'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'Internet');
      await tester.enterText(find.byType(TextFormField).at(2), '6000');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar'));
      await tester.pumpAndSettle();
      await esperarBD(tester);

      expect(find.text('\$14.500'), findsOneWidget); // total del resumen
      // Pagado y pendiente aparecen tanto en el resumen como en cada item.
      expect(find.text('\$8.500'), findsWidgets);
      expect(find.text('\$6.000'), findsWidgets);

    },
  );

  testWidgets(
    'Gastos: se pueden editar y eliminar y los cambios persisten en SQLite',
    (WidgetTester tester) async {
      await crearCuenta(tester, nombre: 'Gabriela Ruiz', email: 'gabriela@test.com');

      // ---------------------------------------------------------------
      // 1. ALTA DE UN GASTO (la fecha de vencimiento se elige en el form)
      // ---------------------------------------------------------------
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nuevo gasto'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'Alquiler');
      await tester.enterText(find.byType(TextFormField).at(1), '1500');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar gasto'));
      await tester.pumpAndSettle();
      await esperarBD(tester);

      final List<Gasto> trasAlta = await tester
              .runAsync<List<Gasto>>(() => GastoRepository().getGastos()) ??
          <Gasto>[];
      expect(trasAlta, hasLength(1));
      expect(trasAlta.first.concepto, 'Alquiler');
      expect(trasAlta.first.monto, 1500);

      // El item queda por debajo de la tarjeta principal: hay que bajar.
      await tester.scrollUntilVisible(
        find.text('Alquiler'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      // ---------------------------------------------------------------
      // 2. EDICION: se cambia el monto desde el menu del item
      // ---------------------------------------------------------------
      await tester.ensureVisible(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();

      // El formulario viene precargado con los datos actuales del gasto.
      expect(find.text('Editar gasto'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Alquiler'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(1), '2000');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar cambios'));
      await tester.pumpAndSettle();
      await esperarBD(tester);

      // Se deja pasar el snackbar de confirmacion para no tapar la lista.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      final List<Gasto> trasEdicion = await tester
              .runAsync<List<Gasto>>(() => GastoRepository().getGastos()) ??
          <Gasto>[];
      expect(trasEdicion, hasLength(1));
      expect(trasEdicion.first.monto, 2000, reason: 'La edicion no persistio');

      // ---------------------------------------------------------------
      // 3. BAJA: se elimina desde el menu del item, con confirmacion
      // ---------------------------------------------------------------
      await tester.scrollUntilVisible(
        find.text('Alquiler'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();

      expect(find.text('Eliminar gasto'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Eliminar'));
      await tester.pumpAndSettle();
      await esperarBD(tester);

      final List<Gasto> trasBaja = await tester
              .runAsync<List<Gasto>>(() => GastoRepository().getGastos()) ??
          <Gasto>[];
      expect(trasBaja, isEmpty, reason: 'La baja no persistio');
      expect(find.text('Aun no hay gastos registrados.'), findsOneWidget);
    },
  );

  testWidgets(
    'Ingresos: se pueden editar y eliminar y los cambios persisten en SQLite',
    (WidgetTester tester) async {
      await crearCuenta(tester, nombre: 'Hector Lima', email: 'hector@test.com');

      // ---------------------------------------------------------------
      // 1. ALTA DE UN INGRESO
      // ---------------------------------------------------------------
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nuevo ingreso'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'Sueldo');
      await tester.enterText(find.byType(TextFormField).at(1), '50000');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar'));
      await tester.pumpAndSettle();
      await esperarBD(tester);

      // Aparece la seccion de ingresos con el item recien cargado.
      expect(find.text('Ingresos del mes'), findsOneWidget);
      expect(find.text('+\$50.000'), findsOneWidget);

      // ---------------------------------------------------------------
      // 2. EDICION: se cambia el monto desde el menu del item
      // ---------------------------------------------------------------
      // Sin gastos cargados, el unico menu de la pantalla es el del ingreso.
      expect(find.byType(PopupMenuButton<String>), findsOneWidget);
      // El menu queda fuera del viewport: hay que acercarlo antes de tocarlo.
      await tester.ensureVisible(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();

      expect(find.text('Editar ingreso'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(1), '75000');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar cambios'));
      await tester.pumpAndSettle();
      await esperarBD(tester);

      final List<Ingreso> trasEdicion = await tester
              .runAsync<List<Ingreso>>(() => IngresoRepository().getIngresos()) ??
          <Ingreso>[];
      expect(trasEdicion, hasLength(1));
      expect(trasEdicion.first.monto, 75000, reason: 'La edicion no persistio');
      expect(find.text('+\$75.000'), findsOneWidget);

      // ---------------------------------------------------------------
      // 3. BAJA: se elimina y la seccion desaparece al quedar vacia
      // ---------------------------------------------------------------
      await tester.ensureVisible(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();

      expect(find.text('Eliminar ingreso'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Eliminar'));
      await tester.pumpAndSettle();
      await esperarBD(tester);

      final List<Ingreso> trasBaja = await tester
              .runAsync<List<Ingreso>>(() => IngresoRepository().getIngresos()) ??
          <Ingreso>[];
      expect(trasBaja, isEmpty, reason: 'La baja no persistio');
      expect(find.text('Ingresos del mes'), findsNothing);
      expect(find.text('\$0'), findsWidgets);
    },
  );

  testWidgets(
    'Servicios del hogar: se pueden editar y los cambios persisten en SQLite',
    (WidgetTester tester) async {
      await crearCuenta(tester, nombre: 'Irene Vega', email: 'irene@test.com');

      // ---------------------------------------------------------------
      // 1. ALTA DE UN SERVICIO Y MARCA COMO PAGADO
      // ---------------------------------------------------------------
      await abrirHogar(tester);
      await tester.pumpAndSettle();
      await esperarBD(tester);

      await tester.tap(find.byTooltip('Nuevo servicio'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'Luz');
      await tester.enterText(find.byType(TextFormField).at(1), 'Vence el 22');
      await tester.enterText(find.byType(TextFormField).at(2), '8500');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar'));
      await tester.pumpAndSettle();
      await esperarBD(tester);

      await tester.tap(find.byTooltip('Marcar como pagado'));
      await tester.pumpAndSettle();
      await esperarBD(tester);

      // ---------------------------------------------------------------
      // 2. EDICION: se cambia titulo y monto desde el menu del item
      // ---------------------------------------------------------------
      await tester.tap(find.byTooltip('Acciones del servicio'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();

      expect(find.text('Editar servicio'), findsOneWidget);
      // El formulario viene precargado con los datos actuales.
      expect(find.widgetWithText(TextFormField, 'Luz'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(0), 'Luz (Edemsa)');
      await tester.enterText(find.byType(TextFormField).at(2), '9500');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar cambios'));
      await tester.pumpAndSettle();
      await esperarBD(tester);

      expect(find.text('Luz (Edemsa)'), findsOneWidget);
      // El resumen refleja el monto nuevo.
      expect(find.text('Total Servicios y Hogar'), findsOneWidget);
      expect(find.text('\$9.500'), findsWidgets);

      final List<ServicioHogar> trasEdicion = await tester
              .runAsync<List<ServicioHogar>>(
                  () => ServicioHogarRepository().getServicios()) ??
          <ServicioHogar>[];
      expect(trasEdicion, hasLength(1));
      expect(trasEdicion.first.titulo, 'Luz (Edemsa)');
      expect(trasEdicion.first.monto, 9500);
      // La edicion no toca el estado: sigue pagado.
      expect(trasEdicion.first.pagado, 1,
          reason: 'La edicion perdio el estado pagado');

      // El item sigue mostrando que esta pagado.
      expect(find.byIcon(Icons.check_circle), findsOneWidget);

      await volverDeHogar(tester);
    },
  );

  testWidgets(
    'Metas de ahorro: editar objetivo y retirar ahorro persisten en SQLite',
    (WidgetTester tester) async {
      await crearCuenta(tester, nombre: 'Julian Castro', email: 'julian@test.com');

      // ---------------------------------------------------------------
      // 1. ALTA DE UNA META Y DEPOSITO
      // ---------------------------------------------------------------
      await tester.tap(find.text('Ahorro'));
      await tester.pumpAndSettle();
      await esperarBD(tester);

      await tester.tap(find.widgetWithText(TextButton, 'Nueva meta'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'Vacaciones');
      await tester.enterText(find.byType(TextFormField).at(1), '20000');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Crear meta'));
      await tester.pumpAndSettle();
      await esperarBD(tester);

      await tester.ensureVisible(find.byTooltip('Acciones de la meta'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Acciones de la meta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Depositar'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), '5000');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Depositar'));
      await tester.pumpAndSettle();
      await esperarBD(tester);

      expect(find.text('Ahorrado: \$5.000'), findsOneWidget);

      // ---------------------------------------------------------------
      // 2. EDICION: se cambia el monto objetivo y lo ahorrado se conserva
      // ---------------------------------------------------------------
      await tester.tap(find.byTooltip('Acciones de la meta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();

      expect(find.text('Editar meta'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Vacaciones'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(1), '40000');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar cambios'));
      await tester.pumpAndSettle();
      await esperarBD(tester);

      expect(find.text('Objetivo: \$40.000'), findsOneWidget);

      List<MetaAhorro> metas = await tester
              .runAsync<List<MetaAhorro>>(() => MetaAhorroRepository().getMetas()) ??
          <MetaAhorro>[];
      expect(metas, hasLength(1));
      expect(metas.first.montoObjetivo, 40000);
      expect(metas.first.montoAhorrado, 5000,
          reason: 'La edicion perdio lo ya ahorrado');

      // ---------------------------------------------------------------
      // 3. RETIRO: valida que no se supere lo ahorrado
      // ---------------------------------------------------------------
      await tester.tap(find.byTooltip('Acciones de la meta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Retirar'));
      await tester.pumpAndSettle();

      // Retirar mas de lo ahorrado no pasa la validacion.
      await tester.enterText(find.byType(TextFormField).at(0), '999999');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Retirar'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('No podés retirar más de'),
        findsOneWidget,
      );
      expect(find.text('Retirar de "Vacaciones"'), findsOneWidget,
          reason: 'El dialogo tenia que quedarse abierto');

      // Retiro valido.
      await tester.enterText(find.byType(TextFormField).at(0), '2000');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Retirar'));
      await tester.pumpAndSettle();
      await esperarBD(tester);

      expect(find.text('Ahorrado: \$3.000'), findsOneWidget);

      metas = await tester
              .runAsync<List<MetaAhorro>>(() => MetaAhorroRepository().getMetas()) ??
          <MetaAhorro>[];
      expect(metas.first.montoAhorrado, 3000,
          reason: 'El retiro no persistio en SQLite');
    },
  );

  test(
    'Una base creada por una version anterior recibe las tablas nuevas',
    () async {
      // Se recrea una base tal como la dejaba la version anterior de la app:
      // SOLO la tabla gastos (sin ingresos, metas, grupos ni servicios).
      final String ruta = '$_dirTest/finanzapp_77.db';
      final Database vieja = await databaseFactory.openDatabase(ruta);
      await vieja.execute('CREATE TABLE gastos ('
          'id INTEGER PRIMARY KEY AUTOINCREMENT, '
          'concepto TEXT, monto REAL, categoria TEXT, '
          'expiration TEXT, fqYear INTEGER, fqHalfYear INTEGER, '
          'fqMonth INTEGER);');
      await vieja.execute(
        "INSERT INTO gastos (concepto, monto) VALUES ('Viejo', 100);",
      );
      await vieja.close();

      // Al abrir esa misma base con la app actual, las tablas nuevas tienen
      // que existir (antes solo se creaban al crear el archivo, y una cuenta
      // existente ya tiene su archivo).
      await DbHelper().setCurrentUser(77);

      final List<Gasto> gastos = await GastoRepository().getGastos();
      expect(gastos, hasLength(1), reason: 'Se perdieron los gastos viejos');
      expect(gastos.first.concepto, 'Viejo');

      // Las tablas nuevas responden sin lanzar "no such table".
      expect(await IngresoRepository().getIngresos(), isEmpty);
      expect(await MetaAhorroRepository().getMetas(), isEmpty);
      expect(await GrupoRepository().getGrupos(), isEmpty);
      expect(await ServicioHogarRepository().getServicios(), isEmpty);

      // Ademas se puede escribir en ellas.
      await IngresoRepository()
          .addIngreso(Ingreso('Sueldo', 1000, '2026-11-01'));
      expect(await IngresoRepository().getIngresos(), hasLength(1));

      // Y la base de usuarios global sigue intacta.
      final List<Usuario> usuarios = await UsuarioRepository().getUsuarios();
      expect(usuarios, isNotEmpty);
    },
  );


  // ---------------------------------------------------------------------
  // INTEGRACION: todo queda conectado al saldo del inicio.
  // ---------------------------------------------------------------------

  group('Saldo total del inicio (logica pura)', () {
    test('Es ingresos - gastos - lo depositado en ahorros', () {
      final List<Gasto> gastos = <Gasto>[
        Gasto('Alquiler', 1500, 'Servicios', '2026-11-01', 0, 0, 0),
      ];
      final List<Ingreso> ingresos = <Ingreso>[
        Ingreso('Sueldo', 50000, '2026-11-01'),
      ];
      final List<MetaAhorro> metas = <MetaAhorro>[
        MetaAhorro('Vacaciones', 'Viajes', 20000, 5000, '2026-12-31'),
      ];

      // 50000 - 1500 - 5000
      expect(saldoTotal(gastos, ingresos, metas), 43500);
    });

    test('Una devolucion de grupo (gasto negativo) suma plata', () {
      final List<Gasto> gastos = <Gasto>[
        Gasto('Devolución grupo Asado', -500, 'General', '2026-11-04', 0, 0, 0),
      ];

      expect(saldoTotal(gastos, <Ingreso>[], <MetaAhorro>[]), 500);
    });

    test('Retirar ahorro devuelve plata al saldo', () {
      // Se depositaron 5000 y se retiraron 2000: quedan 3000 ahorrados,
      // que siguen restando del saldo disponible.
      final List<MetaAhorro> metas = <MetaAhorro>[
        MetaAhorro('Vacaciones', 'Viajes', 20000, 3000, '2026-12-31'),
      ];

      expect(saldoTotal(<Gasto>[], <Ingreso>[], metas), -3000);
    });
  });

  testWidgets(
    'Servicio pagado: se registra como gasto y se deshace al desmarcar',
    (WidgetTester tester) async {
      await crearCuenta(tester, nombre: 'Laura Mesa', email: 'laura@test.com');

      // ---------------------------------------------------------------
      // 1. ALTA DE UN SERVICIO Y MARCA COMO PAGADO
      // ---------------------------------------------------------------
      await abrirHogar(tester);
      await tester.pumpAndSettle();
      await esperarBD(tester);

      await tester.tap(find.byTooltip('Nuevo servicio'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'Luz');
      await tester.enterText(find.byType(TextFormField).at(2), '8500');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar'));
      await tester.pumpAndSettle();
      await esperarBD(tester);

      await tester.tap(find.byTooltip('Marcar como pagado'));
      await tester.pumpAndSettle();
      await esperarBD(tester);

      // El pago quedo registrado como gasto del dia de hoy.
      List<Gasto> gastos = await tester
              .runAsync<List<Gasto>>(() => GastoRepository().getGastos()) ??
          <Gasto>[];
      expect(gastos, hasLength(1), reason: 'El pago no genero gasto');
      expect(gastos.first.concepto, 'Luz');
      expect(gastos.first.monto, 8500);
      expect(gastos.first.categoria, 'Servicios');

      // ---------------------------------------------------------------
      // 2. EL PAGO SE REFLEJA EN EL INICIO (saldo y lista de gastos)
      // ---------------------------------------------------------------
      await volverDeHogar(tester);
      await tester.tap(find.text('Inicio'));
      await tester.pumpAndSettle();
      await esperarBD(tester);

      expect(find.text('-\$8.500'), findsOneWidget, reason: 'Saldo sin descontar');

      await tester.scrollUntilVisible(
        find.text('Luz'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Luz'), findsOneWidget);

      // ---------------------------------------------------------------
      // 3. DESMARCAR COMO PAGADO ELIMINA EL GASTO
      // ---------------------------------------------------------------
      await abrirHogar(tester);
      await tester.pumpAndSettle();
      await esperarBD(tester);

      await tester.tap(find.byTooltip('Marcar como pendiente'));
      await tester.pumpAndSettle();
      await esperarBD(tester);

      gastos = await tester
              .runAsync<List<Gasto>>(() => GastoRepository().getGastos()) ??
          <Gasto>[];
      expect(gastos, isEmpty, reason: 'Desmarcar dejo un gasto huerfano');

      await volverDeHogar(tester);
      await tester.tap(find.text('Inicio'));
      await tester.pumpAndSettle();
      await esperarBD(tester);
      expect(find.text('\$0'), findsWidgets);
    },
  );


  // ---------------------------------------------------------------------
  // INTEGRACION: deudas individuales (logica pura).
  // ---------------------------------------------------------------------

}
