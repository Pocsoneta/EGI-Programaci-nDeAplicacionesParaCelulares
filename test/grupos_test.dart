// Tests de los grupos de gastos compartidos (estilo Tricount): calculos puros,
// persistencia, sincronia con el Saldo total, migracion de bases viejas y un
// flujo completo por pantalla.
//
// Usa un directorio PROPIO porque flutter test ejecuta los archivos en
// paralelo y comparten la carpeta de bases de datos.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:flutter_application_1/data/dbhelper.dart';
import 'package:flutter_application_1/data/fuente_datos.dart';
import 'package:flutter_application_1/data/gasto_repository.dart';
import 'package:flutter_application_1/data/grupo_repository.dart';
import 'package:flutter_application_1/data/usuario_repository.dart';
import 'package:flutter_application_1/model/model.dart';
import 'package:flutter_application_1/ui/anadir_gasto_grupo_screen.dart';
import 'package:flutter_application_1/ui/grupo_detalle_screen.dart';
import 'package:flutter_application_1/ui/groups_screen.dart';
import 'package:flutter_application_1/ui/main_nav_screen.dart';
import 'package:flutter_application_1/util/grupo_calculos.dart';
import 'package:flutter_application_1/util/utils.dart';

final String _dirTest =
    '${Directory.systemTemp.path}${Platform.pathSeparator}finanzapp_test_dbs_grupos';

Future<void> esperarBD(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
  await tester.pump();
}

// Crea un grupo con el usuario actual y devuelve sus datos ya cargados.
Future<DatosGrupo> _crearGrupoConParticipantes(
    String nombre, List<String> otros) async {
  final int yoId = DbHelper().currentUserId!;
  final List<Participante> participantes = <Participante>[
    Participante(0, 'Ana', true),
    ...otros.map((String n) => Participante(0, n, false)),
  ];
  final int grupoId = await GrupoRepository().crearGrupo(
    Grupo(nombre, '🧾'),
    participantes,
  );
  expect(yoId, isNotNull);
  final Grupo grupo = (await GrupoRepository().getGrupos())
      .firstWhere((Grupo g) => g.id == grupoId);
  return GrupoRepository().cargarGrupo(grupo);
}

