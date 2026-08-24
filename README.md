```text
 ╔══════════════════════════════════════════════════════════════════════════════╗
 ║                                                                              ║
 ║   ████████╗ █████╗  ██████╗ ██╗   ███╗   ███╗ ██████╗ ██╗   ██╗██╗██╗        ║
 ║   ╚══██╔══╝██╔══██╗   ██╔══╝██║   ████╗ ████║██╔═══██╗██║   ██║██║██║        ║
 ║      ██║   ███████║   ██║   ██║   ██╔████╔██║██║   ██║██║   ██║██║██║        ║
 ║      ██║   ██╔══██║██ ██║   ██║   ██║╚██╔╝██║██║   ██║╚██╗ ██╔╝██║██║        ║
 ║      ██║   ██║  ██║╚█████╔╝ ██║   ██║ ╚═╝ ██║╚██████╔╝ ╚████╔╝ ██║███████╗   ║
 ║      ╚═╝   ╚═╝  ╚═╝ ╚════╝  ╚═╝   ╚═╝     ╚═╝ ╚═════╝   ╚═══╝  ╚═╝╚══════╝   ║
 ║                                                                              ║
 ║               TAJI — Aplicación Móvil para Condominios                       ║
 ║                    Flutter / iOS & Android App                               ║
 ╚══════════════════════════════════════════════════════════════════════════════╝
```

# TAJI Movil — Aplicación Móvil en Flutter

Aplicación móvil multiplataforma (Android y iOS) de la red **Taji**, desarrollada con el SDK de **Flutter**. Incluye autenticación con JWT (access/refresh tokens) almacenados en vault seguro del sistema, renovación automática ante respuestas `401 Unauthorized`, restauración transparente de sesión y mapeo de datos inmutables desde/hacia JSON.

---

## Arquitectura base (T101)

- Bootstrap y composición de dependencias separados de `main.dart`.
- Navegación declarativa con `go_router` y guardas según el estado de sesión.
- Cliente Dio centralizado, endpoints versionados y renovación JWT coordinada.
- Tokens y perfil mínimo almacenados con `flutter_secure_storage`.
- Restauración offline: una caída de red no elimina la sesión; un 401/403 confirmado sí.
- Errores backend interpretados mediante `error.code`, `error.message` y `error.fields`.
- Configuración empaquetada en `assets/config/app_config.json`, disponible también en release.

Consulta `docs/T101_ARQUITECTURA.md` para el flujo completo y las decisiones de seguridad.

> En debug se admite HTTP hacia una IP privada de la LAN. Para publicar un release usa HTTPS; no se habilitó tráfico HTTP global en producción.

---

## Requisitos Previos

- **Flutter SDK**: Versión 3.19.x o superior
- **Dart SDK**: Incluido junto a Flutter
- **Android Studio / Xcode**: Para emuladores o compilación en dispositivos físicos
- **PowerShell**: (Para ejecutar los scripts de automatización `.ps1` en Windows)

---

## Instalación y Configuración del Entorno

Puedes preparar las dependencias del proyecto móvil de dos formas: mediante el script automático de PowerShell o usando comandos CLI manuales de Flutter.

### Opción 1: Mediante Script de PowerShell (Recomendado)

Abre una terminal PowerShell en el directorio `Movil` y ejecuta:

```powershell
.\instalar_requerimientos.ps1
```

