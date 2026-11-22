# Changelog

Registro de los cambios funcionales de FinanzApp y de los errores que
aparecieron durante su desarrollo, con su causa y cómo se resolvieron.

Estado al cierre de este registro: `flutter analyze` sin issues y
**36 tests en verde** (`flutter test`).

---

## [Grupos estilo Tricount] — 2026-11-17

Rediseño grande de la sección Grupo, inspirado en Tricount. Decisiones tomadas
con el usuario: deudas calculadas desde los gastos (se elimina la carga manual),
en el Saldo total cuenta solo tu parte, se quita la invitación (no hay
servidor), los grupos anteriores se borran y la división admite partes iguales
o montos exactos con centavos.

### Modelo y base de datos (versión 2)

- Entidades nuevas en `lib/model/model.dart`: `Grupo` (nombre y emoji),
  `Participante` (`esYo`), `GastoGrupo` (título, monto, quién pagó, fecha y
  `movimientoId`), `ParteGasto` (cuánto le toca a cada uno) y `PagoGrupo`
  (reembolso registrado).
- Tablas nuevas: `grupos`, `grupo_participantes`, `grupo_gastos`,
  `grupo_gasto_partes`, `grupo_pagos`. Se elimina `grupo_miembros`.
- La base de cada usuario pasa a **versión 2**. `_migrarGrupos` borra los grupos
  del modelo anterior una sola vez, al actualizar (`onUpgrade`). En bases nuevas
  o sin versión también se ejecuta en `onCreate`.
- `DbHelper.eliminarDonde` para borrados por condición.

### Cálculos (`lib/util/grupo_calculos.dart`)

- `saldosNetosEnCentavos`: lo pagado menos lo que toca, más reembolsos.
- `calcularReembolsos`: empareja deudores con acreedores hasta dejar todo en cero.
- `dividirIgual`: reparto en centavos exactos (la suma siempre es el total).
- `formatearMonedaExacta` (utils): `$33.333,33`.

### Saldo total

- Al guardar un gasto compartido, tu parte se registra como gasto personal
  (categoría General, concepto `Grupo: título`). Si el gasto no te toca, no se
  registra nada.
- Los reembolsos **no crean movimientos**. La parte propia ya quedó registrada al
  crear el gasto, así que registrar un pago no la contaría dos veces.
- Al editar o eliminar un gasto compartido se reemplaza o quita su movimiento.
  Al eliminar un grupo se quitan todos sus movimientos.

### Pantallas

- `groups_screen.dart`: lista con emoji, participantes, cantidad de gastos y tu
  saldo (Te deben / Debés / Saldado).
- `crear_grupo_screen.dart`: título, emoji y participantes (vos quedás como
  "Personal").
- `grupo_detalle_screen.dart`: pestañas Gastos y Saldos, botón Añadir gasto,
  añadir participante, eliminar grupo.
- `anadir_gasto_grupo_screen.dart`: alta y edición con pagó, fecha, división
  igual o exacta.
- `reembolsos_screen.dart`: reembolsos pendientes, *Solicitar* (copia el mensaje
  de cobro) y *¡Está pagado!*, más la lista de pagos registrados con opción de
  quitar.

### Correcciones tras probar en PC

- **Crash al eliminar un grupo**: la barra inferior usaba una muesca
  (`CircularNotchedRectangle`). Su recorte consulta la geometría del `Scaffold`
  durante el hit-test, y eso falla cuando la pantalla cambia (por ejemplo al
  volver de eliminar un grupo). Se quitó la muesca: el "+" sigue centrado, sin
  recorte. Nota: el test no lograba reproducir el crash con toques simulados;
  la corrección elimina la causa conocida, pero conviene volver a probarlo.
- **Desborde en el formulario de gasto (pantallas angostas)**: "Pagado por" y
  "Cuándo" pasaron a ir uno debajo del otro, y el selector "Dividir" ocupa el
  ancho completo. Test en `test/grupos_test.dart`.

### Quién debe a quién

- **Reembolsos** separados en *Te deben*, *Tenés que pagar* y *Otros pagos del
  grupo*. Tu nombre aparece como "(yo)" en todas las pantallas del grupo.
- **Saldos**: cada persona se despliega y muestra sus deudas: "X te debe $Y" o
  "Le debés $Y a X" para vos, y "X le debe $Y a Z" para los demás.
