# Módulos móviles disponibles

Versión `1.1.2+4`. Instalar una compilación nueva: el APK anterior no recibe pantallas nuevas por actualizar el servidor.

## Dictado de reportes sin Google

La pantalla de reportes usa `RecordedReportVoice` y `record` 6.2.1: captura PCM16 mono a 16 kHz en memoria, hasta 30 segundos (<1 MB), sin ventanas de Google ni modelos de reconocimiento en el teléfono. Termina tras una pausa de voz o con «Terminar y consultar». El audio WAV se envía autenticado a `cu31/transcribe/`; el Backend usa NVIDIA y no persiste el audio. Requiere conexión y consume la API de NVIDIA. La clave permanece en el servidor.

La consulta se envía automáticamente solo cuando llega una transcripción; cancelar o fallar no genera una consulta. Hay un timeout de transcripción de 45 segundos independiente del cliente general. No se garantiza reconocimiento perfecto: ruido, conexión y disponibilidad del proveedor siguen afectando el resultado. La escritura manual continúa disponible. El grabador requiere recompilar e instalar el APK, no basta hot reload.

- Inicio: accesos directos a incidencias/IA, reservas, comunicados y reportes PDF según permisos.
- Gestión: condominio, personal, sectores, unidades, residentes, asociaciones, permisos de roles existentes y bitácora.
- Comunidad: áreas, reservas, comunicados, asambleas y acuerdos, con listas, búsqueda, detalle y formularios nativos.
- Los módulos existentes de seguridad, activos, QR, mantenimiento e incidencias conservan sus flujos.
- Reportes: generar vista previa y elegir **PDF (.pdf)** antes de compartir. También conserva Excel, CSV, HTML, dictado y lectura. El servidor aplica límites y autorización.

No se desactiva la seguridad: `Sin permiso` significa que el rol no está autorizado. No hay entradas con `Pronto`. Las reservas de residentes usan automáticamente su identidad, requieren horarios futuros y permiten cancelar antes del inicio. La administración puede aprobar/rechazar. Las bajas se realizan por estado para conservar el historial.

## Extensión

`lib/features/management/module_catalog.dart` declara campos y contratos; `module_repository.dart` utiliza el cliente HTTP central y su JWT/tenant; `module_screen.dart` reutiliza listas, detalles y editores. Agregar un contrato no sustituye la autorización del Backend. No añadir direcciones IP en pantallas: se conserva `assets/config/app_config.json`.

## Pruebas

`flutter analyze --no-pub` y `flutter test --no-pub`.

Integración real sin datos del usuario: iniciar `Backend/scripts/serve_cu24_test_api.py`, definir `CU24_LIVE_URL=http://localhost:18766` y ejecutar `flutter test --no-pub test/community_reports_live_test.dart test/assets_maintenance_live_test.dart`. El servidor utiliza SQLite de pruebas en memoria.

`test/mobile_modules_test.dart` verifica permisos, rutas de repositorios, formularios obligatorios y todos los módulos a 390 px. Con `TAJI_PREVIEW_FONT=C:/Windows/Fonts/segoeui.ttf` también genera capturas de referencia en `docs/screenshots/`. No necesita compilar APK.
