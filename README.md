# Taji Móvil

Aplicación Flutter de Taji para Android e iOS. La base T101 integrada incluye navegación declarativa, cliente Dio, renovación JWT coordinada, almacenamiento seguro y estructura modular.

## Arquitectura T101

- Bootstrap y composición de dependencias separados de main.dart.
- GoRouter con redirecciones según el estado de la sesión.
- Cliente HTTP centralizado, endpoints versionados y errores tipados.
- Access token, refresh token y perfil mínimo en flutter_secure_storage.
- Restauración de sesión; una caída de red no borra credenciales válidas.
- Modelos inmutables con fromJson y toJson.
- Configuración incluida como asset tanto en debug como en release.

Consulta docs/T101_ARQUITECTURA.md para los flujos internos.

## Configuración de la API

La aplicación carga assets/config/app_config.json desde AppConfig en el arranque:

~~~json
{
  "apiBaseUrl": "https://167.86.106.105/taji/api/v1",
  "connectTimeoutMs": 12000,
  "receiveTimeoutMs": 12000
}
~~~

La aplicación apunta al servidor de producción (`https://167.86.106.105/taji/api/v1`). El certificado TLS del servidor es válido y verificable con las CAs del sistema (Windows/Android), por lo que no hace falta ningún ajuste de SSL en la app; el `network_security_config.xml` ya permite el tráfico a esa IP y confía en las CAs del sistema y las instaladas por el usuario como respaldo. Para un emulador Android local apuntando al backend de desarrollo puedes usar 10.0.2.2; para un teléfono físico usa la IP LAN accesible del Backend.

## Requisitos

- Flutter 3.19 o superior
- Dart incluido con Flutter
- Android Studio o Xcode
- Android minSdk 23, requerido por el almacenamiento seguro usado en T101

## Instalación y ejecución

~~~powershell
.\instalar_requerimientos.ps1
.\iniciar.ps1
~~~

iniciar.ps1 valida la configuración empaquetada y ejecuta Flutter sin cambiarla. Puedes seleccionar un dispositivo:

~~~powershell
.\iniciar.ps1 -Device "emulator-5554"
~~~

## Verificación

~~~powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
~~~

## Estructura relevante

~~~text
Movil/
├── android/
├── assets/config/
│   └── app_config.json       # Configuración empaquetada
├── docs/
│   └── T101_ARQUITECTURA.md
├── lib/
│   ├── core/                 # Configuración, router, HTTP y almacenamiento
│   ├── domain/models/        # Modelos Dart
│   ├── features/             # Funcionalidades por módulo
│   ├── shared/               # Componentes reutilizables
│   └── main.dart
├── test/
├── iniciar.ps1
├── instalar_requerimientos.ps1
└── pubspec.yaml
~~~
