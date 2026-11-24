import 'package:flutter/material.dart';

import '../data/grupo_repository.dart';
import '../model/model.dart';
import '../util/grupo_calculos.dart';
import '../util/tema.dart';
import '../util/utils.dart';

// Alta o edicion de un gasto compartido. Se elige quien puso plata (una o
// varias personas, cada una con su monto), la fecha y como se divide: partes
// iguales (con centavos exactos) o montos exactos por persona.
class AnadirGastoGrupoScreen extends StatefulWidget {
  final DatosGrupo datos;
  final GastoGrupo? gasto; // null -> alta

  const AnadirGastoGrupoScreen({super.key, required this.datos, this.gasto});

  @override
  State<AnadirGastoGrupoScreen> createState() => _AnadirGastoGrupoScreenState();
}

class _AnadirGastoGrupoScreenState extends State<AnadirGastoGrupoScreen> {
  static const Color _azul = Color(0xFF4C68FF);

  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();
  final _montoController = TextEditingController();
  final Map<int, TextEditingController> _exactos = <int, TextEditingController>{};
  final Map<int, bool> _incluidos = <int, bool>{};
  // Quien puso plata y cuanto. Los montos que el usuario toco a mano no se
  // recalculan al cambiar la seleccion o el total.
  final Map<int, bool> _aporta = <int, bool>{};
  final Map<int, TextEditingController> _montosPagados = <int, TextEditingController>{};
  final Set<int> _aporteEditado = <int>{};

  late String _fecha;
  bool _exacto = false;
  bool _guardando = false;

  bool get _esEdicion => widget.gasto != null;

  List<Participante> get _participantes => widget.datos.participantes;

  @override
  void initState() {
    super.initState();
    final GastoGrupo? gasto = widget.gasto;
    for (final Participante p in _participantes) {
      _incluidos[p.id!] = true;
      _exactos[p.id!] = TextEditingController();
      _aporta[p.id!] = false;
      _montosPagados[p.id!] = TextEditingController();
    }
    if (gasto == null) {
      // Por defecto pones la plata vos, por el total.
      final int? yo = widget.datos.yoId ?? _participantes.first.id;
      if (yo != null) {
        _aporta[yo] = true;
      }
      _fecha = fechaHoy();
      _repartirAportes();
      return;
    }
    _tituloController.text = gasto.titulo;
    _montoController.text = gasto.monto.toStringAsFixed(2);
    _fecha = gasto.fecha;
    _cargarAportes();
    _cargarPartes();
  }

  // Carga quien puso plata en el gasto que se edita. Los montos quedan
  // marcados como tocados para que no se recalculen solos.
  void _cargarAportes() {
    for (final AporteGasto aporte in widget.datos.aportesDe(widget.gasto!)) {
      if (!_montosPagados.containsKey(aporte.participanteId)) {
        continue;
      }
      _aporta[aporte.participanteId] = true;
      _montosPagados[aporte.participanteId]!.text =
          aporte.monto.toStringAsFixed(2);
      _aporteEditado.add(aporte.participanteId);
    }
  }

  // Carga las partes del gasto que se edita. Si no coinciden con una division
  // igual, el gasto se muestra en modo "montos exactos".
  void _cargarPartes() {
    final List<ParteGasto> partes = widget.datos.partes
        .where((ParteGasto p) => p.gastoId == widget.gasto!.id)
        .toList();
    for (final Participante p in _participantes) {
      final ParteGasto? parte = partes.where((ParteGasto x) => x.participanteId == p.id).firstOrNull;
      _incluidos[p.id!] = parte != null;
      _exactos[p.id!]!.text = parte == null ? '' : parte.monto.toStringAsFixed(2);
    }
    final List<double> iguales = dividirIgual(
      widget.gasto!.monto,
      partes.length,
    );
    final List<double> montos = partes.map((ParteGasto p) => p.monto).toList();
    _exacto = !_mismosMontos(iguales, montos);
  }

  bool _mismosMontos(List<double> a, List<double> b) {
    if (a.length != b.length) {
      return false;
    }
    final List<double> ordenA = List<double>.of(a)..sort();
    final List<double> ordenB = List<double>.of(b)..sort();
    for (int i = 0; i < ordenA.length; i++) {
      if ((ordenA[i] - ordenB[i]).abs() > 0.005) {
        return false;
      }
    }
    return true;
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _montoController.dispose();
    for (final TextEditingController c in _exactos.values) {
      c.dispose();
    }
    for (final TextEditingController c in _montosPagados.values) {
      c.dispose();
    }
    super.dispose();
  }

