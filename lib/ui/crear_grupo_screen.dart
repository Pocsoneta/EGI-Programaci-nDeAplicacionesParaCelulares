import 'package:flutter/material.dart';

import '../data/dbhelper.dart';
import '../data/grupo_repository.dart';
import '../data/usuario_repository.dart';
import '../model/model.dart';
import '../util/tema.dart';

// Alta de un grupo: título con emoji y los participantes. Tu nombre va primero
// y queda marcado como "Personal". Los demás son solo nombres.
class CrearGrupoScreen extends StatefulWidget {
  const CrearGrupoScreen({super.key});

  @override
  State<CrearGrupoScreen> createState() => _CrearGrupoScreenState();
}

class _CrearGrupoScreenState extends State<CrearGrupoScreen> {
  static const Color _azul = Color(0xFF4C68FF);
  static const List<String> _emojis = <String>[
    '🧾', '🏝️', '🍖', '⚽', '✈️', '🎉', '🏠', '🍕', '🎮', '🚗',
  ];

  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();
  final List<TextEditingController> _nombres = <TextEditingController>[
    TextEditingController(),
  ];
  String _emoji = _emojis.first;
  String _miNombre = '';
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargarMiNombre();
  }

  Future<void> _cargarMiNombre() async {
    final int? id = DbHelper().currentUserId;
    final usuario = id == null ? null : await UsuarioRepository().getUsuario(id);
    if (mounted) {
      setState(() => _miNombre = usuario?.nombre ?? 'Yo');
    }
  }

  @override
  void dispose() {
    _tituloController.dispose();
    for (final TextEditingController c in _nombres) {
      c.dispose();
    }
    super.dispose();
  }

  void _agregarParticipante() {
    setState(() => _nombres.add(TextEditingController()));
  }

  void _quitarParticipante(int indice) {
    setState(() {
      _nombres[indice].dispose();
      _nombres.removeAt(indice);
    });
  }

  Future<void> _crear() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final List<String> otros = _nombres
        .map((TextEditingController c) => c.text.trim())
        .where((String n) => n.isNotEmpty)
        .toList();
    if (otros.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agregá al menos otro participante')),
      );
      return;
    }
    setState(() => _guardando = true);
    final Grupo grupo = Grupo(_tituloController.text.trim(), _emoji);
    final List<Participante> participantes = <Participante>[
      Participante(0, _miNombre, true),
      ...otros.map((String nombre) => Participante(0, nombre, false)),
    ];
    await GrupoRepository().crearGrupo(grupo, participantes);
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.col.fondo,
      appBar: AppBar(
        title: const Text('Nuevo grupo', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: context.col.superficie,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Título', style: TextStyle(fontWeight: FontWeight.bold, color: context.col.titulo)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _tituloController,
                    decoration: InputDecoration(
                      hintText: 'Por ejemplo, Viaje a la costa',
                      filled: true,
                      fillColor: context.col.superficie,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (value) => (value == null || value.trim().isEmpty)
                        ? 'Ingresá un título'
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _emojis
                  .map((String emoji) => ChoiceChip(
                        label: Text(emoji, style: const TextStyle(fontSize: 18)),
                        selected: _emoji == emoji,
                        selectedColor: _azul.withAlpha(40),
                        onSelected: (_) => setState(() => _emoji = emoji),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 24),
            Text('Participantes',
                style: TextStyle(fontWeight: FontWeight.bold, color: context.col.titulo)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.col.superficie,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _miNombre.isEmpty ? 'Vos' : _miNombre,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _azul,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Personal',
                            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  for (int i = 0; i < _nombres.length; i++)
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _nombres[i],
                            decoration: const InputDecoration(
                              hintText: 'Nombre del participante',
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        if (_nombres.length > 1)
                          IconButton(
                            icon: Icon(Icons.cancel_outlined, color: context.col.sutil),
                            tooltip: 'Quitar participante',
                            onPressed: () => _quitarParticipante(i),
                          ),
                      ],
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _agregarParticipante,
                      icon: const Icon(Icons.person_add_alt_outlined),
                      label: const Text('Añadir otro participante'),
                    ),
                  ),
                ],
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
              onPressed: _guardando ? null : _crear,
              child: const Text('Crear grupo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
