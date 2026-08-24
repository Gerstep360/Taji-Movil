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
  "apiBaseUrl": "http://192.168.100.223:8000/api/v1",
  "connectTimeoutMs": 12000,
  "receiveTimeoutMs": 12000
}
~~~

Esta es la fuente de configuración del binario. Los scripts PS1 no la reescriben, así que la aplicación release usa exactamente el valor compilado. Antes de publicar, cambia la URL a HTTPS del servidor de producción y vuelve a compilar.

Para un emulador Android local puedes usar 10.0.2.2; para un teléfono físico usa la IP LAN accesible del Backend.

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
