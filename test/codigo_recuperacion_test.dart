// Tests de la logica del codigo de recuperacion (sin base de datos).

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/data/codigo_recuperacion.dart';
import 'package:flutter_application_1/data/contrasena.dart';

void main() {
  group('generarCodigoRecuperacion', () {
    test('Tiene formato XXXXX-XXXXX con caracteres sin confusion', () {
      final RegExp formato = RegExp(r'^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{5}-[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{5}$');

      for (int i = 0; i < 50; i++) {
        expect(formato.hasMatch(generarCodigoRecuperacion()), isTrue);
      }
    });

    test('Cada codigo generado es distinto', () {
      final Set<String> codigos = <String>{
        for (int i = 0; i < 50; i++) generarCodigoRecuperacion(),
      };

      expect(codigos, hasLength(50));
    });
  });

  group('normalizarCodigo y hashCodigoRecuperacion', () {
    test('Acepta el codigo en minusculas, con espacios o sin guion', () {
      const String original = 'K7MQ2-XW9TA';

      expect(normalizarCodigo('k7mq2-xw9ta'), 'K7MQ2XW9TA');
      expect(normalizarCodigo(' K7MQ2 XW9TA '), 'K7MQ2XW9TA');
      expect(
        hashCodigoRecuperacion('ana@test.com', 'k7mq2xw9ta'),
        hashCodigoRecuperacion('ana@test.com', original),
      );
    });

    test('El hash no es el de la contrasena con el mismo texto', () {
      const String codigo = 'K7MQ2-XW9TA';

      expect(
        hashCodigoRecuperacion('ana@test.com', codigo),
        isNot(hashContrasena('ana@test.com', 'K7MQ2XW9TA')),
      );
    });
  });
}