- `DatosGrupo.nombreSimple` para las frases sin la marca "(yo)".
- Test en `test/grupos_test.dart` (despliegue de Saldos).

### Varias personas pueden pagar el mismo gasto

- **"Quién puso plata"** en el formulario del gasto: en vez de un único
  "Pagado por", ahora cada participante tiene un casillero y su monto. Un gasto
  puede tener uno o varios que pusieron plata; la suma debe ser el total del
  gasto (se muestra "Suma $X de $Y", en rojo si no cuadra).
- Los montos que se escriben a mano no se recalculan solos; los que no se
  tocaron se reparten en lo que falta del total.
- Tabla nueva `grupo_gasto_aportes` (base versión 3). Los gastos de las bases
  de la versión 2 pasan a tener un solo aporte, el que pagaba, por el total.
- **Saldos**: cada aporte se acredita a quien lo puso, así dos personas pueden
  haber pagado partes distintas del mismo gasto.
- **Ficha del gasto**: muestra "Pagó X" si puso una persona o "Pusieron X e Y"
  si pusieron varias.
- Tests: `test/grupos_test.dart` (cálculo con dos aportes, guardado con dos
  aportes, migración v2→v3 y la pantalla). 64 tests en verde.

### Ajuste de un diseño anterior

- El test de Grupo ya no busca "Sin actividad para mostrar.", que era un resumen
  del diseño anterior.

### Errores y decisiones a revisar

- **Corrección de la propuesta**: en el plan se había dicho que cada reembolso
  registraría un gasto o un ingreso. Eso habría contado dos veces la parte
  propia (el gasto ya se registró al crear el gasto), así que se descartó.
- Los gastos personales que creó el modelo anterior (por ejemplo `Pago a Juan`)
  no se borran: son movimientos que ya ocurrieron. Pueden verse en Gastos.
- Un reembolso que se registró por error se quita desde *Pagos registrados*.
- Quedan fuera: invitar participantes, QR, reembolsos parciales y cambiar la
  moneda por grupo.

### Tests

- 64 tests en verde. Nuevos: `test/grupos_test.dart` (cálculos, Saldo total,
  migración de la base vieja y un flujo completo por pantalla).
- Se quitaron los tests del modelo anterior de `test/mejoras_test.dart`.

---

## [Ajustes de testeo] — 2026-11-10

Cambios pedidos por los compañeros que probaron la app.

### Inicio y botón "+"

- Se eliminaron los botones sueltos **"Agregar ingreso"** y **"Hogar"** de la
  pantalla de Inicio.
- El botón **+** de la barra inferior abre ahora un menú (hoja inferior) con
  tres opciones: **Nuevo gasto**, **Nuevo ingreso** y **Servicios del hogar**.
- El diálogo de ingreso pasó a `lib/ui/dialogo_ingreso.dart` (`DialogoIngreso`),
  porque lo usan Inicio (editar ingreso) y el menú (nuevo ingreso).
- Al cargar un ingreso desde el menú o volver de Servicios del hogar, las
  vistas se recargan y se actualiza la cabecera.

### Tests

- 36 tests en verde. Los pasos que usaban los botones sueltos ahora usan el
  menú del "+".

### Ahorro: cuánto ahorrar (reemplaza el consejo fijo)

- Se eliminó el tip estático "Aportando $15.000 por semana...".
- La tarjeta **"Cuánto ahorrar"** calcula para cada meta, con su importe y su
  fecha objetivo: lo que falta, cuánto ahorrar **por semana** y **por mes**.
  Los periodos se redondean hacia arriba.
- Estados: en curso (muestra el plan), completada ("Meta completa") y vencida
  (la fecha ya pasó, se pide editar la meta).
- Lógica pura en `lib/util/utils.dart` (`calcularPlanAhorro`, `PlanAhorro`,
  `EstadoPlanAhorro`). Tests en `test/plan_ahorro_test.dart` (6 casos).

### Ahorro: una sola forma de crear una meta

- Se quitó el ícono de "Nueva meta" de la barra superior. Queda el botón
  "Nueva meta" de la lista de metas, que dice qué hace.

### Registro: enlace a iniciar sesión

- Nuevo enlace "¿Ya tenés una cuenta? Iniciá sesión" en la pantalla de
  creación de cuenta. Abre el login y, si entra, la cuenta queda activa.
  (`lib/ui/usuario_screen.dart`, test en `test/auth_enlaces_test.dart`).

