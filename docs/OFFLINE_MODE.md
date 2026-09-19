# OFFLINE_MODE — Funcionamiento sin conexión

## Objetivo

Después de preparar los modelos con conexión, TODO el pipeline funciona en modo avión:
escuchar inglés → transcribir → traducir → mostrar español, sin red.

## Qué se prepara exactamente

En la pantalla Home, botón **«Preparar modo offline»**:

1. **Modelo de speech en-US** (SpeechAnalyzer): descarga programática con progreso real
   vía `AssetInventory.assetInstallationRequest(supporting:)` → `downloadAndInstall()`.
   El modelo vive fuera del proceso de la app (gestión del sistema) y se **reserva**
   (`AssetInventory.reserve`) para que el sistema no lo expulse bajo presión de recursos.

2. **Pack de traducción EN→ES** (Translation framework): Apple NO ofrece descarga
   programática con progreso. La primera descarga se dispara con el flujo oficial
   (`.translationTask` + `prepareTranslation()`), que muestra el diálogo de consentimiento
   del sistema **una sola vez**. Después, el estado se consulta con `LanguageAvailability`.

Ambos modelos quedan instalados a nivel de sistema operativo: sobreviven al cierre de la app.

## Estado en Home

```
✓ Speech English (on-device)
✓ Translation English → Español
✓ Funciona sin conexión
```

`getOfflineStatus()` combina ambos estados; `state == "ready"` solo cuando los dos están.

## Test obligatorio de modo avión (antes de dar el MVP por cerrado)

1. Con conexión: Home → «Preparar modo offline» hasta ver los tres ✓.
2. Cerrar la app por completo.
3. **Activar modo avión.**
4. Abrir CinemaSubs → INICIAR SUBTÍTULOS.
5. Reproducir audio en inglés (TV/altavoz a varios metros).
6. Verificar: transcripción y subtítulos en español fluyen sin red.

Si esto no funciona, el MVP NO está terminado (Definition of Done del master prompt).

## Notas técnicas

- `TranslationSession(installedSource:target:preferredStrategy:)` **lanza error** si el par
  no está instalado: por eso la preparación previa es obligatoria y el error está tipado
  (`E_TRANSLATION_MODEL_MISSING`) con mensaje accionable en la UI.
- Los modelos de Translation tradicionales (`.lowLatency`) son los que se descargan por
  defecto en el flujo de preparación — exactamente los que usa la sesión de subtítulos.
- La reserva de Assets de speech se mantiene activa mientras la app se use; no requiere
  liberación manual para el MVP (peso mínimo).