  double? get _monto => double.tryParse(_montoController.text.replaceAll(',', '.'));

  List<int> get _idsIncluidos =>
      _participantes.map((Participante p) => p.id!).where((int id) => _incluidos[id] == true).toList();

  List<int> get _idsAportan =>
      _participantes.map((Participante p) => p.id!).where((int id) => _aporta[id] == true).toList();

  // Reparte el total entre quienes pusieron plata. Los montos que el usuario
  // escribio a mano se respetan: el resto se divide en lo que falta.
  void _repartirAportes() {
    final List<int> ids = _idsAportan;
    if (ids.isEmpty) {
      return;
    }
    double yaPuesto = 0;
    final List<int> sinMonto = <int>[];
    for (final int id in ids) {
      if (_aporteEditado.contains(id)) {
        yaPuesto +=
            double.tryParse(_montosPagados[id]!.text.replaceAll(',', '.')) ?? 0;
      } else {
        sinMonto.add(id);
      }
    }
    if (sinMonto.isEmpty) {
      return;
    }
    double falta = (_monto ?? 0) - yaPuesto;
    if (falta < 0) {
      falta = 0;
    }
    final List<double> partes = dividirIgual(falta, sinMonto.length);
    for (int i = 0; i < sinMonto.length; i++) {
      _montosPagados[sinMonto[i]]!.text = partes[i].toStringAsFixed(2);
    }
  }

  // Suma de lo que pusieron quienes estan marcados.
  double get _sumaAportes {
    double suma = 0;
    for (final int id in _idsAportan) {
      suma += double.tryParse(_montosPagados[id]!.text.replaceAll(',', '.')) ?? 0;
    }
    return suma;
  }

  // Monto que le toca a cada incluido en la division igual (vista previa).
  Map<int, double> get _montosIguales {
    final List<int> ids = _idsIncluidos;
    final List<double> partes = dividirIgual(_monto ?? 0, ids.length);
    return <int, double>{for (int i = 0; i < ids.length; i++) ids[i]: partes[i]};
  }

