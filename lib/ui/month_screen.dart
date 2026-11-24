import 'package:flutter/material.dart';

import '../data/gasto_repository.dart';
import '../data/ingreso_repository.dart';
import '../data/servicio_hogar_repository.dart';
import '../model/model.dart';
import '../util/tema.dart';
import '../util/utils.dart';

// Datos del periodo cargados desde los repositorios.
class _DatosMes {
  final List<Gasto> gastos;
  final List<Ingreso> ingresos;
  final List<ServicioHogar> servicios;

  const _DatosMes(this.gastos, this.ingresos, this.servicios);
}

// Reporte del mes elegido: resumen del periodo, desglose por categoria y la
// seccion de servicios del hogar. Los servicios no tienen fecha propia: su
// estado es el del mes que se esta viendo (pagado si tiene un gasto en ese
// mes, pendiente si no), y cambia al navegar con las flechas del mes.
class MonthScreen extends StatefulWidget {
  // Se avisa a la navegacion cuando cambia un servicio del hogar: marcar un
  // pago crea o elimina un gasto, lo que mueve el saldo del inicio y las
  // alertas de la campana.
  final VoidCallback? onServiciosCambiados;

  const MonthScreen({super.key, this.onServiciosCambiados});

  @override
  State<MonthScreen> createState() => _MonthScreenState();
}

class _MonthScreenState extends State<MonthScreen> {
  DateTime _currentMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  late Future<_DatosMes> _datosFuture;

  // Ultimo dato cargado. Lo usan las acciones (marcar pagado, editar...),
  // que corren fuera del builder del FutureBuilder.
  _DatosMes? _datos;

  static const List<Color> _colores = <Color>[
    Color(0xFFFFA726),
    Color(0xFF4C68FF),
    Color(0xFF26A69A),
    Color(0xFF7E57C2),
    Color(0xFFEC407A),
    Color(0xFF66BB6A),
    Color(0xFF29B6F6),
    Color(0xFF8D6E63),
  ];

  @override
  void initState() {
    super.initState();
    _datosFuture = _cargarDatos();
  }

  @override
  void didUpdateWidget(covariant MonthScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _datosFuture = _cargarDatos();
  }

  Future<_DatosMes> _cargarDatos() async {
    final List<Gasto> gastos = await GastoRepository().getGastos();
    final List<Ingreso> ingresos = await IngresoRepository().getIngresos();
    final List<ServicioHogar> servicios =
        await ServicioHogarRepository().getServicios();
    final _DatosMes datos = _DatosMes(gastos, ingresos, servicios);
    _datos = datos;
    return datos;
  }

  // Vuelve a leer gastos, ingresos y servicios, y refresca la vista.
  void _recargar() {
    // La carga arranca antes del setState: el callback de setState tiene que
    // ser sincrono (no puede devolver un Future).
    final Future<_DatosMes> futuro = _cargarDatos();
    if (mounted) {
      setState(() {
        _datosFuture = futuro;
      });
    }
  }

