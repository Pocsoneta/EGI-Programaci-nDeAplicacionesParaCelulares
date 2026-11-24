import 'package:flutter/material.dart';

import '../data/grupo_repository.dart';
import '../model/model.dart';
import '../util/grupo_calculos.dart';
import '../util/tema.dart';
import '../util/utils.dart';
import 'anadir_gasto_grupo_screen.dart';
import 'reembolsos_screen.dart';

// Ficha de un grupo con dos pestañas: Gastos (lo que se pagó y se divide) y
// Saldos (cuánto te deben o debés, calculado desde los gastos).
class GrupoDetalleScreen extends StatefulWidget {
  final Grupo grupo;

  const GrupoDetalleScreen({super.key, required this.grupo});

  @override
  State<GrupoDetalleScreen> createState() => _GrupoDetalleScreenState();
}

class _GrupoDetalleScreenState extends State<GrupoDetalleScreen> {
  static const Color _azul = Color(0xFF4C68FF);

  late Future<DatosGrupo> _datosFuture;
  bool _verSaldos = false;

  @override
  void initState() {
    super.initState();
    _datosFuture = _cargar();
  }

  Future<DatosGrupo> _cargar() {
    return GrupoRepository().cargarGrupo(widget.grupo);
  }

  void _recargar() {
    final Future<DatosGrupo> futuro = _cargar();
    setState(() {
      _datosFuture = futuro;
    });
  }