### Formato de montos

- `formatearMoneda` separa los miles con punto y no muestra decimales:
  `$1500` pasa a `$1.500`, `-$20000` a `-$20.000`. Se usa en todas las
  pantallas y en el mensaje de "Gasto agregado".
- Los campos de edición siguen mostrando el número sin separadores, porque
  al guardar se leen de vuelta (con "1.500" se leería 1,5).
- Los tests que esperaban montos sin separador se actualizaron.

### Recuperación de contraseña (código de recuperación)

- **Código de recuperación** de 10 caracteres (`XXXXX-XXXXX`, sin 0/O/1/I),
  aleatorio (`Random.secure`). Se guarda solo su hash (`lib/data/codigo_recuperacion.dart`),
  con el mismo esquema que las contraseñas y un prefijo propio.
- **Alta de cuenta**: al crearla se muestra el código en un diálogo que se
  cierra solo con "Ya lo guardé" (botón "Copiar código" incluido).
- **Cuentas existentes**: no fueron borradas. El código se genera desde
  **Mi perfil** ("Generar código") y se muestra una sola vez. Si ya tiene uno,
  el perfil solo permite "Generar nuevo código" (pide confirmación y el
  anterior deja de servir).
- **"Olvidé mi contraseña"** en el login: pantalla con correo, código y nueva
  contraseña. El mensaje de error es el mismo para correo, código o cuenta
  incorrectos, para no revelar qué cuentas existen.
- El código es **de uso único**: al usarlo se borra y la cuenta queda sin
  código hasta generar uno nuevo desde el perfil.
- Columna nueva `usuarios.codigoRecuperacion` (migración automática en
  `DbHelper._crearTablaUsuarios`).
- Tests: `test/codigo_recuperacion_test.dart` (lógica) y
  `test/recuperacion_test.dart` (flujo contra la base). `test/codigo_test_helper.dart`
  cierra el diálogo del código en los tests que crean cuentas.

### Login: enlace a registro

- Nuevo enlace "¿No tenés una cuenta? Registrate" en iniciar sesión. Abre el
  registro y, si se crea la cuenta, queda activa (mismo criterio que el enlace
  inverso del registro). Test en `test/auth_enlaces_test.dart`.

### Tests

- 51 tests en verde.

---

## [Diseño de inicio] — 2026-11-05

### Introducción (primera vez que se abre la app)

- Pantalla nueva `lib/ui/onboarding_screen.dart` con **3 diapositivas**:
  bienvenida, "Todo conectado a tu saldo" y "Grupos y metas". Cada una tiene
  una ilustración hecha con íconos sobre un degradado azul.
- Botones **Omitir**, **Siguiente** y **Comenzar**, con indicadores de página.
- Se muestra **solo la primera vez**: el marcador se guarda en
  `finanzapp_introduccion.txt` (`DbHelper.introduccionVista` /
  `marcarIntroduccionVista`), igual que la sesión.
- Si hay sesión guardada, la app entra directo y no muestra la introducción.

### Login y registro

- Encabezado compartido con degradado azul (`CabeceraAuth`) y tarjeta blanca
  para los campos (`lib/ui/auth_widgets.dart`).
- Íconos en los campos y botón para **mostrar u ocultar la contraseña**.
- Textos con tildes: "Iniciar sesión", "Contraseña", "Ingresá",
  "Credenciales inválidas".
- La lógica no cambió: mismos validadores, mismo orden de campos y mismos
  botones.

### Cabecera y barra inferior

- Cabecera: título "FinanzApp" con el mes, campana con punto rojo cuando
  hay alertas, y **avatar con la inicial** de la cuenta activa (abre el perfil).
- "Crear cuenta" e "Iniciar sesión" salieron del header y pasaron al
  **perfil**, en la sección "Cuentas".
- Barra inferior con `BottomAppBar` y el botón **"+" centrado**. Quedan
  **4 accesos** (Inicio, Mes, Grupo, Ahorro), 2 a cada lado.
- **Hogar salió de la barra**: ahora es un botón **"Hogar"** en Inicio, en la
  misma fila que "Agregar ingreso". Abre la pantalla de servicios como
  pantalla propia y, al volver, recarga Inicio y la cabecera.

### Pantallas angostas

