import 'package:flutter/material.dart';
import '../data/usuario_repository.dart';
import '../util/tema.dart';
import 'auth_widgets.dart';
import 'codigo_recuperacion_dialog.dart';
import 'login_screen.dart';

class UsuarioScreen extends StatefulWidget {
  const UsuarioScreen({super.key});

  @override
  State<UsuarioScreen> createState() => _UsuarioScreenState();
}

class _UsuarioScreenState extends State<UsuarioScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _ocultarPassword = true;

  @override
  void dispose() {
    _nombreController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _crearCuenta() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    int? userId;
    try {
      userId = await UsuarioRepository().crearUsuario(
        nombre: _nombreController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
    } on EmailEnUsoException {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ya existe una cuenta con ese correo')),
      );
      return;
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo crear la cuenta')),
      );
      return;
    }
    if (!mounted) {
      return;
    }
    // Codigo de recuperacion: se muestra una sola vez, antes de entrar.
    final String codigo = await UsuarioRepository().generarNuevoCodigo(
      userId,
      _emailController.text.trim(),
    );
    if (!mounted) {
      return;
    }
    await mostrarCodigoRecuperacion(context, codigo);
    if (!mounted) {
      return;
    }
    // La sesion queda guardada en disco: al volver a abrir la app el usuario
    // no tiene que loguearse de nuevo.
    await UsuarioRepository().guardarSesion(userId);
    if (!mounted) {
      return;
    }
    // Se retorna el id del usuario creado; la app debe recargar sus datos.
    Navigator.of(context).pop(userId);
  }

  // Abre el login encima de este registro. Si entra con una cuenta, el id se
  // reenvia hacia arriba para que la pantalla principal cargue esa cuenta.
  Future<void> _irAIniciarSesion() async {
    final int? userId = await Navigator.of(context).push<int>(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
    if (userId != null && mounted) {
      Navigator.of(context).pop(userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.col.fondo,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const CabeceraAuth(
              icono: Icons.person_add_alt_1_rounded,
              titulo: 'Nueva cuenta',
              subtitulo: 'Creá tu cuenta para empezar a registrar tus finanzas',
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
                        controller: _nombreController,
                        decoration: decoracionAuth(
                          context: context,
                          etiqueta: 'Nombre',
                          icono: Icons.person_outline,
                        ),
                        validator: (value) => (value == null || value.trim().isEmpty)
                            ? 'Ingresá un nombre'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: decoracionAuth(
                          context: context,
                          etiqueta: 'Correo',
                          icono: Icons.mail_outline,
                        ),
                        validator: (value) => (value == null || !value.contains('@'))
                            ? 'Ingresá un correo válido'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _ocultarPassword,
                        decoration: decoracionAuth(
                          context: context,
                          etiqueta: 'Contraseña',
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
                        onPressed: _crearCuenta,
                        child: const Text(
                          'Crear cuenta',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancelar'),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _irAIniciarSesion,
                        child: const Text('¿Ya tenés una cuenta? Iniciá sesión'),
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
