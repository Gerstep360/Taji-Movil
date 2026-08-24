# T101 — Base de la aplicación móvil

## Inicio

`main.dart` delega en `bootstrap.dart`. El bootstrap carga la configuración
empaquetada, construye almacenamiento, cliente HTTP, repositorio, controlador de
sesión y router antes de ejecutar `TajiApp`.

Si `assets/config/app_config.json` es inválido, la aplicación muestra una
pantalla comprensible en lugar de quedar en blanco.

## Navegación

`go_router` centraliza las rutas en `core/router/`:

- `/splash`
- `/iniciar-sesion`
- `/crear-cuenta`
- `/recuperar-contrasena`
- `/inicio`

El router escucha `AuthController`: durante la restauración muestra splash, un
invitado solo puede usar rutas de autenticación y una sesión activa se redirige
al inicio.

## HTTP

`ApiConfig` lee `assets/config/app_config.json`, que queda incluido dentro del
APK/IPA. La URL debe terminar en `/api/v1`; HTTP se acepta únicamente para
localhost, emulador o IP privada y HTTPS se acepta para producción.

`ApiClient` usa Dio, añade Bearer JWT, renueva una sola vez aunque varias
peticiones reciban 401 simultáneamente y reintenta la solicitud original. Los
endpoints se concentran en `api_endpoints.dart`.

`ApiFailure` interpreta el contrato `error.code/message/fields` del backend y
mantiene compatibilidad con el formato anterior.

## Sesión segura

Access token, refresh token y una copia mínima del perfil se guardan con
`flutter_secure_storage` (Keychain en iOS y cifrado AES-GCM/Android Keystore en
Android). Si la red está caída, Taji usa el perfil cifrado y conserva los tokens;
una respuesta 401/403 confirmada invalida la sesión. Cerrar sesión elimina todo
el material local incluso si el servidor no responde.

El refresh token continúa sujeto a la caducidad configurada por el backend; una
sesión no debe ser realmente infinita por seguridad.

## Release

La configuración del servidor no depende de `--dart-define`: edita
`assets/config/app_config.json` antes de compilar. Los builds release deben usar
HTTPS. Android permite HTTP LAN solamente en el manifiesto `debug`, evitando
publicar accidentalmente una aplicación con tráfico global sin cifrar.