// Guarda un gasto compartido dividido en partes iguales entre los participantes.
Future<GastoGrupo> _gastoIgual(
    DatosGrupo datos, String titulo, double monto, int pagadoPor) async {
  final List<int> ids = datos.participantes.map((Participante p) => p.id!).toList();
  final List<double> partes = dividirIgual(monto, ids.length);
  final GastoGrupo gasto = GastoGrupo(datos.grupo.id!, titulo, monto, pagadoPor, '2026-11-17');
  await GrupoRepository().guardarGasto(
    gasto: gasto,
    partes: [
      for (int i = 0; i < ids.length; i++)
        ParteGasto(0, datos.grupo.id!, ids[i], partes[i]),
    ],
    aportes: [AporteGasto(0, datos.grupo.id!, pagadoPor, monto)],
    yoId: datos.yoId,
    nombreGrupo: datos.grupo.nombre,
  );
  return gasto;
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
  });

  setUp(() async {
    await DbHelper().cerrarSesion();
  });

  group('Calculos (logica pura)', () {
    test('dividirIgual reparte con centavos exactos', () {
      final List<double> partes = dividirIgual(100000, 3);

      expect(partes, hasLength(3));
      expect(partes.fold(0.0, (double a, double b) => a + b), closeTo(100000, 0.001));
      expect(partes.first, 33333.34);
      expect(partes.last, 33333.33);
    });

    test('Los saldos salen de lo pagado menos lo que toca', () {
      final Participante yo = Participante(1, 'Ana', true, 1);
      final Participante joaquin = Participante(1, 'Joaquin', false, 2);
      final Participante juan = Participante(1, 'Juan', false, 3);
      final List<double> partes = dividirIgual(100000, 3);
      final GastoGrupo carne = GastoGrupo.withId(1, 1, 'Carne', 100000, 1, '2026-11-17', 0);
      final List<ParteGasto> listaPartes = <ParteGasto>[
        ParteGasto.withId(1, 1, 1, 1, partes[0]),
        ParteGasto.withId(2, 1, 1, 2, partes[1]),
        ParteGasto.withId(3, 1, 1, 3, partes[2]),
      ];

      final Map<int, int> netos = saldosNetosEnCentavos(
        participantes: <Participante>[yo, joaquin, juan],
        gastos: <GastoGrupo>[carne],
        partes: listaPartes,
        pagos: <PagoGrupo>[],
      );

      expect(netos[1], 6666666, reason: 'Ana pagó 100.000 y le tocan 33.333,34');
      expect(netos[2], -3333333);
      expect(netos[3], -3333333);
    });

    test('Los reembolsos dejan a todos en cero y un pago reduce la deuda', () {
      final Participante yo = Participante(1, 'Ana', true, 1);
      final Participante joaquin = Participante(1, 'Joaquin', false, 2);
      final Participante juan = Participante(1, 'Juan', false, 3);
      final List<Reembolso> sinPagos = calcularReembolsos(<int, int>{1: 6666666, 2: -3333333, 3: -3333333});

      expect(sinPagos, hasLength(2));
      expect(sinPagos.every((Reembolso r) => r.acreedorId == 1), isTrue);
      expect(sinPagos.fold(0.0, (double a, Reembolso r) => a + r.monto), closeTo(66666.66, 0.001));

      final Map<int, int> conPago = saldosNetosEnCentavos(
        participantes: <Participante>[yo, joaquin, juan],
        gastos: <GastoGrupo>[GastoGrupo.withId(1, 1, 'Carne', 100000, 1, '2026-11-17', 0)],
        partes: <ParteGasto>[
          ParteGasto.withId(1, 1, 1, 1, 33333.34),
          ParteGasto.withId(2, 1, 1, 2, 33333.33),
          ParteGasto.withId(3, 1, 1, 3, 33333.33),
        ],
        pagos: <PagoGrupo>[PagoGrupo.withId(1, 1, 2, 1, 33333.33, '2026-11-18')],
      );
      final List<Reembolso> tras = calcularReembolsos(conPago);

      expect(conPago[2], 0);
      expect(tras, hasLength(1));
      expect(tras.first.deudorId, 3);
      expect(tras.first.acreedorId, 1);
    });

    test('Formato con centavos y separador de miles', () {
      expect(formatearMonedaExacta(33333.33), '\$33.333,33');
      expect(formatearMonedaExacta(-50000), '-\$50.000,00');
      expect(formatearMonedaExacta(0), '\$0,00');
    });
  });

  group('Persistencia y Saldo total', () {
    test('Tu parte de un gasto compartido queda como gasto personal', () async {
      await UsuarioRepository().crearUsuario(nombre: 'Ana', email: 'ana@grupos.com', password: 'x12345');
      final DatosGrupo datos = await _crearGrupoConParticipantes('Asado', <String>['Joaquin', 'Juan']);
      final GastoGrupo carne = await _gastoIgual(datos, 'Carne', 100000, datos.yoId!);

      expect(carne.movimientoId, greaterThan(0));
      final List<Gasto> gastos = await GastoRepository().getGastos();
      final Gasto miParte = gastos.firstWhere((Gasto g) => g.concepto == 'Asado: Carne');
      expect(miParte.monto, 33333.34);

      final DatosGrupo tras = await GrupoRepository().cargarGrupo(datos.grupo);
      expect(tras.miSaldo, closeTo(66666.66, 0.001));
    });

    test('Editar y eliminar un gasto actualiza tu parte en el Saldo total', () async {
      await UsuarioRepository().crearUsuario(nombre: 'Bruno', email: 'bruno@grupos.com', password: 'x12345');
      final DatosGrupo datos = await _crearGrupoConParticipantes('Viaje', <String>['Lucia']);
      final GastoGrupo gasto = await _gastoIgual(datos, 'Hotel', 20000, datos.yoId!);

      // Se edita para que sea solo tuyo: la parte personal pasa a 20.000.
      final List<ParteGasto> nuevas = <ParteGasto>[
        ParteGasto(0, datos.grupo.id!, datos.yoId!, 20000),
      ];
      gasto
        ..titulo = 'Hotel centro'
        ..monto = 20000;
      await GrupoRepository().guardarGasto(
        gasto: gasto,
        partes: nuevas,
        aportes: [AporteGasto(0, datos.grupo.id!, datos.yoId!, 20000)],
        yoId: datos.yoId,
        nombreGrupo: 'Viaje',
      );
      final List<Gasto> editados = (await GastoRepository().getGastos())
          .where((Gasto g) => g.concepto.startsWith('Viaje:'))
          .toList();
      expect(editados, hasLength(1), reason: 'El movimiento anterior no se reemplazo');
      expect(editados.first.concepto, 'Viaje: Hotel centro');
      expect(editados.first.monto, 20000);

      await GrupoRepository().eliminarGasto(gasto);
      expect(
        (await GastoRepository().getGastos()).where((Gasto g) => g.concepto.startsWith('Viaje:')),
        isEmpty,
        reason: 'Al borrar el gasto tenia que quitarse tu parte',
      );
    });

    test('Los reembolsos no duplican el Saldo total', () async {
      await UsuarioRepository().crearUsuario(nombre: 'Carla', email: 'carla@grupos.com', password: 'x12345');
      final DatosGrupo datos = await _crearGrupoConParticipantes('Cena', <String>['Pedro']);
      final int pedroId =
          datos.participantes.firstWhere((Participante p) => !p.esYo).id!;
      // Pedro pagó 3000: a vos te toca 1500 y le debés 1500.
      await _gastoIgual(datos, 'Pizza', 3000, pedroId);
      final int cantidadAntes = (await GastoRepository().getGastos())
          .where((Gasto g) => g.concepto.startsWith('Cena:'))
          .length;

      final DatosGrupo conDeuda = await GrupoRepository().cargarGrupo(datos.grupo);
      expect(conDeuda.miSaldo, -1500);
      await GrupoRepository().registrarPago(PagoGrupo(
        datos.grupo.id!,
        conDeuda.yoId!,
        pedroId,
        1500,
        fechaHoy(),
      ));

      final DatosGrupo saldado = await GrupoRepository().cargarGrupo(datos.grupo);
      expect(saldado.miSaldo, 0);
      expect(
        (await GastoRepository().getGastos()).where((Gasto g) => g.concepto.startsWith('Cena:')),
        hasLength(cantidadAntes),
        reason: 'Un reembolso no tiene que crear movimientos personales',
      );
    });

    test('Eliminar un grupo borra tambien sus movimientos personales', () async {
      await UsuarioRepository().crearUsuario(nombre: 'Diego', email: 'diego@grupos.com', password: 'x12345');
      final DatosGrupo datos = await _crearGrupoConParticipantes('Futbol', <String>['Mario']);
      await _gastoIgual(datos, 'Cancha', 8000, datos.yoId!);

      await GrupoRepository().deleteGrupo(datos.grupo.id!);

      expect(await GrupoRepository().getGrupos(), isEmpty);
      expect(
        (await GastoRepository().getGastos()).where((Gasto g) => g.concepto.startsWith('Futbol:')),
        isEmpty,
      );
    });
  });

  test('Una base de la version anterior pierde sus grupos viejos una sola vez', () async {
    final String ruta = '$_dirTest/finanzapp_90.db';
    final Database vieja = await databaseFactory.openDatabase(
      ruta,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (Database db, int version) async {
          await db.execute('CREATE TABLE grupos ('
              'id INTEGER PRIMARY KEY AUTOINCREMENT, '
              'nombre TEXT, integrantes INTEGER, saldo INTEGER, icono TEXT);');
          await db.execute('CREATE TABLE grupo_miembros ('
              'id INTEGER PRIMARY KEY AUTOINCREMENT, '
              'grupoId INTEGER, nombre TEXT, deuda REAL);');
          await db.execute("INSERT INTO grupos (nombre, integrantes, saldo, icono) VALUES ('Viejo', 2, 0, 'otro');");
        },
      ),
    );
    await vieja.close();

    await DbHelper().setCurrentUser(90);
    expect(await GrupoRepository().getGrupos(), isEmpty,
        reason: 'El grupo del modelo anterior tenia que borrarse');

    await _crearGrupoConParticipantes('Nuevo', <String>['Sol']);
    expect((await GrupoRepository().getGrupos()).map((Grupo g) => g.nombre), <String>['Nuevo']);
  });

  testWidgets('Flujo completo: crear grupo, cargar un gasto y ver el saldo', (WidgetTester tester) async {
    await tester.runAsync(() async {
      await UsuarioRepository().crearUsuario(nombre: 'Alejo', email: 'alejo@grupos.com', password: 'x12345');
    });
    await tester.pumpWidget(const MaterialApp(home: GroupsScreen()));
    await tester.pumpAndSettle();
    await esperarBD(tester);

    // 1. Crear el grupo con un participante.
    await tester.tap(find.byTooltip('Nuevo grupo'));
    await tester.pumpAndSettle();
    await esperarBD(tester);
    await tester.enterText(find.byType(TextFormField).at(0), 'Asado');
    await tester.enterText(find.byType(TextFormField).at(1), 'Ana');
    await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Crear grupo'));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Crear grupo'));
    await tester.pumpAndSettle();
    await esperarBD(tester);

    expect(find.text('Asado'), findsOneWidget);
    expect(find.text('Saldado'), findsOneWidget);

    // 2. Abrir el grupo y añadir un gasto de 3000 divido entre los dos.
    await tester.tap(find.text('Asado'));
    await tester.pumpAndSettle();
    await esperarBD(tester);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Añadir gasto'));
    await tester.pumpAndSettle();
    await esperarBD(tester);
    await tester.enterText(find.byType(TextFormField).at(0), 'Carne');
    await tester.enterText(find.byType(TextFormField).at(1), '3000');
    await tester.scrollUntilVisible(find.widgetWithText(ElevatedButton, 'Añadir'), 200, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Añadir'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Añadir'));
    await tester.pumpAndSettle();
    await esperarBD(tester);

    // 3. En Saldos: te deben la mitad (1.500,00) que pagaste de mas.
    await tester.tap(find.text('Saldos'));
    await tester.pumpAndSettle();
    await esperarBD(tester);
    expect(find.text('Te deben'), findsOneWidget);
    expect(find.text('\$1.500,00'), findsWidgets);
  });

  testWidgets('Eliminar un grupo no rompe la barra inferior', (WidgetTester tester) async {
    await tester.runAsync(() async {
      await UsuarioRepository().crearUsuario(nombre: 'Elena', email: 'elena@grupos.com', password: 'x12345');
      await _crearGrupoConParticipantes('Asado', <String>['Ana']);
    });
    await tester.pumpWidget(MaterialApp(home: MainNavScreen(onCerrarSesion: () {})));
    await tester.pumpAndSettle();
    await esperarBD(tester);

    await tester.tap(find.text('Grupo'));
    await tester.pumpAndSettle();
    await esperarBD(tester);
    await tester.tap(find.text('Asado'));
    await tester.pumpAndSettle();
    await esperarBD(tester);

    await tester.tap(find.byTooltip('Opciones del grupo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar grupo'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Eliminar'));
    await tester.pumpAndSettle();
    await esperarBD(tester);

    // Tocar la barra inferior despues de eliminar no debe lanzar errores.
    await tester.tap(find.text('Inicio'));
    await tester.pumpAndSettle();
    await esperarBD(tester);
    expect(find.text('Asado'), findsNothing);
  });

  testWidgets('El formulario de gasto no desborda en una pantalla angosta', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(340, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.runAsync(() async {
      await UsuarioRepository().crearUsuario(nombre: 'Fede', email: 'fede@grupos.com', password: 'x12345');
      await _crearGrupoConParticipantes('Cena', <String>['Pablo', 'Marta']);
    });
    final DatosGrupo datos = (await tester.runAsync(() async {
      final Grupo g = (await GrupoRepository().getGrupos()).first;
      return GrupoRepository().cargarGrupo(g);
    }))!;

    await tester.pumpWidget(MaterialApp(home: AnadirGastoGrupoScreen(datos: datos)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Montos exactos'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Saldos: cada persona se despliega y muestra quien le debe a quien', (WidgetTester tester) async {
    late Grupo grupo;
    await tester.runAsync(() async {
      await UsuarioRepository().crearUsuario(nombre: 'Ana', email: 'ana@saldos.com', password: 'x12345');
      final DatosGrupo datos = await _crearGrupoConParticipantes('Cena', <String>['Joaquin', 'Juan']);
      final int joaquinId = datos.participantes.firstWhere((Participante p) => p.nombre == 'Joaquin').id!;
      await _gastoIgual(datos, 'Pizza', 3000, joaquinId);
      grupo = (await GrupoRepository().getGrupos()).first;
    });

    await tester.pumpWidget(MaterialApp(home: GrupoDetalleScreen(grupo: grupo)));
    await tester.pumpAndSettle();
    await esperarBD(tester);
    await tester.tap(find.text('Saldos'));
    await tester.pumpAndSettle();

    // Ana debe $1.000 a Joaquin: al desplegarla se ve la deuda.
    await tester.tap(find.text('Ana'));
    await tester.pumpAndSettle();
    expect(find.text('Le debés \$1.000,00 a Joaquin'), findsOneWidget);
  });

  test('Un gasto con dos que pusieron plata acredita a los dos', () {
    final Participante yo = Participante(1, 'Ana', true, 1);
    final Participante beto = Participante(1, 'Beto', false, 2);
    final Participante carlos = Participante(1, 'Carlos', false, 3);
    final GastoGrupo gasto = GastoGrupo.withId(1, 1, 'Carne', 100000, 1, '2026-11-17', 0);

    final Map<int, int> netos = saldosNetosEnCentavos(
      participantes: <Participante>[yo, beto, carlos],
      gastos: <GastoGrupo>[gasto],
      partes: <ParteGasto>[
        ParteGasto.withId(1, 1, 1, 1, 33333.34),
        ParteGasto.withId(2, 1, 1, 2, 33333.33),
        ParteGasto.withId(3, 1, 1, 3, 33333.33),
      ],
      pagos: <PagoGrupo>[],
      aportes: <AporteGasto>[
        AporteGasto.withId(1, 1, 1, 1, 60000),
        AporteGasto.withId(2, 1, 1, 2, 40000),
      ],
    );

    // Ana puso 60.000 y le toca 33.333,34; Beto puso 40.000 y le toca 33.333,33.
    expect(netos[1], 2666666);
    expect(netos[2], 666667);
    expect(netos[3], -3333333);
    expect(netos.values.fold(0, (int a, int b) => a + b), 0);
  });

  test('Dos personas pueden poner plata para el mismo gasto', () async {
    await UsuarioRepository().crearUsuario(nombre: 'Eva', email: 'eva@grupos.com', password: 'x12345');
    final DatosGrupo datos = await _crearGrupoConParticipantes('Cena', <String>['Luis']);
    final int luisId =
        datos.participantes.firstWhere((Participante p) => !p.esYo).id!;
    final List<int> ids = datos.participantes.map((Participante p) => p.id!).toList();
    final List<double> partes = dividirIgual(6000, ids.length);

    final GastoGrupo gasto =
        GastoGrupo(datos.grupo.id!, 'Pizza', 6000, datos.yoId!, '2026-11-17');
    await GrupoRepository().guardarGasto(
      gasto: gasto,
      partes: [
        for (int i = 0; i < ids.length; i++)
          ParteGasto(0, datos.grupo.id!, ids[i], partes[i]),
      ],
      aportes: [
        AporteGasto(0, datos.grupo.id!, datos.yoId!, 4000),
        AporteGasto(0, datos.grupo.id!, luisId, 2000),
      ],
      yoId: datos.yoId,
      nombreGrupo: 'Cena',
    );

    final DatosGrupo tras = await GrupoRepository().cargarGrupo(datos.grupo);
    // Pusiste 4.000 y te tocan 3.000: te deben 1.000.
    expect(tras.miSaldo, 1000);
    // Luis puso 2.000 y le tocan 3.000: debe 1.000.
    expect(tras.netosEnCentavos[luisId], -100000);
    final List<Reembolso> reembolsos = tras.reembolsos;
    expect(reembolsos, hasLength(1));
    expect(reembolsos.first.deudorId, luisId);
    expect(reembolsos.first.acreedorId, datos.yoId);
    expect(reembolsos.first.monto, 1000);
    expect(tras.fraseQuienPago(gasto), 'Pusieron Ana (yo) y Luis');
  });

  test('Una base de la version 2 llena los aportes de sus gastos', () async {
    final String ruta = '$_dirTest/finanzapp_91.db';
    final Database vieja = await databaseFactory.openDatabase(
      ruta,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (Database db, int version) async {
          await db.execute('CREATE TABLE grupos ('
              'id INTEGER PRIMARY KEY AUTOINCREMENT, nombre TEXT, emoji TEXT);');
          await db.execute('CREATE TABLE grupo_participantes ('
              'id INTEGER PRIMARY KEY AUTOINCREMENT, grupoId INTEGER, '
              'nombre TEXT, esYo INTEGER);');
          await db.execute('CREATE TABLE grupo_gastos ('
              'id INTEGER PRIMARY KEY AUTOINCREMENT, grupoId INTEGER, '
              'titulo TEXT, monto REAL, pagadoPor INTEGER, fecha TEXT, '
              'movimientoId INTEGER DEFAULT 0);');
          await db.execute('CREATE TABLE grupo_gasto_partes ('
              'id INTEGER PRIMARY KEY AUTOINCREMENT, gastoId INTEGER, '
              'grupoId INTEGER, participanteId INTEGER, monto REAL);');
          await db.execute("INSERT INTO grupos (nombre, emoji) VALUES ('V2', 'x');");
          await db.execute(
              "INSERT INTO grupo_participantes (grupoId, nombre, esYo) VALUES (1, 'Ana', 1);");
          await db.execute(
              "INSERT INTO grupo_gastos (grupoId, titulo, monto, pagadoPor, fecha) "
              "VALUES (1, 'Carne', 50000, 1, '2026-11-17');");
          await db.execute(
              "INSERT INTO grupo_gasto_partes (gastoId, grupoId, participanteId, monto) "
              "VALUES (1, 1, 1, 50000);");
        },
      ),
    );
    await vieja.close();

    await DbHelper().setCurrentUser(91);
    final Grupo grupo = (await GrupoRepository().getGrupos()).first;
    final DatosGrupo datos = await GrupoRepository().cargarGrupo(grupo);

    expect(datos.gastos, hasLength(1));
    expect(datos.aportesDe(datos.gastos.first), hasLength(1),
        reason: 'El gasto viejo tenia que pasar a tener un aporte');
    expect(datos.aportesDe(datos.gastos.first).first.participanteId, 1);
    expect(datos.aportesDe(datos.gastos.first).first.monto, 50000);
    expect(datos.miSaldo, 50000 - 50000,
        reason: 'Ana pago 50.000 y le tocan 50.000: queda en cero');
  });

  testWidgets('Se puede marcar que dos personas pusieron plata', (WidgetTester tester) async {
    late DatosGrupo datos;
    await tester.runAsync(() async {
      await UsuarioRepository().crearUsuario(nombre: 'Fito', email: 'fito@grupos.com', password: 'x12345');
      datos = await _crearGrupoConParticipantes('Asado', <String>['Dina']);
    });

    await tester.pumpWidget(MaterialApp(home: AnadirGastoGrupoScreen(datos: datos)));
    await tester.pumpAndSettle();

    expect(find.text('Quién puso plata'), findsOneWidget);

    // Se pone el total y se marca a la otra persona.
    await tester.enterText(find.byType(TextFormField).at(1), '8000');
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).at(1)); // Dina, en la lista de aportes.
    await tester.pumpAndSettle();
    expect(find.text('Suma \$8.000,00 de \$8.000,00'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(1), '10000');
    await tester.pumpAndSettle();
    // Como ninguno de los dos montos se toco a mano, se reparte 5.000 c/u.
    expect(find.text('Suma \$10.000,00 de \$10.000,00'), findsOneWidget);
  });
}
