import 'package:flutter/material.dart';

import '../data/ingreso_repository.dart';
import '../model/model.dart';
import '../util/utils.dart';

// Dialogo de alta y edicion de ingresos (concepto + monto + fecha).
class DialogoIngreso extends StatefulWidget {
  // Ingreso a editar. Null -> modo alta.
  final Ingreso? ingreso;

  const DialogoIngreso({super.key, this.ingreso});

  @override
  State<DialogoIngreso> createState() => DialogoIngresoState();
}

class DialogoIngresoState extends State<DialogoIngreso> {
  final _formKey = GlobalKey<FormState>();
  final _conceptoController = TextEditingController();
  final _montoController = TextEditingController();
  late DateTime _fecha;

  bool get _esEdicion => widget.ingreso != null;

  @override
  void initState() {
    super.initState();
    final Ingreso? ingreso = widget.ingreso;
    if (ingreso != null) {
      _conceptoController.text = ingreso.concepto;
      _montoController.text = ingreso.monto.toStringAsFixed(2);
      _fecha = DateTime.tryParse(ingreso.fecha) ?? DateTime.now();
    } else {
      _fecha = DateTime.now();
    }
  }

  @override
  void dispose() {
    _conceptoController.dispose();
    _montoController.dispose();
    super.dispose();
  }

  String _aTextoFecha(DateTime fecha) {
    final String mes = fecha.month.toString().padLeft(2, '0');
    final String dia = fecha.day.toString().padLeft(2, '0');
    return '${fecha.year}-$mes-$dia';
  }

  Future<void> _elegirFecha() async {
    final DateTime? seleccionada = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (seleccionada != null) {
      setState(() => _fecha = seleccionada);
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final double monto =
        double.tryParse(_montoController.text.replaceAll(',', '.')) ?? 0;
    final Ingreso ingreso = Ingreso(
      _conceptoController.text.trim(),
      monto,
      _aTextoFecha(_fecha),
      widget.ingreso?.id,
    );
    if (_esEdicion) {
      await IngresoRepository().updateIngreso(ingreso);
    } else {
      await IngresoRepository().addIngreso(ingreso);
    }
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_esEdicion ? 'Editar ingreso' : 'Agregar ingreso'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _conceptoController,
                decoration: const InputDecoration(
                  labelText: 'Concepto',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Ingresá un concepto'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _montoController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Monto',
                  prefixText: '\$',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Ingresá el monto';
                  }
                  final double? monto =
                      double.tryParse(value.replaceAll(',', '.'));
                  if (monto == null || monto <= 0) {
                    return 'Ingresá un monto mayor a cero';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _elegirFecha,
                borderRadius: BorderRadius.circular(8),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Fecha',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                  child: Text(formatearFecha(_aTextoFecha(_fecha))),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _guardar,
          child: Text(_esEdicion ? 'Guardar cambios' : 'Guardar'),
        ),
      ],
    );
  }
}