  Future<void> _elegirFecha() async {
    final DateTime? elegida = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_fecha) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (elegida != null) {
      final String mes = elegida.month.toString().padLeft(2, '0');
      final String dia = elegida.day.toString().padLeft(2, '0');
      setState(() => _fecha = '${elegida.year}-$mes-$dia');
    }
  }

  void _mostrar(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final double monto = _monto!;
    final List<int> ids = _idsIncluidos;
    if (ids.isEmpty) {
      _mostrar('Elegí al menos una persona para dividir');
      return;
    }
    final List<int> queAportan = _idsAportan;
    if (queAportan.isEmpty) {
      _mostrar('Elegí quién puso plata para este gasto');
      return;
    }
    if ((_sumaAportes - monto).abs() > 0.005) {
      _mostrar(
          'Lo que pusieron debe sumar ${formatearMonedaExacta(monto)} (va ${formatearMonedaExacta(_sumaAportes)})');
      return;
    }

    final List<ParteGasto> partes = <ParteGasto>[];
    if (_exacto) {
      double suma = 0;
      for (final int id in ids) {
        final double valor =
            double.tryParse(_exactos[id]!.text.replaceAll(',', '.')) ?? 0;
        suma += valor;
        partes.add(ParteGasto(0, widget.datos.grupo.id!, id, valor));
      }
      if ((suma - monto).abs() > 0.005) {
        _mostrar('Los montos deben sumar ${formatearMonedaExacta(monto)}');
        return;
      }
    } else {
      final Map<int, double> iguales = _montosIguales;
      for (final int id in ids) {
        partes.add(ParteGasto(0, widget.datos.grupo.id!, id, iguales[id]!));
      }
    }

    setState(() => _guardando = true);
    final GastoGrupo gasto = widget.gasto ??
        GastoGrupo(widget.datos.grupo.id!, '', monto, queAportan.first, _fecha);
    gasto
      ..titulo = _tituloController.text.trim()
      ..monto = monto
      ..pagadoPor = queAportan.first
      ..fecha = _fecha;
    final List<AporteGasto> aportes = <AporteGasto>[
      for (final int id in queAportan)
        AporteGasto(
          0,
          widget.datos.grupo.id!,
          id,
          double.parse(_montosPagados[id]!.text.replaceAll(',', '.')),
        ),
    ];
    await GrupoRepository().guardarGasto(
      gasto: gasto,
      partes: partes,
      aportes: aportes,
      yoId: widget.datos.yoId,
      nombreGrupo: widget.datos.grupo.nombre,
    );
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Map<int, double> iguales = _montosIguales;
    return Scaffold(
      backgroundColor: context.col.fondo,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Cerrar',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _esEdicion ? 'Editar gasto' : 'Añadir gasto',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: context.col.superficie,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _etiqueta('Título'),
            TextFormField(
              controller: _tituloController,
              decoration: _decoracion('Por ejemplo, Carne'),
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? 'Ingresá un título' : null,
            ),
            const SizedBox(height: 16),
            _etiqueta('Cantidad'),
            TextFormField(
              controller: _montoController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: _decoracion('0,00').copyWith(prefixText: '\$ '),
              onChanged: (_) => setState(_repartirAportes),
              validator: (value) {
                final double? monto =
                    double.tryParse((value ?? '').replaceAll(',', '.'));
                if (monto == null || monto <= 0) {
                  return 'Ingresá un monto válido';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _etiqueta('Quién puso plata'),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: context.col.superficie,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: _participantes.map((Participante p) {
                  final int id = p.id!;
                  final bool pago = _aporta[id] == true;
                  return Row(
                    children: [
                      Checkbox(
                        value: pago,
                        activeColor: _azul,
                        onChanged: (bool? valor) => setState(() {
                          _aporta[id] = valor ?? false;
                          if (valor != true) {
                            _aporteEditado.remove(id);
                            _montosPagados[id]!.clear();
                          }
                          _repartirAportes();
                        }),
                      ),
                      Expanded(
                        child: Text(
                          p.esYo ? '${p.nombre} (yo)' : p.nombre,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (pago)
                        SizedBox(
                          width: 120,
                          child: TextFormField(
                            controller: _montosPagados[id],
                            textAlign: TextAlign.right,
                            keyboardType:
                                const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                                prefixText: '\$ ', isDense: true),
                            onChanged: (_) => setState(() {
                              _aporteEditado.add(id);
                            }),
                          ),
                        )
                      else
                        Text('—', style: TextStyle(color: context.col.sutil)),
                      const SizedBox(width: 8),
                    ],
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Suma ${formatearMonedaExacta(_sumaAportes)} de ${formatearMonedaExacta(_monto ?? 0)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: ((_sumaAportes - (_monto ?? 0)).abs() <= 0.005)
                      ? _azul
                      : Colors.redAccent,
                ),
              ),
            ),
            const SizedBox(height: 10),
            _etiqueta('Cuándo'),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                foregroundColor: context.col.titulo,
                backgroundColor: context.col.superficie,
                side: BorderSide.none,
              ),
              onPressed: _elegirFecha,
              child: Text(formatearFecha(_fecha)),
            ),
            const SizedBox(height: 20),
            _etiqueta('Dividir'),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: false, label: Text('Igualmente')),
                  ButtonSegment(value: true, label: Text('Montos exactos')),
                ],
                selected: {_exacto},
                onSelectionChanged: (Set<bool> sel) => setState(() => _exacto = sel.first),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: context.col.superficie,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: _participantes.map((Participante p) {
                  final int id = p.id!;
                  final bool incluido = _incluidos[id] == true;
                  return Row(
                    children: [
                      Checkbox(
                        value: incluido,
                        activeColor: _azul,
                        onChanged: (bool? valor) => setState(() => _incluidos[id] = valor ?? false),
                      ),
                      Expanded(
                        child: Text(
                          p.esYo ? '${p.nombre} (yo)' : p.nombre,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_exacto)
                        SizedBox(
                          width: 120,
                          child: TextFormField(
                            controller: _exactos[id],
                            enabled: incluido,
                            textAlign: TextAlign.right,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(prefixText: '\$ ', isDense: true),
                            onChanged: (_) => setState(() {}),
                          ),
                        )
                      else
                        Text(
                          formatearMonedaExacta(incluido ? (iguales[id] ?? 0) : 0),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      const SizedBox(width: 8),
                    ],
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: _azul,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _guardando ? null : _guardar,
              child: Text(
                _esEdicion ? 'Guardar cambios' : 'Añadir',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _etiqueta(String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        texto,
        style: TextStyle(fontWeight: FontWeight.bold, color: context.col.titulo),
      ),
    );
  }

  InputDecoration _decoracion(String pista) {
    return InputDecoration(
      hintText: pista,
      filled: true,
      fillColor: context.col.superficie,
      isDense: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }
}
