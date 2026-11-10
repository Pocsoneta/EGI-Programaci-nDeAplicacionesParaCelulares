import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Muestra el codigo de recuperacion UNA sola vez. No se puede cerrar tocando
// afuera: hay que confirmar con "Ya lo guardé", asi no se pierde sin verlo.
Future<void> mostrarCodigoRecuperacion(BuildContext context, String codigo) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) => AlertDialog(
      title: const Text('Tu código de recuperación'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Guardalo en un lugar seguro. Lo vas a necesitar si olvidás tu contraseña. '
            'Solo se muestra esta vez.',
            style: TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF6F8FC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: SelectableText(
              codigo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                color: Color(0xFF1E3C72),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: codigo));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Código copiado')),
                );
              }
            },
            icon: const Icon(Icons.copy_outlined),
            label: const Text('Copiar código'),
          ),
        ],
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Ya lo guardé'),
        ),
      ],
    ),
  );
}
