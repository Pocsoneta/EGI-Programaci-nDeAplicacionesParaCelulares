import 'package:flutter/material.dart';

import '../data/grupo_repository.dart';
import '../model/model.dart';
import '../util/utils.dart';
import 'crear_grupo_screen.dart';
import 'grupo_detalle_screen.dart';

// Lista de grupos. Cada tarjeta muestra tu saldo en el grupo: cuanto te deben,
// cuanto debés, o si ya está saldado.
class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  static const Color _azul = Color(0xFF4C68FF);
  static const Color _azulOscuro = Color(0xFF1E3C72);

  late Future<List<DatosGrupo>> _gruposFuture;

  @override
  void initState() {
    super.initState();
    _gruposFuture = _cargarGrupos();
  }

  @override
  void didUpdateWidget(covariant GroupsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _gruposFuture = _cargarGrupos();
  }

  Future<List<DatosGrupo>> _cargarGrupos() async {
    final List<Grupo> grupos = await GrupoRepository().getGrupos();
    final List<DatosGrupo> datos = <DatosGrupo>[];
    for (final Grupo grupo in grupos) {
      datos.add(await GrupoRepository().cargarGrupo(grupo));
    }
    return datos;
  }

  void _recargar() {
    final Future<List<DatosGrupo>> futuro = _cargarGrupos();
    setState(() {
      _gruposFuture = futuro;
    });
  }

  Future<void> _nuevoGrupo() async {
    final bool? creado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (context) => const CrearGrupoScreen()),
    );
    if (creado == true && mounted) {
      _recargar();
    }
  }

  Future<void> _abrirGrupo(Grupo grupo) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => GrupoDetalleScreen(grupo: grupo)),
    );
    if (mounted) {
      _recargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        title: const Text(
          'Grupos',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add_outlined, color: _azul),
            tooltip: 'Nuevo grupo',
            onPressed: _nuevoGrupo,
          ),
        ],
      ),
      body: FutureBuilder<List<DatosGrupo>>(
        future: _gruposFuture,
        builder: (context, snapshot) {
          final List<DatosGrupo> grupos = snapshot.data ?? <DatosGrupo>[];
          if (grupos.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Aún no tenés grupos. Creá uno con el botón de arriba.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54),
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: grupos.map(_buildTarjeta).toList(),
          );
        },
      ),
    );
  }

  Widget _buildTarjeta(DatosGrupo datos) {
    final double saldo = datos.miSaldo;
    final Color color = saldo > 0.005
        ? Colors.green
        : saldo < -0.005
            ? Colors.redAccent
            : Colors.grey;
    final String estado = saldo > 0.005
        ? 'Te deben'
        : saldo < -0.005
            ? 'Debés'
            : 'Saldado';
    final String monto = saldo.abs() < 0.005 ? '' : formatearMonedaExacta(saldo.abs());
    final int cantidad = datos.participantes.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _abrirGrupo(datos.grupo),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: _azul.withAlpha(25),
                child: Text(datos.grupo.emoji, style: const TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      datos.grupo.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: _azulOscuro,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$cantidad participantes · ${datos.gastos.length} gastos',
                      style: const TextStyle(color: Colors.black45, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(estado, style: const TextStyle(color: Colors.black45, fontSize: 11)),
                  if (monto.isNotEmpty)
                    Text(
                      monto,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
