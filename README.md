# ConectaLab — Fase 4

Laboratorio educativo en español con Flutter, Material 3, tema oscuro y navegación adaptable. Incluye transportes de red, diagnóstico HTTPS, lecciones Wi-Fi/datos móviles, descubrimiento BLE, permisos y chat local con imágenes reales. No existe un servidor de chat ni comunicación con otros usuarios o dispositivos.

## Entorno y dependencias

Entorno revisado: Flutter 3.44.8 estable y Dart 3.12.2 en Windows. El SDK Dart requerido es `^3.12.2`.

- `connectivity_plus` 7.3.1: consulta inicial y eventos con listas de transportes. Se conservan Wi-Fi, celular, Ethernet, VPN y otros simultáneamente.
- `http` 1.6.0: petición HTTPS cancelable, con timeout de 8 segundos.
- `cupertino_icons`: dependencia existente conservada.
- `image_picker` 1.2.4: selector nativo/navegador y cámara Android/iOS. API y requisitos revisados en [documentación oficial](https://pub.dev/packages/image_picker/versions/1.2.4) y [implementación Web](https://pub.dev/packages/image_picker_for_web).

Se verificaron las interfaces instaladas y la documentación oficial:
https://pub.dev/packages/connectivity_plus/versions/7.3.1
https://pub.dev/packages/http/versions/1.6.0

## Ejecutar y validar

```sh
flutter pub get
flutter devices
flutter run -d chrome
# También: flutter run -d edge o flutter run -d ID_DEL_TELEFONO

dart format lib test
flutter analyze
flutter test
flutter build web
flutter build apk --debug
```

## Diagnóstico y endpoint

Una instancia de `ConnectivityService` consulta el transporte al abrir la aplicación, escucha cambios y vuelve a comprobar al regresar del segundo plano. Agrupa eventos durante 600 ms, comparte la operación en curso y descarta resultados de redes anteriores. Libera suscripción, temporizador y cliente HTTP al destruirse.

El transporte reportado y la comunicación HTTPS se muestran por separado. La petición utiliza la ruta elegida por el sistema: no comprueba cada interfaz individualmente, no detecta la generación celular ni mide la velocidad de la conexión.

Endpoint predeterminado: `https://httpbin.org/status/204`. Es un servicio público externo cuya disponibilidad puede variar. Solo se envía una marca temporal para evitar caché, sin datos personales añadidos por la aplicación; se mantiene la validación TLS. El servidor recibe los metadatos normales de cualquier petición, incluida la IP de origen.

Para cambiarlo por un servidor HTTPS propio:

```sh
flutter run -d chrome --dart-define=CONNECTALAB_HTTPS_ENDPOINT=https://tu-servidor.example/health
flutter build web --dart-define=CONNECTALAB_HTTPS_ENDPOINT=https://tu-servidor.example/health
```

También se puede proporcionar `endpoint` al construir `HttpHttpsProbe`. Debe ser una URL HTTPS sin credenciales. En Web, el servidor debe permitir el origen mediante CORS. Se usa GET sin cabeceras personalizadas y sin seguir redirecciones; los navegadores pueden convertir una redirección en error de conexión. Se recomienda un endpoint pequeño sin redirecciones.

Cualquier respuesta HTTP, incluidos 404 y 503, confirma comunicación con ese servidor. Se mide el tiempo hasta las cabeceras y se muestra la hora de comprobación. Timeout y error significan que la prueba no pudo completarse: pueden deberse al servidor, DNS, TLS, red o CORS, y no demuestran ausencia absoluta de Internet.

## Archivos principales

- `lib/services/connectivity_service.dart`: clasificación, abstracciones para pruebas, consulta, eventos y petición HTTPS.
- `lib/app.dart`: instancia compartida, ciclo de vida, tema y navegación existente.
- `lib/screens/home_screen.dart`: tarjeta real de diagnóstico y accesos educativos.
- `lib/screens/network_screen.dart`: estado celular/Wi-Fi, lecciones 3G/4G/5G y ajustes compatibles.
- `lib/widgets/connectivity_card.dart`: carga, resultado, tiempo, fecha y actualización manual.
- `lib/widgets/network_comparison.dart`: tabla educativa adaptable.
- `android/app/src/main/AndroidManifest.xml`: permisos normales de Internet y estado de red; consultas de actividades de ajustes.
- `android/app/src/main/kotlin/com/example/exposicion/MainActivity.kt`: apertura de ajustes mediante canal nativo.
- `test/connectivity_service_test.dart`, `test/connectivity_fakes.dart` y `test/widget_test.dart`: pruebas del servicio y navegación.

## Plataformas y limitaciones

**Android:** `INTERNET` y `ACCESS_NETWORK_STATE` están declarados. El diagnóstico de red no solicita ubicación ni activa/desactiva radios; los requisitos BLE se detallan más abajo. El botón de ajustes aparece cuando el sistema puede resolver la actividad: panel de Internet desde Android 10 y ajustes inalámbricos en versiones anteriores. Se consulta otra vez al volver a la app. El proyecto usa Java 17, AGP 9.0.1 y Gradle 9.1, compatibles con los mínimos del paquete.

**iOS:** mínimo configurado en 13.1. Las peticiones son HTTPS; no se añaden excepciones ATS. El paquete requiere Xcode 26.1.1 o posterior. No se controla la conectividad celular ni se consultan saldo, plan, señal exacta o generación. Los simuladores pueden informar cambios de Wi-Fi de forma poco fiable. Los ajustes de red se abren manualmente.

**Web:** el navegador ofrece una estimación de conectividad. La app muestra el transporte físico como desconocido, aunque el plugin entregue `wifi`. La prueba respeta CORS y las restricciones del navegador. No se simulan datos ni acceso a ajustes nativos.

No se consultan SSID, contraseñas, IP local o intensidad de señal. Wi-Fi puede conectar una red local sin Internet o compartir un enlace celular que consume un plan de datos.

## Historial: validación de fase 2 tras el apagado

- `flutter pub get`: correcto.
- `dart format lib test`: 12 archivos revisados, sin cambios de formato.
- `flutter analyze`: sin incidencias.
- `flutter test`: 13 pruebas aprobadas, incluidas respuestas HTTP de error, timeout, transportes simultáneos, cambios de red, descarte de errores antiguos y liberación de recursos.
- Navegación comprobada con pruebas de widgets en 320×640, 390×844 y 1440×1000: Inicio, datos móviles, Wi-Fi, Bluetooth, Chat y Permisos.
- `flutter build web`: correcto, genera `build/web`.
- Endpoint público: una petición real respondió HTTP 204 y permitió el origen `http://localhost:8351` mediante CORS. Esto no sustituye una prueba completa en navegador o teléfono.
- Android: `flutter build apk --debug` no pudo finalizar. Gradle falla en `:gradle:compileKotlin` al intentar borrar archivos generados en `flutter/packages/flutter_tools/gradle/build/classes/kotlin/main`, dentro del SDK de Flutter alojado en OneDrive. El fallo ocurre antes de compilar la aplicación; no se puede dar el APK por validado. Conviene cerrar procesos que usen el SDK y comprobar bloqueos de sincronización; si persiste, usar un SDK fuera de OneDrive y repetir la compilación.
- iOS: sin compilación en este equipo Windows. No se han probado cambios de Wi-Fi a datos móviles en un teléfono físico.

### Prueba manual pendiente en teléfono

1. Ejecutar la app con Wi-Fi, actualizar y revisar transporte y HTTPS.
2. Desactivar Wi-Fi desde el sistema, habilitar datos móviles y regresar a la app.
3. Activar modo avión y revisar el reporte y el resultado independiente de HTTPS.
4. Probar Wi-Fi sin salida a Internet y, si es posible, con VPN.
5. Pulsar varias veces actualizar y comprobar que no se duplican peticiones.
6. Abrir ajustes, regresar, navegar por las secciones y repetir en el navegador.

## Fase 3: BLE y centro de permisos

### Dependencias compatibles

Se fijan `flutter_blue_plus 2.3.14` y `permission_handler 12.0.1`. Esta última resuelve `permission_handler_android 13.0.1`, compatible con compileSdk 36. La versión 13.0.2 de permisos exige SDK 37 mediante su backend Android y no compila con la instalación actual; por eso se utiliza una versión estable compatible, sin overrides. Se fija `connectivity_plus 7.3.1`: 7.3.2 exige `dbus ^0.8.0`, incompatible con la dependencia Linux de BLE. La API del diagnóstico no cambia y se ejecutan de nuevo sus pruebas.

Fuentes oficiales:
- https://pub.dev/packages/flutter_blue_plus/versions/2.3.14
- https://pub.dev/packages/permission_handler/versions/12.0.1
- https://developer.android.com/develop/connectivity/bluetooth/bt-permissions

### Funcionamiento y alcance

`lib/services/permission_service.dart` concentra la política por plataforma, consultas, solicitudes individuales y ajustes. `lib/services/bluetooth_service.dart` mantiene el estado del adaptador, el escaneo y los resultados. Las APIs nativas se encapsulan detrás de interfaces para las pruebas.

El servicio BLE solo se inicializa en Android/iOS después de comprobar autorización. La pantalla muestra adaptador, escaneo, nombre anunciado cuando existe, identificador del sistema y RSSI en dBm. Agrupa dispositivos por identificador, limpia la lista al iniciar otra búsqueda y conserva los resultados del último escaneo; no indica conexiones actuales ni una distancia exacta. Los resultados no se persisten, exportan ni envían a servidores.

El escaneo dura como máximo 12 segundos. Se impiden inicios simultáneos. Detener, salir de la pantalla, pasar al segundo plano, perder autorización o apagar el adaptador detiene la búsqueda. Un inicio que termine después de salir también se cancela. Se liberan las suscripciones al eliminar el servicio. No se activa Bluetooth, no se anuncia el teléfono, no se empareja, no se conecta ni se leen características GATT.

Los permisos nunca se solicitan al arrancar. El centro muestra solo los aplicables, su propósito, estado, resultado y acceso a ajustes si es necesario. Sin autorización, el escaneo permanece deshabilitado y el diagnóstico de red sigue disponible. La API puede no distinguir una autorización nunca solicitada de una denegación; la interfaz conserva esa ambigüedad. Se distinguen autorización, denegación, denegación permanente, restricción y estado desconocido. Acceso limitado no se trata como autorización BLE. Una solicitud permanente/restringida no se repite automáticamente; se ofrecen ajustes. No se encadenan más ventanas tras una denegación. Al regresar de ajustes se consulta otra vez.

El botón Solicitar permisos no inicia automáticamente una búsqueda: tras autorizar y activar Bluetooth, se pulsa Iniciar escaneo. Las tarjetas educativas explican este flujo y Classic frente a BLE. El chat de fase 4 funciona exclusivamente de forma local.

### Permisos Android

| Permiso | Versiones | Motivo |
| --- | --- | --- |
| `BLUETOOTH_SCAN` con `neverForLocation` | Android 12+ | Descubrir anuncios BLE sin derivar ubicación |
| `BLUETOOTH_CONNECT` | Android 12+ | Consultar adaptador y nombres; el plugin también lo exige al escanear |
| `BLUETOOTH`, `BLUETOOTH_ADMIN` | Hasta Android 11, `maxSdkVersion=30` | Acceso y descubrimiento heredados |
| `ACCESS_FINE_LOCATION` | Declarado hasta Android 11; solicitado en Android 6–11 | Requisito del descubrimiento, sin consultar coordenadas |
| `ACCESS_COARSE_LOCATION` | Hasta Android 9, `maxSdkVersion=28` | Compatibilidad con descubrimiento heredado |
| `INTERNET`, `ACCESS_NETWORK_STATE` | Permisos normales | Diagnóstico HTTPS y transporte, sin diálogo |

No se declara publicidad BLE ni ubicación en segundo plano. BLE es opcional en el manifiesto. `neverForLocation` puede filtrar algunos beacons. En Android 6–11 también puede ser necesario habilitar servicios de ubicación desde los ajustes; se explica si falla el inicio y no se activan por la app.

El canal de ajustes existente añade `sdkInt` para consultar la versión Android sin otra dependencia. Se mantiene la apertura anterior de ajustes de red. `android/app/proguard-rules.pro` conserva clases nativas BLE en release; una compilación debug no valida la versión release.

### Preparación iOS

El plist incluye `NSBluetoothAlwaysUsageDescription` con la finalidad educativa del descubrimiento. La fase 4 añade las descripciones de cámara y fotografías indicadas más abajo. No se añade ubicación ni ejecución Bluetooth en segundo plano. El mínimo se ajusta a iOS 13.1 porque en iOS 13.0 la consulta del permiso Bluetooth no ofrece el mismo comportamiento sin solicitud.

El proyecto utiliza Swift Package Manager. La dependencia resuelta `permission_handler_apple 9.6.2` detecta la clave del plist y habilita `PERMISSION_BLUETOOTH`; su configuración instalada fue revisada. En Mac, ejecutar desde la raíz `flutter pub get` y `flutter build ios --no-codesign`; configurar firma y ejecutar en un iPhone físico. Si la detección de permisos falla al compilar desde Xcode, configurar `PERMISSION_HANDLER_INFO_PLIST` con la ruta absoluta al plist, según la documentación actual del backend Apple. Si se migra a CocoaPods, habilitar únicamente `PERMISSION_BLUETOOTH=1` en el bloque `post_install` del Podfile.

No se ha compilado ni ejecutado iOS en este Windows. Los identificadores CoreBluetooth no son necesariamente direcciones MAC. No se promete descubrir dispositivos Classic ni beacons que requieren CoreLocation.

### Web, escritorio y permisos de imágenes

Esta fase habilita BLE exclusivamente en Android/iOS aunque el paquete tenga implementaciones adicionales. En Web y escritorio se muestra información, controles de escaneo deshabilitados y no se llama al backend BLE. Web Bluetooth depende de un navegador compatible, HTTPS, selección explícita y dispositivos compatibles; no equivale al escaneo general móvil. El diagnóstico de red continúa funcionando en Web.

La fase 4 incorpora selección de imágenes y captura móvil, con permisos específicos y sin acceso general al almacenamiento. Su configuración se describe a continuación.

### Licencia del paquete BLE

`flutter_blue_plus 2.3.14` usa la licencia FlutterBluePlus: uso personal/educativo sin fines de lucro sin licencia comercial; revisar condiciones si cambia el destino a uso comercial. Esta versión declara posible telemetría limitada durante la compilación (metadatos de app/paquete), separada de los anuncios BLE. Fuente: https://pub.dev/packages/flutter_blue_plus/license

### Demostración en Android real

1. Conectar un teléfono con depuración USB. Ejecutar `flutter devices` y `flutter run -d ID_DEL_TELEFONO`.
2. Colocar cerca un periférico BLE autorizado que esté anunciándose. Un dispositivo Classic o ya conectado puede no aparecer.
3. Abrir Permisos: Android 12+ muestra descubrimiento y consulta del adaptador; Android 6–11 muestra ubicación para BLE.
4. Denegar una solicitud y verificar que escaneo queda deshabilitado mientras Inicio, Wi-Fi y datos móviles siguen funcionando.
5. Conceder permisos; ante denegación permanente, abrir ajustes y regresar. Activar Bluetooth manualmente. En Android 6–11 revisar servicios de ubicación.
6. Abrir Bluetooth, iniciar y revisar anuncios con nombre, identificador y RSSI. Sin periféricos, la lista debe quedar vacía.
7. Detener manualmente, repetir hasta timeout de 12 segundos y comprobar la detención al navegar o pasar al segundo plano.
8. Apagar Bluetooth desde el sistema, regresar y comprobar el mensaje. Repetir también el diagnóstico HTTPS.

Los proveedores simulados están únicamente en `test/`; no sustituyen pruebas de hardware físico.

### Archivos de fase 3

Nuevos: servicios Bluetooth/permisos; pantallas Bluetooth/permisos; `permission_controls.dart`; ProGuard; `bluetooth_fakes.dart`, `bluetooth_service_test.dart` y `bluetooth_widget_test.dart`.

Actualizados: `pubspec.yaml`, `pubspec.lock`, `lib/app.dart`, indicador de fase en Inicio, `test/widget_test.dart`, manifiesto Android, `MainActivity.kt`, Gradle de la app, plist y mínimo iOS, README. La lógica de conectividad y las lecciones Wi-Fi/datos móviles se conservan.

### Validación de fase 3

Validación final: `flutter pub get` correcto; `dart format lib test` correcto; `flutter analyze` sin incidencias; `flutter test` con 26 pruebas aprobadas; `flutter build apk --debug` correcto; `flutter build web` correcto. También se recompila Web con `--no-wasm-dry-run` después del último ajuste del servicio. No se ha ejecutado el APK en hardware ni compilado iOS o release.

Configuración Android comprobada en este Flutter: `compileSdk=36`, `targetSdk=36`, `minSdk=24` (Android 7+). La política de permisos distingue también API 23 para permitir reutilizarla si se ajusta el mínimo, pero el APK actual no se instala en Android 6.

En Windows, si `flutter pub get` informa que necesita enlaces simbólicos, habilitar el Modo de desarrollador en Configuración o ejecutar la instalación con los privilegios adecuados. No es un permiso móvil de la aplicación.

## Fase 4: chat local e imágenes

Abrir la pestaña **Chat**. Escribir y pulsar enviar añade un mensaje exclusivamente al historial de este dispositivo, con remitente «Tú · este dispositivo» y fecha/hora real de creación. Los mensajes vacíos se rechazan. No hay respuestas ficticias, estados de entrega ni envío a un servidor o por Bluetooth. El indicador de modo local permanece visible.

En **Adjuntar imagen**, elegir **Seleccionar imagen** o **Tomar fotografía** en Android/iOS. Después de leer y validar el archivo aparece una vista previa: **Cancelar imagen** la descarta y **Confirmar imagen** la añade, junto con el texto escrito si lo hay. En pantallas pequeñas esas acciones son iconos de cerrar y confirmar con etiquetas accesibles. Cancelar el selector no crea un mensaje. Los errores de permisos, archivo eliminado, formato ilegible y cámara no disponible se explican sin bloquear el resto del chat. En Android se consulta `retrieveLostData` una vez al iniciar: una selección recuperada requiere confirmación, nunca se envía automáticamente.

### Con Internet y sin Internet

El chat y la lectura de una imagen local disponible no dependen de la red. El icono de diagnóstico abre una tarjeta educativa y la tarjeta HTTPS existente, con transporte, resultado, tiempo y hora de la última comprobación. **Actualizar diagnóstico** ejecuta la misma prueba del servicio compartido; escribir, reconstruir el chat y abrir la tarjeta no provocan peticiones adicionales. El retorno a primer plano mantiene la comprobación ya existente en la aplicación.

Una imagen que solo esté en la nube puede necesitar Internet para que el selector la descargue. En Web, cargar inicialmente la aplicación y sus recursos puede necesitar conexión: esta fase no garantiza una instalación PWA ni un arranque offline. Una vez cargada, el chat local sigue disponible. HTTPS fallido o timeout no prueba por sí solo ausencia absoluta de Internet; también intervienen servidor, DNS, TLS y CORS.

### Historial y límites

**Los mensajes e imágenes no persisten después de reiniciar la aplicación o recargar/cerrar Web.** Se comparten durante la sesión, también al cambiar de pestaña. Se decidió no incorporar dos sistemas de almacenamiento distintos ni guardar rutas temporales como permanentes. La copia validada de los bytes conserva la imagen en memoria durante la sesión aunque desaparezca el archivo temporal. No se escribe historial en disco ni se suben imágenes. Si Android destruye el proceso al abrir cámara/selector, el historial anterior se pierde; recuperar la selección no recupera ese historial.

Para acotar memoria: máximo 200 mensajes, 4.000 caracteres por texto, 5 MiB por archivo leído, 16 millones de píxeles y 25 MiB de imágenes en el historial. Se pide al selector reducir hasta 1600×1600 y calidad 80 cuando el backend lo admite; se verifica el tamaño antes y durante la lectura y se valida la decodificación con `instantiateImageCodecWithSize`, compatible con Web. En el navegador, el motor puede decodificar primero para conocer las dimensiones: el límite de píxeles no garantiza evitar todo pico transitorio de memoria del selector/decodificador. Las vistas se decodifican con un ancho de caché de 800 píxeles. El botón **Borrar historial local** libera las referencias de la sesión previa confirmación. No se promete conservar metadatos EXIF completos ni formatos que el sistema no pueda decodificar.

### Configuración por plataforma

- **Android:** se usa el selector del sistema/Photo Picker (Android 13+) o el mecanismo compatible del plugin. No se añade permiso general de almacenamiento, `READ_MEDIA_IMAGES` ni `CAMERA`: la captura delega en la aplicación de cámara del sistema. Los permisos BLE existentes siguen separados. La cámara puede no existir en un emulador o dispositivo.
- **iOS:** `Info.plist` incluye `NSCameraUsageDescription` y `NSPhotoLibraryUsageDescription` con finalidad del chat. La cámara se consulta y solicita individualmente desde el servicio de permisos existente. `requestFullMetadata: false` evita pedir autorización general para metadatos de fotografías; el selector concede acceso al archivo elegido. No se añade micrófono ni ubicación para imágenes. Con Swift Package Manager, el backend de permisos detecta la clave de cámara; con CocoaPods habilitar también `PERMISSION_CAMERA=1` si se migra. Compilación y ejecución iOS pendientes en macOS/iPhone.
- **Web:** selección mediante el input de archivos del navegador y bytes del archivo elegido. Captura de cámara oculta porque no se garantiza soporte del atributo capture. No se usan rutas del sistema ni APIs nativas. Los permisos del navegador/selector no equivalen a un permiso general de galería y no se inventan estados. La recarga elimina todo el historial.
- **Escritorio:** selección de archivo mediante la implementación del plugin; captura oculta. Compilaciones de escritorio no validadas en esta fase.

### Archivos de fase 4

Nuevos: `lib/models/chat_message.dart`, `lib/services/chat_service.dart`, `lib/services/image_service.dart`, `lib/screens/chat_screen.dart`, `lib/widgets/chat_message_bubble.dart`; `test/image_fakes.dart`, `test/chat_service_test.dart`, `test/chat_widget_test.dart`; comprobación opcional de Chrome `tool/verify_web_chat.cjs`.

Actualizados: dependencias y lock, `lib/app.dart`, `lib/services/permission_service.dart`, `lib/widgets/permission_controls.dart`, `lib/screens/permissions_screen.dart`, indicador de fase en Inicio, privacidad iOS, prueba de navegación existente y README. El servicio HTTPS, las lecciones de red y el servicio BLE se conservan.

### Guion de exposición

1. Ejecutar `flutter run -d ID_DEL_TELEFONO` o `flutter run -d chrome`; abrir Chat y señalar el indicador de modo local.
2. Intentar enviar espacios: mostrar validación. Escribir un mensaje y explicar remitente y hora real.
3. Seleccionar una imagen disponible en el dispositivo; cancelar la vista previa. Repetir y confirmar. En móvil, probar cámara y denegación de permiso cuando corresponda.
4. Activar modo avión desde el sistema. Escribir otro mensaje y seleccionar una imagen local; explicar que no se necesita un servidor.
5. Abrir diagnóstico y actualizar HTTPS. Comparar transporte y resultado; explicar que un fallo puede tener varias causas.
6. Cambiar de pestaña y regresar: el historial permanece durante la sesión. Reiniciar/recargar: demostrar que no hay persistencia.
7. Mostrar Wi-Fi, datos móviles, BLE y permisos. Para comunicación entre usuarios harían falta backend/transporte remoto, identificación, almacenamiento y confirmaciones reales; no se implementan en esta fase.

### Validación de fase 4

`flutter pub get` correcto; formato correcto; `flutter analyze` sin incidencias; `flutter test`: **40 pruebas aprobadas**. Cubren validación de mensajes, hora y remitente, cancelación/confirmación, errores y límites de archivos, permisos cámara independientes de BLE, recuperación Android simulada, concurrencia, dispose, chat con HTTPS fallido, desplazamiento y teclado a 320×640, diseño amplio 1440×1000 y navegación anterior.

`flutter build apk --debug` correcto: `build/app/outputs/flutter-apk/app-debug.apk`. `flutter build web` correcto; después de la corrección de imágenes se ejecutó también `flutter build web --no-wasm-dry-run`. Chrome real en modo headless: texto con red deshabilitada, selector del navegador con archivo PNG de prueba asignado mediante CDP, vista previa, confirmación e historial entre pestañas, correcto. Se inspeccionó una captura del chat para comprobar el texto mostrado. No equivale a manejar manualmente el diálogo de archivos ni a una prueba en teléfono.

La comprobación opcional se repite con `node tool/verify_web_chat.cjs` después de compilar Web; requiere Node 22+, Chrome en la ruta Windows indicada y puertos 8357/9229 libres. Usa un perfil aislado y una imagen exclusiva de prueba en `build/`, nunca introduce archivos ficticios en producción. Durante la validación se regeneraron los artefactos porque el registro Web anterior estaba vacío, y se corrigió la lectura de dimensiones no admitida por `ImageDescriptor` en Web.

No se han probado cámara, galería, modo avión ni escaneo BLE en un teléfono físico; iOS sigue pendiente en macOS/iPhone. Los proveedores simulados de las pruebas están solo en `test/`.

## Usuarios: comparación con una operación remota

La pestaña **Usuarios**, junto a Chat, consulta `https://dummyjson.com/users` al entrar por primera vez. Muestra hasta 30 perfiles en tarjetas adaptables, con avatar, nombre, correo, ciudad y empresa; el total disponible lo entrega la API. Son perfiles de ejemplo de DummyJSON, no participantes del chat. Se seleccionan únicamente los campos necesarios; no se muestran contraseñas ni datos bancarios. [Documentación oficial de usuarios](https://dummyjson.com/docs/users).

**Actualizar usuarios** ejecuta una nueva petición GET real, sin caché deliberada, con límite de ocho segundos y cancelación. Evita solicitudes simultáneas, valida la respuesta JSON y acota el cuerpo a 1 MiB. La pantalla distingue el transporte del sistema, la consulta a DummyJSON y el diagnóstico HTTPS compartido. No solicita Bluetooth, cámara ni ubicación para descargar usuarios: `INTERNET` y estado de red ya están configurados como permisos normales de Android. El acceso al centro de permisos explica esta diferencia; las restricciones de red de la app, Wi-Fi, datos móviles y modo avión se revisan en los ajustes del dispositivo.

Si falla la consulta, muestra timeout, respuesta HTTP de error o imposibilidad de conectar, con reintento. No afirma que un fallo pruebe ausencia absoluta de Internet: puede fallar DummyJSON, DNS, TLS o CORS. Si ya había usuarios, conserva la última carga en memoria y la identifica como datos anteriores cuando falta transporte o falla la actualización. No se conservan al reiniciar. Los avatares pueden fallar independientemente de la consulta; se muestran iniciales en su lugar. Cambiar de pestaña no descarga otra vez.

Demostración: abrir Usuarios con conexión, pulsar actualizar y ver los perfiles; activar modo avión y pulsar actualizar para mostrar el error y los datos anteriores; abrir Chat y escribir para contrastar una función local; restablecer Wi-Fi/datos y reintentar Usuarios. No se verificó esta secuencia en un teléfono físico.

Archivos: `lib/services/users_service.dart`, `lib/screens/users_screen.dart`, integración de navegación en `lib/app.dart`, `test/users_test.dart` y ampliación de la comprobación Chrome `tool/verify_web_chat.cjs`. Se mantienen las dependencias actuales.

Validación de Usuarios: formato correcto, `flutter analyze` sin incidencias, **45 pruebas aprobadas**, APK debug y compilación Web correctos. Chrome headless consultó la API real, cargó 30 perfiles, reintentó con red deshabilitada y mostró el error con los datos anteriores identificados; también comprobó el chat y sus imágenes offline. La comprobación alterna pestañas para actualizar el árbol de accesibilidad usado por CDP. La respuesta online y el diseño se inspeccionaron en una captura. No se ha ejecutado el APK actualizado en hardware ni compilado iOS.