Este script automatiza los siguientes pasos:
1. Verifica que el SDK de Flutter esté instalado y disponible en el `PATH`.
2. Ejecuta `flutter pub get` para descargar los paquetes listados en [pubspec.yaml](file:///c:/Users/rojas/Documents/Proyectos/Sistemas%20de%20informacion%20II/Movil/pubspec.yaml).
3. Crea el archivo de configuración inicial [assets/config/app_config.json](file:///c:/Users/rojas/Documents/Proyectos/Sistemas%20de%20informacion%20II/Movil/assets/config/app_config.json).

---

### Opción 2: Mediante Comandos Manuales (CLI)

Si prefieres realizar el proceso manualmente por consola:

1. **Navegar a la carpeta Movil**:
   ```powershell
   cd Movil
   ```

2. **Obtener paquetes de Flutter/Dart**:
   ```powershell
   flutter pub get
   ```

3. **Verificar o crear el archivo de configuración de Runtime**:
   Asegúrate de que exista `assets/config/app_config.json` con el contenido base:
   ```json
   {
     "apiBaseUrl": "http://10.0.2.2:8000/api/v1",
     "connectTimeoutMs": 12000,
     "receiveTimeoutMs": 12000
   }
   ```
   *(Nota: `10.0.2.2` es el alias que usa el emulador oficial de Android Studio para conectarse al `localhost` de la computadora).*

---

## Cómo Ejecutar la Aplicación Móvil

### Opción 1: Mediante Script PowerShell (Recomendado para Red Local / MVP)

Para ejecutar Flutter en tu dispositivo físico o emulador actualizando automáticamente la URL de la API en el archivo empaquetado:

```powershell
.\iniciar.ps1
```

#### Parámetros opcionales del script `iniciar.ps1`:
- **`-MachineIp`**: Especifica la IP local de tu máquina en la red (ej. `"192.168.100.50"`).
- **`-ApiPort`**: Especifica el puerto del Backend (por defecto `8000`).
- **`-ApiBaseUrl`**: Sobrescribe la URL completa de la API (ej. `"http://10.0.2.2:8000/api/v1"` para emulador Android).
- **`-Device`**: ID del dispositivo o emulador objetivo donde se lanzará la app.

**Ejemplos de uso:**
```powershell
# Ejecutar en una IP específica de la LAN
.\iniciar.ps1 -MachineIp "192.168.1.10"

# Ejecutar en Emulador Android
.\iniciar.ps1 -ApiBaseUrl "http://10.0.2.2:8000/api/v1"

# Especificar dispositivo objetivo
.\iniciar.ps1 -Device "emulator-5554"
```

---

### Opción 2: Mediante Comandos Manuales (CLI)

1. **Listar dispositivos conectados/emuladores**:
   ```powershell
   flutter devices
   ```

2. **Iniciar la aplicación en modo Debug**:
   ```powershell
   flutter run
   ```

3. **Lanzar en un dispositivo específico**:
   ```powershell
   flutter run -d <ID_DEL_DISPOSITIVO>
   ```

---

## Scripts PowerShell Incluidos

| Script | Descripción | Parámetros Principales |
| --- | --- | --- |
| [instalar_requerimientos.ps1](file:///c:/Users/rojas/Documents/Proyectos/Sistemas%20de%20informacion%20II/Movil/instalar_requerimientos.ps1) | Verifica Flutter SDK, ejecuta `flutter pub get` y genera la configuración inicial `app_config.json`. | Ninguno |
| [iniciar.ps1](file:///c:/Users/rojas/Documents/Proyectos/Sistemas%20de%20informacion%20II/Movil/iniciar.ps1) | Autodetecta la IP LAN (o acepta `-ApiBaseUrl`), actualiza `assets/config/app_config.json` y ejecuta `flutter run`. | `-MachineIp`, `-ApiPort`, `-ApiBaseUrl`, `-Device` |

---

## Comandos Útiles de Desarrollo y Compilación

```powershell
# Analizar código con el linter de Dart
flutter analyze

# Ejecutar pruebas unitarias
flutter test

# Compilar ejecutable APK para Android (Release)
flutter build apk --release

# Compilar App Bundle para Google Play (Release)
flutter build appbundle --release
```

---

## Estructura del Proyecto Móvil

```text
Movil/
├── android/            # Proyecto nativo Android y AndroidManifest
├── assets/
│   ├── config/
│   │   └── app_config.json  # Configuración compilada en runtime (URL API, Timeouts)
│   └── images/         # Recursos gráficos, íconos y marca
├── ios/                # Proyecto nativo iOS (Runner.xcworkspace, Info.plist)
├── lib/
│   ├── core/           # Configuración, router, tema, HTTP y almacenamiento seguro
│   ├── domain/
│   │   └── models/     # Modelos Dart inmutables (fromJson/toJson) de las tablas de dominio
│   ├── features/       # Autenticación por funcionalidad: data, state, models y screens
│   ├── shared/         # Componentes visuales reutilizables
│   └── main.dart       # Punto de entrada de la aplicación Flutter
├── test/               # Pruebas unitarias e integración de Flutter
├── iniciar.ps1         # Script de lanzamiento con autodetección de IP LAN
├── instalar_requerimientos.ps1 # Script de instalación del SDK y pub get
└── pubspec.yaml        # Configuración de dependencias y assets de Flutter
```