  void _changeMonth(int delta) {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + delta, 1);
    });
  }

  // Abre el selector de fecha para elegir el mes a mostrar.
  Future<void> _elegirMes() async {
    final DateTime? fecha = await showDatePicker(
      context: context,
      initialDate: _currentMonth,
      firstDate: DateTime(2000, 1),
      lastDate: DateTime(2100, 12),
    );
    if (fecha != null && mounted) {
      setState(() => _currentMonth = DateTime(fecha.year, fecha.month, 1));
    }
  }

  // True si la pantalla esta mostrando el mes en curso.
  bool get _esMesEnCurso =>
      ValidadorFecha.esMismaFecha(_currentMonth, DateTime.now());

  // Fecha del gasto que se crea al marcar un pago: hoy si se ve el mes en
  // curso; si no, un dia valido del mes que se esta viendo.
  String _fechaDelMes() {
    if (_esMesEnCurso) {
      return fechaHoy();
    }
    final int ultimoDia =
        DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final int dia = DateTime.now().day <= ultimoDia ? DateTime.now().day : ultimoDia;
    final String mes = _currentMonth.month.toString().padLeft(2, '0');
    final String diaTexto = dia.toString().padLeft(2, '0');
    return '${_currentMonth.year}-$mes-$diaTexto';
  }

  // Gasto que registra el pago de `servicio` dentro de `mes`, o null si en
  // ese mes sigue pendiente. Primero se mira el gasto asociado al servicio;
  // si no esta en ese mes, se busca por concepto y categoria, para que el
  // estado valga para cualquier mes y no solo para el ultimo pago cargado.
  Gasto? _gastoDelMes(ServicioHogar servicio, List<Gasto> gastos, DateTime mes) {
    for (final Gasto gasto in gastos) {
      if (gasto.id == servicio.gastoId &&
          ValidadorFecha.esMismaFecha(
              DateTime.tryParse(gasto.expiration) ?? DateTime(0), mes)) {
        return gasto;
      }
    }
    for (final Gasto gasto in gastos) {
      if (gasto.categoria == 'Servicios' &&
          gasto.concepto == servicio.titulo &&
          ValidadorFecha.esMismaFecha(
              DateTime.tryParse(gasto.expiration) ?? DateTime(0), mes)) {
        return gasto;
      }
    }
    return null;
  }

  // Avisa a la navegacion que los datos cambiaron (alertas y demas vistas).
  void _avisarCambio() {
    widget.onServiciosCambiados?.call();
  }

  // Abre el formulario de alta de un servicio del hogar.
  Future<void> _nuevoServicio() async {
    final bool? creado = await showDialog<bool>(
      context: context,
      builder: (context) => const _DialogoNuevoServicio(),
    );
    if (creado == true) {
      _recargar();
      _avisarCambio();
    }
  }

  // Abre el mismo formulario en modo edicion sobre un servicio existente.
  Future<void> _editarServicio(ServicioHogar servicio) async {
    final bool? guardado = await showDialog<bool>(
      context: context,
      builder: (context) => _DialogoNuevoServicio(servicio: servicio),
    );
    if (guardado == true) {
      _recargar();
      _avisarCambio();
    }
  }

  // Marca o desmarca un servicio como pagado EN EL MES QUE SE ESTA VIENDO
  // (se persiste en SQLite).
  //
  // Al marcarlo se registra el pago como gasto de ese mes, para que aparezca
  // en el desglose y en el saldo. Al desmarcarlo, ese gasto se elimina. El
  // campo `pagado` (el que usan las notificaciones) solo se toca cuando el
  // mes en pantalla es el mes en curso: marcar un mes viejo no cambia lo que
  // pasa hoy.
  Future<void> _alternarPagado(ServicioHogar servicio) async {
    final Gasto? existente =
        _gastoDelMes(servicio, _datos?.gastos ?? <Gasto>[], _currentMonth);
    if (existente != null) {
      await GastoRepository().deleteGasto(existente.id!);
      if (servicio.gastoId == existente.id) {
        servicio.gastoId = 0;
      }
      if (_esMesEnCurso) {
        servicio.pagado = 0;
      }
    } else {
      servicio.gastoId = await GastoRepository().addGasto(Gasto(
        servicio.titulo,
        servicio.monto,
        'Servicios',
        _fechaDelMes(),
        0,
        0,
        0,
      ));
      if (_esMesEnCurso) {
        servicio.pagado = 1;
      }
    }
    await ServicioHogarRepository().updateServicio(servicio);
    _recargar();
    _avisarCambio();
  }

  // Elimina un servicio despues de confirmar.
  Future<void> _eliminar(ServicioHogar servicio) async {
    final bool? confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar servicio'),
        content: Text('¿Querés eliminar "${servicio.titulo}"?'),
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
    if (confirmado == true) {
      // Si estaba pagado, su gasto asociado se elimina tambien.
      if (servicio.gastoId > 0) {
        await GastoRepository().deleteGasto(servicio.gastoId);
      }
      await ServicioHogarRepository().deleteServicio(servicio.id!);
      _recargar();
      _avisarCambio();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.col.fondo,
      appBar: AppBar(
        title: const Text(
          'Gastos del Mes',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: context.col.superficie,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            tooltip: 'Elegir mes',
            onPressed: _elegirMes,
          ),
        ],
      ),
      body: FutureBuilder<_DatosMes>(
        future: _datosFuture,
        builder: (context, snapshot) {
          final _DatosMes datos = snapshot.data ??
              const _DatosMes(<Gasto>[], <Ingreso>[], <ServicioHogar>[]);
          return _buildContenido(datos);
        },
      ),
    );
  }

  Widget _buildContenido(_DatosMes datos) {
    final List<Gasto> gastosMes = gastosDelMes(datos.gastos, _currentMonth);
    final double totalGastado = totalGastos(gastosMes);
    final double totalIngresado =
        totalIngresos(ingresosDelMes(datos.ingresos, _currentMonth));
    final double balance = totalIngresado - totalGastado;
    final List<MapEntry<String, double>> categorias = categoriasOrdenadas(gastosMes);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Selector de mes interactivo
          _buildMonthSelector(),
          const SizedBox(height: 16),

          // Tarjeta de resumen del periodo (valores reales)
          _buildTotalCard(totalGastado, totalIngresado, balance),
          const SizedBox(height: 24),

          // Desglose por categoria calculado desde SQLite
          const Text(
            'Desglose por Categoría',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          if (categorias.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Sin gastos en este período.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            )
          else
            for (int i = 0; i < categorias.length; i++)
              _buildCategoryItem(
                icon: _iconoDe(categorias[i].key),
                color: _colores[i % _colores.length],
                name: categorias[i].key,
                amount: formatearMoneda(categorias[i].value),
                percentage: porcentaje(categorias[i].value, totalGastado),
              ),

          // Servicios del hogar: la lista completa, con el estado del mes
          // elegido arriba (resumen) y en cada item.
          _buildServicios(datos),
        ],
      ),
    );
  }

  // Seccion de servicios del hogar dentro del reporte del mes.
  Widget _buildServicios(_DatosMes datos) {
    final List<ServicioHogar> servicios = datos.servicios;
    double total = 0;
    double pagado = 0;
    for (final ServicioHogar servicio in servicios) {
      total += servicio.monto;
      if (_gastoDelMes(servicio, datos.gastos, _currentMonth) != null) {
        pagado += servicio.monto;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                'Servicios del hogar',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.group_add_outlined, size: 22),
              tooltip: 'Nuevo servicio',
              onPressed: _nuevoServicio,
            ),
          ],
        ),
        const SizedBox(height: 4),

        // Resumen del mes elegido: cuanto se pago y cuanto sigue pendiente.
        Row(
          children: [
            Expanded(child: _datoServicio('Total', formatearMoneda(total), Colors.blue)),
            Expanded(
                child: _datoServicio('Pagado', formatearMoneda(pagado), Colors.green)),
            Expanded(
                child:
                    _datoServicio('Pendiente', formatearMoneda(total - pagado), Colors.orange)),
          ],
        ),
        const SizedBox(height: 12),

        if (servicios.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Aún no hay servicios cargados. Agregá uno con el botón de arriba.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          )
        else
          ...servicios.map(
            (ServicioHogar servicio) => _buildServiceItem(servicio, datos),
          ),
      ],
    );
  }

  // Dato chico del resumen de servicios (etiqueta y monto).
  Widget _datoServicio(String etiqueta, String monto, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(etiqueta,
            style: TextStyle(fontSize: 12, color: context.col.subtexto)),
        const SizedBox(height: 2),
        Text(
          monto,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color),
        ),
      ],
    );
  }

  // Item de servicio: al tocar el icono se marca/desmarca como pagado en el
  // mes que se esta viendo; al tocar la fila se abre su edicion.
  Widget _buildServiceItem(ServicioHogar servicio, _DatosMes datos) {
    final bool pagado =
        _gastoDelMes(servicio, datos.gastos, _currentMonth) != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.col.superficie,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _editarServicio(servicio),
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: Icon(
                pagado ? Icons.check_circle : Icons.schedule,
                color: pagado ? Colors.green : Colors.orange,
                size: 24,
              ),
              tooltip: pagado ? 'Marcar como pendiente' : 'Marcar como pagado',
              onPressed: () => _alternarPagado(servicio),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    servicio.titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Text(
                    servicio.detalle.isEmpty
                        ? (pagado ? 'Pagado' : 'Pendiente')
                        : servicio.detalle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: context.col.subtexto, fontSize: 12),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  formatearMoneda(servicio.monto),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Acciones del servicio',
              onSelected: (valor) {
                if (valor == 'editar') {
                  _editarServicio(servicio);
                } else if (valor == 'eliminar') {
                  _eliminar(servicio);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'editar', child: Text('Editar')),
                PopupMenuItem(value: 'eliminar', child: Text('Eliminar')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Widget selector de mes (flechas izquierda/derecha)
  Widget _buildMonthSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: context.col.superficie,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 16),
            tooltip: 'Mes anterior',
            onPressed: () => _changeMonth(-1),
          ),
          Expanded(
            child: Text(
              etiquetaMes(_currentMonth),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios, size: 16),
            tooltip: 'Mes siguiente',
            onPressed: () => _changeMonth(1),
          ),
        ],
      ),
    );
  }

  // Tarjeta resumen con gastado, ingresado y balance del periodo.
  Widget _buildTotalCard(double totalGastado, double totalIngresado, double balance) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Total Gastado en el Período',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            formatearMoneda(totalGastado),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Ingresos: ${formatearMoneda(totalIngresado)}',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            'Balance: ${formatearMoneda(balance)}',
            style: TextStyle(
              color: balance >= 0 ? Colors.greenAccent : Colors.redAccent,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // Ítem de categoría con barra de progreso.
  Widget _buildCategoryItem({
    required IconData icon,
    required Color color,
    required String name,
    required String amount,
    required double percentage,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.col.superficie,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.12),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
              Expanded(
                flex: 2,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    amount,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: percentage,
              minHeight: 6,
              backgroundColor: context.col.pista,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${(percentage * 100).round()}%',
              style: const TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  // Icono representativo para cada categoria de gasto.
  IconData _iconoDe(String categoria) {
    switch (categoria) {
      case 'Servicios':
        return Icons.home_outlined;
      case 'Comida':
        return Icons.local_dining_outlined;
      case 'Transporte':
        return Icons.directions_car_outlined;
      case 'Entretenimiento':
        return Icons.movie_outlined;
      case 'Salud':
        return Icons.favorite_outline;
      case 'Educacion':
        return Icons.school_outlined;
      case 'Otros':
        return Icons.category_outlined;
      default:
        return Icons.shopping_bag_outlined;
    }
  }
}

// Formulario de alta y edicion de servicios y gastos fijos del hogar.
class _DialogoNuevoServicio extends StatefulWidget {
  // Servicio a editar. Null -> modo alta.
  final ServicioHogar? servicio;

  const _DialogoNuevoServicio({this.servicio});

  @override
  State<_DialogoNuevoServicio> createState() => _DialogoNuevoServicioState();
}

class _DialogoNuevoServicioState extends State<_DialogoNuevoServicio> {
  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();
  final _detalleController = TextEditingController();
  final _montoController = TextEditingController();

  bool get _esEdicion => widget.servicio != null;

  @override
  void initState() {
    super.initState();
    final ServicioHogar? servicio = widget.servicio;
    if (servicio != null) {
      _tituloController.text = servicio.titulo;
      _detalleController.text = servicio.detalle;
      _montoController.text = servicio.monto.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _detalleController.dispose();
    _montoController.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final double monto =
        double.tryParse(_montoController.text.replaceAll(',', '.')) ?? 0;
    // En modo edicion se conservan el id, el estado pagado/pendiente y el
    // gasto asociado: solo se modifican titulo, detalle y monto.
    final ServicioHogar servicio = ServicioHogar(
      _tituloController.text.trim(),
      _detalleController.text.trim(),
      monto,
      widget.servicio?.pagado ?? 0,
      widget.servicio?.id,
      widget.servicio?.gastoId ?? 0,
    );
    if (_esEdicion) {
      await ServicioHogarRepository().updateServicio(servicio);
      // Si el servicio ya estaba pagado, el gasto que representa ese pago
      // se actualiza para que no quede desincronizado.
      if (servicio.pagado == 1 && servicio.gastoId > 0) {
        final Gasto? gasto = await GastoRepository().getGasto(servicio.gastoId);
        if (gasto != null) {
          gasto.concepto = servicio.titulo;
          gasto.monto = servicio.monto;
          await GastoRepository().updateGasto(gasto);
        }
      }
    } else {
      await ServicioHogarRepository().addServicio(servicio);
    }
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_esEdicion ? 'Editar servicio' : 'Nuevo servicio'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _tituloController,
                decoration: const InputDecoration(
                  labelText: 'Título',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Ingresá un título'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _detalleController,
                decoration: const InputDecoration(
                  labelText: 'Detalle (opcional)',
                  border: OutlineInputBorder(),
                ),
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
                    return 'Ingresá un monto valido';
                  }
                  return null;
                },
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
