# Revisión e integración móvil sin duplicar PR

Fecha: 2026-11-03. Rama: `Gerstep`. Respaldo: `backup/Gerstep-before-cu18-cu25-completion-20261103`.

## Qué se conserva e integra

| CU | Implementación móvil utilizada |
|---|---|
| CU18 | Formulario existente `features/incidents/incident_report*`: catálogos del servidor, ubicación, evidencias, validación y confirmación. |
| CU19/CU20 | Seguimiento existente: lista/detalle, responsable asignado y consultas; no se duplica el módulo de incidencias de Noelia/Eunice. La asignación administrativa sigue en Web. |
| CU21 | Estado, fechas objetivo/vencidas, responsable y línea de tiempo existentes. |
| CU22 | Panel existente de categoría, prioridad, riesgos, recomendaciones, carga/error y evidencias. No se sustituye la integración NVIDIA. |
| CU23 | Consulta paginada de inventario, ficha y QR en `/activos`. El CRUD administrativo permanece en Web. |
| CU24 | Lector de activos en `/identificar-activo-qr`, permiso de cámara, alternativa manual, detalle e historial. |
| CU25 | Órdenes asignadas en `/mantenimiento`: paginación, iniciar/pausar/completar, notas, foto de evidencia e historial. Planificación/asignación administrativa en Web. |
| CU31 | Reportes existentes con consulta, dictado Google, revisión y exportación: conservados. |

CU25 procede de `origin/DaniDev` (`f1df718`, PR #12). Se importaron solo su módulo y pruebas; se conectaron al proveedor de datos, arranque, permisos, navegación y menú actuales.

Durante la revisión `git fetch` encontró CU24 actualizado en `origin/Cristel` (`80df693`, modelo original `dc2e065`). Esa rama ya incluye CU25 y cambia la API a un emulador. Se reutilizaron **solo sus modelos de activos/historial y pruebas**. Hay un único modelo, un único repositorio y un único flujo de escaneo; no se importaron controladores/pantallas alternativos ni CU25 por segunda vez.

No se incorporaron los formularios paralelos de Noelia/Eunice porque el contrato ya está cubierto en Gerstep. Tampoco se reemplazaron `app_config.json`, clientes HTTP, almacenamiento seguro, configuración Android/iOS, dictado o dependencias.

## Ajustes de compatibilidad

- Endpoints y URL base siguen centralizados. Configuración empaquetada en `assets/config/app_config.json`, sin depender de argumentos de compilación.
- Guardas y menú coinciden con permisos de Backend; sin deducir permisos administrativos del nombre de un rol.
- Estado de activos/órdenes recreado por usuario y condominio. Un resultado asíncrono no notifica después de cerrar su pantalla.
- QR de visitas no se acepta como QR de activo; el servidor valida pertenencia y permisos. Fallar un escaneo limpia el resultado anterior.
- Cámara se detiene al cerrar o pausar; carga/errores y alternativa manual visibles.
- Órdenes paginadas; antes de leer una foto en memoria se comprueba el límite de 20 MB.
- Única corrección en prueba antigua CU11: `Denegado` debe buscarse dentro de la tarjeta, no confundirse con el filtro que lleva el mismo texto.

## Evidencia

- `flutter analyze --no-pub`: sin problemas.
- Suite completa con servidor efímero disponible: **148 pruebas correctas**, incluida una integración contra Django real con JWT móvil, inventario, QR/historial, rechazo de otro condominio, órdenes y seguimiento.
- Los modelos de Cristel tienen sus pruebas originales; se agregan pruebas de permisos, paginación, cierre de pantalla y UI a 390×844.
- [Inventario](screenshots/CU23-flutter-inventory.png), [QR](screenshots/CU24-flutter-qr.png), [orden](screenshots/CU25-flutter-order.png). Mismo azul, tipografía, fondos y componentes Taji.
- **No se compiló APK**. No se verificaron cámara física, instalación Android/iOS ni micrófono de un teléfono real en esta revisión.

Prueba real opcional: iniciar en Backend `scripts/serve_cu24_test_api.py`, definir en la consola de pruebas `$env:CU24_LIVE_URL='http://localhost:18766'` y ejecutar `flutter test --no-pub`. Sin la variable, solo se omite esa integración real. La variable no configura ni es necesaria para la aplicación release.

PostgreSQL estaba detenido: pruebas Django aisladas con SQLite en memoria, sin tocar datos reales. No hubo push ni fusión/cierre de PR remotos.
