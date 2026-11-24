// Tema visual de FinanzApp: paleta clara y oscura, y el control que recuerda
// la eleccion del usuario.
//
// La paleta es semantica (fondo, superficie, textos...), no literal. En modo
// claro devuelve EXACTAMENTE los colores que ya usaba la app, asi activar el
// modo oscuro no cambia nada cuando esta apagado.

import 'package:flutter/material.dart';

import '../data/dbhelper.dart';

@immutable
class AppColores extends ThemeExtension<AppColores> {
  final Color fondo; // Fondo general de las pantallas.
  final Color superficie; // Tarjetas, barras y hojas.
  final Color superficie2; // Superficie secundaria (chips, rellenos suaves).
  final Color titulo; // Titulos y encabezados de marca.
  final Color texto; // Texto principal.
  final Color subtexto; // Texto secundario (fechas, ayudas).
  final Color sutil; // Texto muy tenue (placeholder, notas).
  final Color gris; // Texto gris neutro.
  final Color pista; // Fondo de barras de progreso.
  final Color borde; // Bordes y separadores.

  const AppColores({
    required this.fondo,
    required this.superficie,
    required this.superficie2,
    required this.titulo,
    required this.texto,
    required this.subtexto,
    required this.sutil,
    required this.gris,
    required this.pista,
    required this.borde,
  });

  // Valores del modo claro: los mismos que tenia la app antes del tema.
  static const AppColores claro = AppColores(
    fondo: Color(0xFFF6F8FC),
    superficie: Color(0xFFFFFFFF),
    superficie2: Color(0xFFF3F5F9),
    titulo: Color(0xFF1E3C72),
    texto: Color(0xFF1A1C1E),
    subtexto: Color(0x8A000000), // Colors.black54
    sutil: Color(0x61000000), // Colors.black38
    gris: Color(0xFF9E9E9E), // Colors.grey
    pista: Color(0xFFEEEEEE), // Colors.grey.shade200
    borde: Color(0x1F000000), // Colors.black12
  );

  // Valores del modo oscuro: mismos roles sobre fondo oscuro.
  static const AppColores oscuro = AppColores(
    fondo: Color(0xFF11141C),
    superficie: Color(0xFF1C2029),
    superficie2: Color(0xFF242A34),
    titulo: Color(0xFFE7ECF7),
    texto: Color(0xFFECEDEF),
    subtexto: Color(0xFFB0B7C3),
    sutil: Color(0xFF8B919E),
    gris: Color(0xFF9AA0AC),
    pista: Color(0xFF3A404B),
    borde: Color(0xFF343A45),
  );

  @override
  AppColores copyWith({
    Color? fondo,
    Color? superficie,
    Color? superficie2,
    Color? titulo,
    Color? texto,
    Color? subtexto,
    Color? sutil,
    Color? gris,
    Color? pista,
    Color? borde,
  }) {
    return AppColores(
      fondo: fondo ?? this.fondo,
      superficie: superficie ?? this.superficie,
      superficie2: superficie2 ?? this.superficie2,
      titulo: titulo ?? this.titulo,
      texto: texto ?? this.texto,
      subtexto: subtexto ?? this.subtexto,
      sutil: sutil ?? this.sutil,
      gris: gris ?? this.gris,
      pista: pista ?? this.pista,
      borde: borde ?? this.borde,
    );
  }

  @override
  AppColores lerp(ThemeExtension<AppColores>? other, double t) {
    if (other is! AppColores) {
      return this;
    }
    return AppColores(
      fondo: Color.lerp(fondo, other.fondo, t)!,
      superficie: Color.lerp(superficie, other.superficie, t)!,
      superficie2: Color.lerp(superficie2, other.superficie2, t)!,
      titulo: Color.lerp(titulo, other.titulo, t)!,
      texto: Color.lerp(texto, other.texto, t)!,
      subtexto: Color.lerp(subtexto, other.subtexto, t)!,
      sutil: Color.lerp(sutil, other.sutil, t)!,
      gris: Color.lerp(gris, other.gris, t)!,
      pista: Color.lerp(pista, other.pista, t)!,
      borde: Color.lerp(borde, other.borde, t)!,
    );
  }
}

/// Acceso a la paleta actual desde cualquier `BuildContext`.
extension ColoresContext on BuildContext {
  AppColores get col =>
      Theme.of(this).extension<AppColores>() ?? AppColores.claro;
}

ThemeData _temaBase(AppColores c, Brightness brillo) {
  // Se parte del esquema por defecto de Material 3 (el que ya usaba la app)
  // para no cambiar los acentos, y solo se ajustan las superficies.
  final ColorScheme esquema = ThemeData(
    useMaterial3: true,
    brightness: brillo,
  ).colorScheme.copyWith(
        surface: c.superficie,
        onSurface: c.texto,
        outlineVariant: c.borde,
      );
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Roboto',
    brightness: brillo,
    colorScheme: esquema,
    scaffoldBackgroundColor: c.fondo,
    canvasColor: c.fondo,
    dividerColor: c.borde,
    extensions: <ThemeExtension<dynamic>>[c],
    appBarTheme: AppBarTheme(
      backgroundColor: c.superficie,
      foregroundColor: c.titulo,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.superficie,
      surfaceTintColor: Colors.transparent,
    ),
    popupMenuTheme: PopupMenuThemeData(color: c.superficie),
    snackBarTheme: SnackBarThemeData(backgroundColor: c.superficie2),
  );
}

ThemeData temaClaro() => _temaBase(AppColores.claro, Brightness.light);

ThemeData temaOscuro() => _temaBase(AppColores.oscuro, Brightness.dark);

/// Estado del modo oscuro en toda la aplicacion.
///
/// Es un `ChangeNotifier` unico: la app escucha y reconstruye el `MaterialApp`
/// cuando cambia. La eleccion se guarda en disco para recordarla al reiniciar.
class TemaControl extends ChangeNotifier {
  static final TemaControl instancia = TemaControl._();

  TemaControl._();

  ThemeMode _modo = ThemeMode.light;

  ThemeMode get modo => _modo;

  bool get oscuro => _modo == ThemeMode.dark;

  /// Lee la preferencia guardada. Si no hay, queda en claro.
  Future<void> cargar() async {
    final bool guardado = await DbHelper().temaOscuroGuardado();
    _modo = guardado ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  /// Enciende o apaga el modo oscuro y lo persiste.
  Future<void> alternar() async {
    _modo = oscuro ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
    await DbHelper().guardarTemaOscuro(oscuro);
  }
}
