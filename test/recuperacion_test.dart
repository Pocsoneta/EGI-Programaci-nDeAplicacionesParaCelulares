// Tests del flujo de recuperacion de contrasena contra la base real:
// generar el codigo, restablecer la contrasena, uso unico y cuentas sin codigo.
//
// Usa un directorio PROPIO porque flutter test ejecuta los archivos en
// paralelo y comparten la carpeta de bases de datos.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:flutter_application_1/data/contrasena.dart';
import 'package:flutter_application_1/data/dbhelper.dart';
import 'package:flutter_application_1/data/fuente_datos.dart';
import 'package:flutter_application_1/data/usuario_repository.dart';

final String _dirTest =
    '${Directory.systemTemp.path}${Platform.pathSeparator}finanzapp_test_dbs_recuperacion';

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

  test('Restablece la contrasena con el codigo, una sola vez', () async {
    final int id = await UsuarioRepository().crearUsuario(
      nombre: 'Ana',
      email: 'ana@test.com',
      password: 'vieja123',
    );
    final String codigo = await UsuarioRepository().generarNuevoCodigo(id, 'ana@test.com');

    expect(await UsuarioRepository().tieneCodigoRecuperacion(id), isTrue);

    final bool ok = await UsuarioRepository().restablecerContrasena(
      email: 'ana@test.com',
      codigo: codigo.toLowerCase(),
      nuevaPassword: 'nueva456',
    );
    expect(ok, isTrue);

    // La contrasena nueva funciona y la vieja ya no.
    final usuario = await UsuarioRepository().getUsuarioPorEmail('ana@test.com');
    expect(contrasenaCorrecta(usuario!, 'nueva456'), isTrue);
    expect(contrasenaCorrecta(usuario, 'vieja123'), isFalse);

    // El codigo se usa una sola vez: la cuenta queda sin codigo.
    expect(await UsuarioRepository().tieneCodigoRecuperacion(id), isFalse);
    final bool reuso = await UsuarioRepository().restablecerContrasena(
      email: 'ana@test.com',
      codigo: codigo,
      nuevaPassword: 'otra789',
    );
    expect(reuso, isFalse);
  });

  test('Un codigo, correo o cuenta incorrectos no restablecen nada', () async {
    final int id = await UsuarioRepository().crearUsuario(
      nombre: 'Bruno',
      email: 'bruno@test.com',
      password: 'clave123',
    );
    final String codigo = await UsuarioRepository().generarNuevoCodigo(id, 'bruno@test.com');

    final String codigoMalo = codigo == 'AAAAA-AAAAA' ? 'BBBBB-BBBBB' : 'AAAAA-AAAAA';
    expect(
      await UsuarioRepository().restablecerContrasena(
        email: 'bruno@test.com',
        codigo: codigoMalo,
        nuevaPassword: 'nueva',
      ),
      isFalse,
    );
    expect(
      await UsuarioRepository().restablecerContrasena(
        email: 'nadie@test.com',
        codigo: codigo,
        nuevaPassword: 'nueva',
      ),
      isFalse,
    );

    // Nada cambio: la contrasena original sigue valiendo y el codigo tambien.
    final usuario = await UsuarioRepository().getUsuarioPorEmail('bruno@test.com');
    expect(contrasenaCorrecta(usuario!, 'clave123'), isTrue);
    expect(await UsuarioRepository().tieneCodigoRecuperacion(id), isTrue);
  });

  test('Una cuenta sin codigo no se puede recuperar y puede generar uno nuevo', () async {
    final int id = await UsuarioRepository().crearUsuario(
      nombre: 'Carla',
      email: 'carla@test.com',
      password: 'clave123',
    );

    // Cuenta "vieja": todavia no tiene codigo.
    expect(await UsuarioRepository().tieneCodigoRecuperacion(id), isFalse);
    expect(
      await UsuarioRepository().restablecerContrasena(
        email: 'carla@test.com',
        codigo: 'AAAAA-AAAAA',
        nuevaPassword: 'nueva',
      ),
      isFalse,
    );

    // Desde el perfil se genera el codigo: el anterior (si lo hubiera) deja
    // de servir al generar uno nuevo.
    final String primero = await UsuarioRepository().generarNuevoCodigo(id, 'carla@test.com');
    final String segundo = await UsuarioRepository().generarNuevoCodigo(id, 'carla@test.com');
    expect(
      await UsuarioRepository().restablecerContrasena(
        email: 'carla@test.com',
        codigo: primero,
        nuevaPassword: 'nueva',
      ),
      isFalse,
    );
    expect(
      await UsuarioRepository().restablecerContrasena(
        email: 'carla@test.com',
        codigo: segundo,
        nuevaPassword: 'nueva',
      ),
      isTrue,
    );
  });
}