  void _mostrar(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  Future<void> _anadirGasto(DatosGrupo datos, {GastoGrupo? gasto}) async {
    final bool? guardado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => AnadirGastoGrupoScreen(datos: datos, gasto: gasto),
      ),
    );
    if (guardado == true && mounted) {
      _recargar();
    }
  }

  Future<void> _eliminarGasto(GastoGrupo gasto) async {
    final bool? confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar gasto'),
        content: Text('¿Querés eliminar "${gasto.titulo}"? Tu parte también se quita de tus gastos.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) {
      return;
    }
    await GrupoRepository().eliminarGasto(gasto);
    _recargar();
  }

  Future<void> _anadirParticipante(DatosGrupo datos) async {
    final TextEditingController controlador = TextEditingController();
    final String? nombre = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Añadir participante'),
        content: TextField(
          controller: controlador,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nombre'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controlador.text.trim()),
            child: const Text('Añadir'),
          ),
        ],
      ),
    );
    controlador.dispose();
    if (nombre == null || nombre.isEmpty || !mounted) {
      return;
    }
    final bool repetido = datos.participantes
        .any((Participante p) => p.nombre.toLowerCase() == nombre.toLowerCase());
    if (repetido) {
      _mostrar('Ya hay un participante con ese nombre');
      return;
    }
    await GrupoRepository().addParticipante(
      Participante(widget.grupo.id!, nombre, false),
    );
    _recargar();
  }

  Future<void> _eliminarGrupo() async {
    final bool? confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar grupo'),
        content: Text(
          '¿Querés eliminar "${widget.grupo.nombre}" con todos sus gastos? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) {
      return;
    }
    await GrupoRepository().deleteGrupo(widget.grupo.id!);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _verReembolsos() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => ReembolsosScreen(grupo: widget.grupo)),
    );
    if (mounted) {
      _recargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DatosGrupo>(
      future: _datosFuture,
      builder: (context, snapshot) {
        final DatosGrupo? datos = snapshot.data;
        return Scaffold(
          backgroundColor: context.col.fondo,
          appBar: AppBar(
            backgroundColor: context.col.superficie,
            elevation: 0,
            actions: [
              if (datos != null)
                PopupMenuButton<String>(
                  tooltip: 'Opciones del grupo',
                  onSelected: (valor) {
                    if (valor == 'participante') {
                      _anadirParticipante(datos);
                    } else if (valor == 'eliminar') {
                      _eliminarGrupo();
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'participante', child: Text('Añadir participante')),
                    PopupMenuItem(value: 'eliminar', child: Text('Eliminar grupo')),
                  ],
                ),
            ],
          ),
          body: datos == null
              ? const Center(child: CircularProgressIndicator())
              : _buildContenido(datos),
          bottomNavigationBar: datos == null || _verSaldos
              ? null
              : SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        backgroundColor: _azul,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => _anadirGasto(datos),
                      child: const Text('Añadir gasto', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildContenido(DatosGrupo datos) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        Center(
          child: Column(
            children: [
              Text(widget.grupo.emoji, style: const TextStyle(fontSize: 44)),
              const SizedBox(height: 4),
              Text(
                widget.grupo.nombre,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: context.col.titulo),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SegmentedButton<bool>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: false, label: Text('Gastos')),
            ButtonSegment(value: true, label: Text('Saldos')),
          ],
          selected: {_verSaldos},
          onSelectionChanged: (Set<bool> sel) => setState(() => _verSaldos = sel.first),
        ),
        const SizedBox(height: 16),
        if (_verSaldos) ..._saldos(datos) else ..._gastos(datos),
      ],
    );
  }

  List<Widget> _gastos(DatosGrupo datos) {
    final int? yo = datos.yoId;
    final double misGastos = datos.partes
        .where((ParteGasto p) => p.participanteId == yo)
        .fold(0.0, (double total, ParteGasto p) => total + p.monto);
    final double totales = datos.gastos.fold(0.0, (double total, GastoGrupo g) => total + g.monto);

    return [
      Row(
        children: [
          Expanded(child: _estadistica('Mis gastos', formatearMonedaExacta(misGastos))),
          Expanded(child: _estadistica('Gastos totales', formatearMonedaExacta(totales))),
        ],
      ),
      const SizedBox(height: 16),
      if (datos.gastos.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(
            'Aún no hay gastos. Tocá "Añadir gasto" para empezar a registrar y dividir tus gastos.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.col.subtexto),
          ),
        )
      else
        ...datos.gastos.map((GastoGrupo gasto) => _tarjetaGasto(datos, gasto)),
    ];
  }

  Widget _estadistica(String etiqueta, String valor) {
    return Column(
      children: [
        Text(etiqueta, style: TextStyle(color: context.col.subtexto, fontSize: 12)),
        const SizedBox(height: 4),
        Text(valor, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      ],
    );
  }

  Widget _tarjetaGasto(DatosGrupo datos, GastoGrupo gasto) {
    final int? yo = datos.yoId;
    final ParteGasto? miParte = datos.partes
        .where((ParteGasto p) => p.gastoId == gasto.id && p.participanteId == yo)
        .firstOrNull;
    final String detalle = miParte == null
        ? '${datos.fraseQuienPago(gasto)} · no te toca'
        : '${datos.fraseQuienPago(gasto)} · tu parte ${formatearMonedaExacta(miParte.monto)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
      decoration: BoxDecoration(
        color: context.col.superficie,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => _anadirGasto(datos, gasto: gasto),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(gasto.titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(
                    '${formatearFecha(gasto.fecha)} · $detalle',
                    style: TextStyle(color: context.col.subtexto, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          Text(
            formatearMonedaExacta(gasto.monto),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          PopupMenuButton<String>(
            tooltip: 'Acciones del gasto',
            onSelected: (valor) {
              if (valor == 'editar') {
                _anadirGasto(datos, gasto: gasto);
              } else if (valor == 'eliminar') {
                _eliminarGasto(gasto);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'editar', child: Text('Editar')),
              PopupMenuItem(value: 'eliminar', child: Text('Eliminar')),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _saldos(DatosGrupo datos) {
    final double saldo = datos.miSaldo;
    final bool teDeben = saldo > 0.005;
    final bool debes = saldo < -0.005;
    final String titulo = teDeben
        ? 'Te deben'
        : debes
            ? 'Debés'
            : 'Todo saldado';
    final Color color = teDeben
        ? Colors.green
        : debes
            ? Colors.redAccent
            : Colors.grey;

    return [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: context.col.superficie, borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            Text(titulo, style: TextStyle(color: context.col.subtexto)),
            const SizedBox(height: 4),
            Text(
              saldo.abs() < 0.005 ? 'Sin deudas' : formatearMonedaExacta(saldo.abs()),
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: () => _verReembolsos(),
        icon: const Icon(Icons.swap_horiz),
        label: const Text('Ver reembolsos'),
      ),
      const SizedBox(height: 20),
      Text('Saldos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.col.titulo)),
      const SizedBox(height: 8),
      ...datos.participantes.map((Participante p) => _filaSaldo(datos, p)),
    ];
  }

  Widget _filaSaldo(DatosGrupo datos, Participante p) {
    final int centavos = datos.netosEnCentavos[p.id] ?? 0;
    final Color color = centavos > 0
        ? Colors.green
        : centavos < 0
            ? Colors.redAccent
            : Colors.grey;
    final String monto = centavos == 0
        ? formatearMonedaExacta(0)
        : '${centavos > 0 ? '+' : '-'}${formatearMonedaExacta(centavos.abs() / 100)}';
    final List<Reembolso> deudas = datos.reembolsos
        .where((Reembolso r) => r.deudorId == p.id || r.acreedorId == p.id)
        .toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: context.col.superficie, borderRadius: BorderRadius.circular(12)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          shape: const RoundedRectangleBorder(side: BorderSide.none),
          leading: CircleAvatar(
            backgroundColor: _azul.withAlpha(30),
            child: Text(
              p.nombre.isEmpty ? '?' : p.nombre.substring(0, 1).toUpperCase(),
              style: const TextStyle(color: _azul, fontWeight: FontWeight.bold),
            ),
          ),
          title: Text(p.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: p.esYo ? const Text('Personal', style: TextStyle(color: _azul, fontSize: 12)) : null,
          trailing: Text(monto, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          children: deudas.isEmpty
              ? [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Sin deudas pendientes.', style: TextStyle(color: context.col.subtexto)),
                  ),
                ]
              : deudas.map((Reembolso r) => _lineaDeuda(datos, p, r)).toList(),
        ),
      ),
    );
  }

  // Frase de una deuda desde la perspectiva de la persona desplegada.
  Widget _lineaDeuda(DatosGrupo datos, Participante p, Reembolso r) {
    final String deudor = datos.nombreSimple(r.deudorId);
    final String acreedor = datos.nombreSimple(r.acreedorId);
    final String monto = formatearMonedaExacta(r.monto);
    final String frase;
    if (p.esYo && r.acreedorId == p.id) {
      frase = '$deudor te debe $monto';
    } else if (p.esYo) {
      frase = 'Le debés $monto a $acreedor';
    } else {
      frase = '$deudor le debe $monto a $acreedor';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(frase, style: const TextStyle(fontSize: 13)),
      ),
    );
  }
}
