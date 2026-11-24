# FinanzApp

Aplicación de finanzas personales hecha con Flutter. Permite registrar cuentas,
gastos, ingresos, metas de ahorro, servicios del hogar y grupos de gastos,
y editarlos o eliminarlos cuando se necesite.

## Requisitos

- **Flutter SDK 3.x** con Dart **3.13.2 o superior** (instalación oficial:
  https://docs.flutter.dev/get-started/install). Verificá con `flutter --version`.
- **Git** (para clonar el repositorio).
- Para correr en **Windows**: Visual Studio 2022 (o Build Tools) con la carga de
  trabajo **"Desarrollo de escritorio con C++"**.
- Para correr en **Linux**: paquetes de GTK y CMake (`sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev`).
- Para correr en **Android**: Android Studio con el SDK de Android.

No hace falta instalar extensiones: alcanza con el SDK de Flutter. Un editor
(VS Code o Android Studio) es opcional.

## Cómo ejecutarla

```bash
git clone <url-del-repositorio>
cd FinanzApp-2-arquitectura
flutter pub get
flutter run -d windows   # o -d linux / -d <id-de-tu-emulador-android>
```

La primera compilación puede tardar varios minutos. Durante el build se descarga
automáticamente `sqlite3.dll` (Windows), por lo que necesita conexión a internet.

Para ver los dispositivos disponibles: `flutter devices`.

## Cuenta de prueba

Al iniciar, la app crea la cuenta:

- Email: `test@finanzapp.com`
- Contraseña: `123456`

## Modo demo

En `lib/data/fuente_datos.dart`, la variable `FuenteDatos.usarMock` controla
de dónde salen los datos:

- `false` (valor actual): los datos se guardan en SQLite.
- `true`: modo demo, los datos son de ejemplo y se guardan solo en memoria.

Las cuentas de usuario siempre se guardan en SQLite, aunque esté activo el modo demo.

## Seguridad de las cuentas

- **Contraseñas hasheadas**: nunca se guardan en texto plano. Se almacena el
  hash SHA-256 de `email|contraseña` (`lib/data/contrasena.dart`), de modo que
  cada cuenta tiene su propio hash aunque use la misma contraseña.
- **Cuentas viejas**: si una contraseña estaba en claro, se acepta en el login
  y queda migrada a hash automáticamente.
- **Correo único**: no se pueden crear dos cuentas con el mismo correo (tampoco
  cambiando mayúsculas/minúsculas), ni tomar un correo ya usado desde el perfil.
- **Sesión persistente**: la app recuerda al último usuario autenticado al
  reiniciar. Al cerrar sesión se borra ese registro y vuelve a pedir login.
- **Recuperación de contraseña**: cada cuenta tiene un código de recuperación
  de 10 caracteres que se muestra **una sola vez** (al crear la cuenta o desde
  *Mi perfil*). Solo se guarda su hash. Con el correo, el código y una nueva
  contraseña, "Olvidé mi contraseña" en el login la restablece. El código es de
  uso único. Si se pierde, se puede generar uno nuevo desde *Mi perfil*, pero
  las cuentas sin código no se pueden recuperar.

## Notificaciones

La campana de la barra superior muestra un punto rojo cuando hay alertas
pendientes. Las notificaciones no son mensajes fijos: se calculan en el momento
a partir de los datos de la cuenta (`lib/util/notificaciones.dart`):

- **Servicios del hogar todavía sin pagar.**
- **Metas de ahorro**: alcanzadas, vencidas o con fecha objetivo próxima.

Se ordenan de más urgente a menos urgente. La pantalla de notificaciones se
actualiza cada vez que se abre. Los gastos no generan alertas: un gasto es
plata que ya salió, no algo que venza (la fecha del gasto sirve para
agruparlo por mes).

## Todo conectado al saldo del inicio

La tarjeta **Saldo total** del inicio muestra cuánta plata hay disponible:
`ingresos − gastos − plata depositada en ahorros + plata retirada`
(`saldoTotal` en `lib/util/utils.dart`). Todos los movimientos la modifican:

- **Servicios del hogar**: al marcar un servicio como pagado se registra
  automáticamente como gasto (categoría "Servicios", con la fecha del mes que
  se está viendo), y al desmarcarlo ese gasto se elimina. Si se edita un
  servicio pagado, el gasto se actualiza junto con él.
- **Grupos**: tu parte de cada gasto compartido queda registrada como un
  gasto personal. Los reembolsos no cambian el saldo, porque la parte propia
  ya se contó al crear el gasto.
- **Ahorros**: depositar baja el saldo disponible y retirarlo lo sube (el
  dinero se mueve entre tu billetera y tus metas).

## Grupos para dividir gastos

Inspirado en Tricount: cada grupo tiene un título con emoji, sus participantes
(vos aparecés como "Personal") y sus gastos compartidos.

- **Crear grupo**: título, emoji y nombres de los participantes.
- **Añadir gasto**: título, cantidad, quién puso plata (una o varias personas,
  cada una con su monto), fecha y cómo se divide:
  *Igualmente* (con centavos exactos: 100.000 entre 3 da 33.333,34 / 33.333,33 /
  33.333,33) o *Montos exactos* por persona.
- **Pestaña Gastos**: lo que se pagó, tu parte y lo que gastaste en total.
- **Pestaña Saldos**: cuánto te deben o debés. Sale de los gastos, no se carga a mano.
- **Reembolsos**: quién le debe a quién para dejar todo en cero. *Solicitar*
  copia un mensaje de cobro; *¡Está pagado!* registra el pago.
- **Saldo total**: solo cuenta tu parte de cada gasto compartido.
- Los grupos del modelo anterior se borraron al actualizar la app.


## Primera vez y navegación

- **Introducción**: al abrir la app por primera vez se muestran tres
  pantallas de bienvenida (se pueden omitir). No vuelven a aparecer.
- **Barra inferior**: Inicio, Mes, Grupo y Ahorro, con el botón **+** en el
  centro. Al tocarlo se abre un menú con **Nuevo gasto** y **Nuevo ingreso**.
- **Pantalla Mes**: reporte del mes elegido (total gastado, ingresos,
  balance y desglose por categoría) con la sección **Servicios del hogar**
  debajo: alta, edición, borrado y estado según el mes (pagado si tiene un
  gasto en ese mes, pendiente si no; cambia al mover las flechas del mes).
- **Perfil** (avatar de la cabecera): datos de la cuenta, crear otra cuenta,
  iniciar sesión con otra cuenta y cerrar sesión.
- **Modo oscuro**: el botón de la luna/sol en la cabecera cambia entre claro y
  oscuro. La elección se recuerda al reiniciar.

## Tests

```bash
flutter analyze
flutter test
```

Al cierre de este registro: `flutter analyze` sin issues y **69 tests en
verde**.

## Historial de cambios

Cada bloque funcional y los errores encontrados (con su causa y
solución) están registrados en [CHANGELOG.md](CHANGELOG.md).

## Plataformas

- **Linux**: probada (análisis y 69 tests pasan).
- **Windows**: sin probar en esta rama.
- **Android**: no probada todavía.
- **Web**: no es compatible. El código usa `dart:io`, que no existe en el navegador.
