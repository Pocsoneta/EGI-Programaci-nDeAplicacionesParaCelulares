import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/grupo_repository.dart';
import '../model/model.dart';
import '../util/grupo_calculos.dart';
import '../util/tema.dart';
import '../util/utils.dart';

// Reembolsos del grupo, separados en lo que te involucra (te deben / debés) y
// los pagos entre otros participantes. "Solicitar" copia un mensaje de cobro.
// "¡Está pagado!" registra el pago.
class ReembolsosScreen extends StatefulWidget {
  final Grupo grupo;

  const ReembolsosScreen({super.key, required this.grupo});

  @override
  State<ReembolsosScreen> createState() => _ReembolsosScreenState();
}

class _ReembolsosScreenState extends State<ReembolsosScreen> {
  static const Color _azul = Color(0xFF4C68FF);

  late Future<DatosGrupo> _datosFuture;

  @override
  void initState() {
    super.initState();
    _datosFuture = GrupoRepository().cargarGrupo(widget.grupo);
  }

  void _recargar() {
    final Future<DatosGrupo> futuro = GrupoRepository().cargarGrupo(widget.grupo);
    setState(() {
      _datosFuture = futuro;
    });
  }

  String _mensajeCobro(DatosGrupo datos, Reembolso r) {
    final String monto = formatearMonedaExacta(r.monto);
    final String deudor = datos.nombreSimple(r.deudorId);
    final String acreedor = datos.nombreSimple(r.acreedorId);
    if (r.acreedorId == datos.yoId) {
      return 'Hola $deudor, te recuerdo que me debés $monto por el grupo ${widget.grupo.nombre}.';
    }
    return '$deudor le debe $monto a $acreedor por el grupo ${widget.grupo.nombre}.';
  }

  Future<void> _copiar(DatosGrupo datos, Reembolso r) async {
    await Clipboard.setData(ClipboardData(text: _mensajeCobro(datos, r)));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mensaje de cobro copiado')),
      );
    }
  }

  Future<void> _marcarPagado(Reembolso r) async {
    await GrupoRepository().registrarPago(PagoGrupo(
      widget.grupo.id!,
      r.deudorId,
      r.acreedorId,
      r.monto,
      fechaHoy(),
    ));
    _recargar();
  }

  Future<void> _quitarPago(PagoGrupo pago) async {
    await GrupoRepository().eliminarPago(pago.id!);
    _recargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.col.fondo,
      appBar: AppBar(
        title: const Text('Reembolsos', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: context.col.superficie,
        elevation: 0,
      ),
      body: FutureBuilder<DatosGrupo>(
        future: _datosFuture,
        builder: (context, snapshot) {
          final DatosGrupo? datos = snapshot.data;
          if (datos == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return _buildContenido(datos);
        },
      ),
    );
  }

  Widget _buildContenido(DatosGrupo datos) {
    final int? yo = datos.yoId;
    final List<Reembolso> pendientes = datos.reembolsos;
    final List<Reembolso> cobros =
        pendientes.where((Reembolso r) => r.acreedorId == yo).toList();
    final List<Reembolso> pagos =
        pendientes.where((Reembolso r) => r.deudorId == yo).toList();
    final List<Reembolso> otros = pendientes
        .where((Reembolso r) => r.acreedorId != yo && r.deudorId != yo)
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (pendientes.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'No hay reembolsos pendientes. Todo está saldado.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.col.subtexto),
            ),
          ),
        if (cobros.isNotEmpty) ...[
          _titulo('Te deben'),
          ...cobros.map((Reembolso r) => _tarjetaReembolso(datos, r)),
        ],
        if (pagos.isNotEmpty) ...[
          _titulo('Tenés que pagar'),
          ...pagos.map((Reembolso r) => _tarjetaReembolso(datos, r)),
        ],
        if (otros.isNotEmpty) ...[
          _titulo('Otros pagos del grupo'),
          ...otros.map((Reembolso r) => _tarjetaReembolso(datos, r)),
        ],
        const SizedBox(height: 20),
        _titulo('Pagos registrados'),
        if (datos.pagos.isEmpty)
          Text('Todavía no registraste pagos.', style: TextStyle(color: context.col.subtexto))
        else
          ...datos.pagos.map((PagoGrupo pago) => _filaPago(datos, pago)),
      ],
    );
  }

  Widget _titulo(String texto) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 10),
      child: Text(
        texto,
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.col.titulo),
      ),
    );
  }

  Widget _tarjetaReembolso(DatosGrupo datos, Reembolso r) {
    final bool meCobran = r.acreedorId == datos.yoId;
    final bool yoDebo = r.deudorId == datos.yoId;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.col.superficie,
        borderRadius: BorderRadius.circular(16),
        border: (meCobran || yoDebo)
            ? Border.all(color: _azul.withAlpha(90), width: 1.5)
            : null,
      ),
      child: Column(
        children: [
          Text.rich(
            TextSpan(
              style: TextStyle(fontSize: 14, color: context.col.subtexto),
              children: [
                TextSpan(
                  text: datos.nombreDe(r.deudorId),
                  style: TextStyle(fontWeight: FontWeight.bold, color: context.col.titulo),
                ),
                const TextSpan(text: ' debe a '),
                TextSpan(
                  text: datos.nombreDe(r.acreedorId),
                  style: TextStyle(fontWeight: FontWeight.bold, color: context.col.titulo),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            formatearMonedaExacta(r.monto),
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: context.col.titulo),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _azul,
                    foregroundColor: Colors.white,
                    elevation: 0,
                  ),
                  onPressed: () => _copiar(datos, r),
                  child: const Text('Solicitar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _marcarPagado(r),
                  child: const Text('¡Está pagado!'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filaPago(DatosGrupo datos, PagoGrupo pago) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
      decoration: BoxDecoration(color: context.col.superficie, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${datos.nombreDe(pago.deudorId)} pagó a ${datos.nombreDe(pago.acreedorId)}',
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Text(
            formatearMonedaExacta(pago.monto),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          IconButton(
            tooltip: 'Quitar pago',
            icon: Icon(Icons.undo, color: context.col.sutil),
            onPressed: () => _quitarPago(pago),
          ),
        ],
      ),
    );
  }
}