- Las filas que antes tenían ancho fijo ahora se adaptan (`Expanded`,
  `Flexible`, `FittedBox`, texto con `maxLines`/`ellipsis`) en Inicio, Mes,
  Ahorro, Hogar y la barra inferior.
- Test nuevo `test/pantalla_chica_test.dart`: recorre las secciones con un
  celular de 320×568 y falla si aparece un desborde.

### Tests

- 36 tests en verde. Nuevos: `introduccion_test.dart` (la introducción se
  muestra una sola vez) y `pantalla_chica_test.dart`.
- Los tests que abren la app marcan la introducción como vista.
- Los pasos que usaban los íconos del header ahora abren "Mi perfil" primero.

---

## Errores encontrados en este bloque

| Error | Causa | Solución |
|---|---|---|
| Tests de "Notificaciones" no encontraban la campana | Se cambió el ícono a `notifications_none_rounded` y los tests buscan `notifications_none` | Se volvió al ícono original |
| Inicio no mostraba "Aun no hay gastos registrados." | `BottomAppBar` de Material 3 mide **80 px** por defecto; la barra anterior medía 56 px, así que el contenido quedaba debajo del borde visible | Altura fijada en 60 px |
| Test de perfil no encontraba el avatar | Se tocaba el emoji 😊, que ya no existe (el avatar muestra la inicial) | Los tests usan `find.byTooltip('Mi perfil')` |
| El "+" se montaba sobre "Hogar" | Los 5 accesos eran columnas iguales con el hueco al centro; 2 a la izquierda y 3 a la derecha corrían el hueco | Dos mitades iguales y hueco central de 80 px |
| Desborde "RenderFlex overflowed" al achicar la ventana | Las etiquetas de la barra se partían en dos líneas y la columna superaba la altura | Etiquetas con `maxLines: 1` |
| Botón "Hogar" fuera de la vista en Inicio | Al agregar el botón, la lista de Inicio creció y el texto de gastos quedó debajo | Botón en la misma fila que "Agregar ingreso" |
| Test de Metas fallaba al tocar "Ahorro" | Un cierre de la pantalla de Hogar quedó al inicio del test de Metas (no al final del de servicios) | Se movió al final del test que corresponde |
| Test de pantalla chica: `Scaffold.geometryOf()` | Toque sobre un `BottomAppBar` con muesca antes de que la pantalla se pintara | Frames extra antes de tocar la barra |
| Desbordes en Inicio, Mes, Ahorro y Hogar | Filas con ancho fijo: título + botón, indicadores de 3 columnas, nombre del mes | Widgets que se adaptan al ancho (ver "Pantallas angostas") |
| Test de pantalla chica: "Hogar" no encontrado | Inicio es una lista perezosa: el botón queda fuera del área construida | `scrollUntilVisible` antes de tocar |

**Observación sobre los tests:** `flutter test` mide el texto con una fuente de
prueba más ancha que Roboto, así que el test de pantalla chica es más estricto
que un celular real. No se cargó una fuente del sistema para no depender de
la máquina.

---

## [Sin versión] — Rama `v2-arquitectura`

### Seguridad

- Contraseñas hasheadas con **SHA-256 + sal derivada del email**
  (`lib/data/contrasena.dart`); nunca se guardan en texto plano.
- **Sesión persistente** en `finanzapp_sesion.txt`: la app recuerda al
  usuario entre ejecuciones y ofrece cierre de sesión desde el perfil.
- Validaciones de registro y edición de perfil (email único, campos
  obligatorios, confirmación de contraseña).

### Notificaciones

- Utilidad `lib/util/notificaciones.dart`: genera avisos de **servicios
  del hogar pendientes/vencidos** y de **metas de ahorro** próximas a su
  fecha objetivo.
- Pantalla de notificaciones conectada a esa utilidad (no es mock).

### Todo conectado al saldo del inicio

- **Tarjeta "Saldo total"** en Inicio (`saldoTotal` en
  `lib/util/utils.dart`): ingresos − gastos − plata depositada en ahorros.
- **Gastos sin vencimiento**: campo "Fecha" único; los campos de
  vencimiento quedaron opcionales.
- **Servicios del hogar**: marcar como pagado crea un gasto asociado
  (`ServicioHogar.gastoId`); desmarcarlo lo elimina; editar un servicio
  pagado actualiza el gasto.
- **Ahorros**: depositar baja el saldo disponible y retirarlo lo sube.
- **Grupos**: los pagos y cobros quedan registrados como gastos.

