// Codigo de recuperacion de la cuenta.
//
// Es un codigo aleatorio de 10 caracteres (formato XXXXX-XXXXX) que la app
// muestra UNA sola vez. Solo se guarda su hash, igual que las contrasenas:
// si se pierde, no se puede volver a mostrar; se puede generar uno nuevo
// (lo que invalida el anterior).

import 'dart:math';

import 'contrasena.dart';

// Sin caracteres que se confunden al leerlos o copiarlos (0/O, 1/I).
const String _alfabeto = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const int _largo = 10;

/// Genera un codigo nuevo y aleatorio, por ejemplo "K7MQ2-XW9TA".
String generarCodigoRecuperacion() {
  final Random aleatorio = Random.secure();
  final StringBuffer codigo = StringBuffer();
  for (int i = 0; i < _largo; i++) {
    if (i == _largo ~/ 2) {
      codigo.write('-');
    }
    codigo.write(_alfabeto[aleatorio.nextInt(_alfabeto.length)]);
  }
  return codigo.toString();
}

/// Deja solo letras y numeros en mayusculas: el usuario puede escribir el
/// codigo con o sin guion, con espacios o en minusculas.
String normalizarCodigo(String codigo) {
  return codigo.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
}

/// Hash del codigo de recuperacion. Usa el email como sal, igual que las
/// contrasenas, y un prefijo para que nunca coincida con el hash de una
/// contrasena.
String hashCodigoRecuperacion(String email, String codigo) {
  return hashContrasena(email, 'codigo:${normalizarCodigo(codigo)}');
}
