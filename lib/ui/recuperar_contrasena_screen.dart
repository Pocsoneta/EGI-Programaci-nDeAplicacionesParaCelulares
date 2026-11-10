import 'package:flutter/material.dart';
import '../data/usuario_repository.dart';
import 'auth_widgets.dart';

// Restablece la contrasena con el correo y el codigo de recuperacion.
// Si sale bien, vuelve al login para iniciar sesion con la contrasena nueva.
class RecuperarContrasenaScreen extends StatefulWidget {
  const RecuperarContrasenaScreen({super.key});

  @override
  State<RecuperarContrasenaScreen> createState() => _RecuperarContrasenaScreenState();
}

class _RecuperarContrasenaScreenState extends State<RecuperarContrasenaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _codigoController = TextEditingController();
  final _passwordController = TextEditingController();
  final _repetirController = TextEditingController();
  bool _ocultarPassword = true;
  bool _guardando = false;

  @override
  void dispose() {
    _emailController.dispose();
    _codigoController.dispose();
    _passwordController.dispose();
    _repetirController.dispose();
    super.dispose();
  }

  Future<void> _restablecer() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _guardando = true);
    final bool ok = await UsuarioRepository().restablecerContrasena(
      email: _emailController.text,
      codigo: _codigoController.text,
      nuevaPassword: _passwordController.text.trim(),
    );
    if (!mounted) {
      return;
    }
    setState(() => _guardando = false);
    if (!ok) {
      // Mismo mensaje para correo, codigo o cuenta incorrectos: no revela
      // cuales datos existen.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo restablecer. Revisá el correo y el código.')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Contraseña actualizada. Ya podés iniciar sesión.')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const CabeceraAuth(
              icono: Icons.vpn_key_outlined,
              titulo: 'Recuperar contraseña',
              subtitulo: 'Necesitás el código que guardaste al crear la cuenta',
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: TarjetaAuth(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: decoracionAuth(
                          etiqueta: 'Correo',
                          icono: Icons.mail_outline,
                        ),
                        validator: (value) => (value == null || !value.contains('@'))
                            ? 'Ingresá un correo válido'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _codigoController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: decoracionAuth(
                          etiqueta: 'Código de recuperación',
                          icono: Icons.confirmation_number_outlined,
                        ),
                        validator: (value) => (value == null || value.trim().isEmpty)
                            ? 'Ingresá el código'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _ocultarPassword,
                        decoration: decoracionAuth(
                          etiqueta: 'Nueva contraseña',
                          icono: Icons.lock_outline,
                          sufijo: IconButton(
                            icon: Icon(_ocultarPassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined),
                            onPressed: () => setState(
                                () => _ocultarPassword = !_ocultarPassword),
                          ),
                        ),
                        validator: (value) => (value == null || value.trim().isEmpty)
                            ? 'Ingresá una contraseña'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _repetirController,
                        obscureText: _ocultarPassword,
                        decoration: decoracionAuth(
                          etiqueta: 'Repetir contraseña',
                          icono: Icons.lock_outline,
                        ),
                        validator: (value) => value != _passwordController.text.trim()
                            ? 'Las contraseñas no coinciden'
                            : null,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          backgroundColor: const Color(0xFF4C68FF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _guardando ? null : _restablecer,
                        child: const Text(
                          'Restablecer contraseña',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Volver'),
                      ),
                      const Text(
                        'Si tu cuenta no tiene código, iniciá sesión y generalo desde Mi perfil.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black45, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