### Deudas individuales por grupo

- Nueva entidad `MiembroGrupo` (grupoId, nombre, deuda con signo) y
  tabla `grupo_miembros`; `DbHelper.listar` ahora acepta filtro
  `where`/`args`.
- Repositorio `lib/data/miembro_grupo_repository.dart` (mock + SQLite).
  `GrupoRepository.addGrupo` ahora devuelve el id.
- **Alta de grupo**: se cargan los nombres de los integrantes
  (separados por coma) en vez de un número; el grupo arranca sin deudas.
- **Pantalla nueva `lib/ui/grupo_detalle_screen.dart`** (ficha del grupo):
  - resumen total del grupo (`totalDeudasGrupo` en `lib/util/utils.dart`);
  - cada integrante con su deuda individual: *Me debe* / *Le debés* /
    *Al día*;
  - menú por integrante: **Editar deuda** (dirección *Me debe* / *Le
    debés* + monto), **Pagar**, **Me pagan**, **Eliminar**;
  - **Pagar** crea un gasto positivo (resta plata) y **Me pagan** un
    gasto negativo (suma plata), sin poder superar el monto adeudado;
  - el saldo total del grupo se recalcula y persiste en cada cambio y se
    refleja en la tarjeta del grupo.
- En `groups_screen.dart` el menú de la tarjeta pasó a *Ver deudas* /
  *Eliminar* (las acciones de pago a nivel grupo se movieron a la ficha);
  tocar la tarjeta también abre la ficha.

### Tests

- 34 tests en verde. Nuevos: seguridad (`seguridad_test.dart`),
  notificaciones (`notificaciones_test.dart`), deudas individuales de
  grupos, alta de grupo con integrantes, integración con el saldo del
  inicio y regresión del bug de solo lectura (`migracion_test.dart`).

---

## Errores encontrados y resueltos

### 1. `Database readonly` al crear un grupo (crítico)

**Síntoma:** `SqfliteFfiException ... Database readonly` en
`INSERT INTO grupos ...` con `readOnly: true, singleInstance: true` al
crear un grupo (aunque la app parecía funcionar normal).

**Causa raíz:** `DbHelper._migrarCuentasExistentes` abría todas las
bases de cuentas con `readOnly: true` para leer una tabla vieja
`usuarios`. Las bases creadas por la versión actual **no tienen** esa
tabla, la lectura fallaba y el `close()` (que estaba después de la
lectura, no en un `finally`) quedaba saltado. sqflite cachea conexiones
por ruta (`singleInstance`), así que al entrar a la cuenta,
`openDatabase` devolvía **esa misma conexión en solo lectura**: los
SELECT funcionaban y el primer INSERT reventaba.

**Fix:** en `lib/data/dbhelper.dart`, la apertura de migración ahora se
hace con `singleInstance: false` (nunca se cachea la conexión de
solo lectura) y el `close()` va en un `finally` (se libera aunque la
lectura falle). Los datos no se dañaron: `readOnly` es una marca de la
conexión, no del archivo.

**Test de regresión:** `test/migracion_test.dart` — "La migracion de
cuentas no deja la base del usuario en solo lectura" (fallaba con el
mismo error antes del fix).

### 2. Errores de tests durante el desarrollo

| Error | Causa | Solución |
|---|---|---|
| `Found 0 widgets with text "Inicio"` | La ficha del grupo cubría la barra de navegación | `pop()` de la ficha antes de cambiar de pantalla |
| Menús de grupos no encontrados | `find.ancestor` no matcheaba el `PopupMenuButton` | Buscar por `find.byTooltip(...)` |
| Widgets "fuera del viewport" (800x600) | Menús y botones bajo el pliegue | `ensureVisible` / `scrollUntilVisible` antes del tap |
| Mensaje de validación vacío | Texto largo fuera de pantalla | `find.textContaining` + diálogos con `SingleChildScrollView` |
| `mock_test` con asserts en rojo | Los asserts quedaron desactualizados al cambiar los repositorios | Asserts actualizados al nuevo comportamiento |

---

## Commits previos (contexto)

- `4dc5658` feat: arquitectura por capas, SQLite multiusuario y perfil
- `9c80c59` feat: repositorios con fuente de datos conmutable (mock <-> SQLite)
- `ca6a1df` Quitar version web, README actualizado y tests portables
