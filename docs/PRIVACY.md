# PRIVACY — Privacidad by design

## Reglas (no negociables)

```
NO guardar audio.
NO guardar transcripciones.
NO enviar audio a servidores.
NO enviar texto a servidores.
NO analytics durante Cinema Mode.
NO crash reports que incluyan transcript text.
```

## Cómo se cumplen en la implementación

| Regla | Mecanismo |
|---|---|
| Sin audio en disco | El tap de `AVAudioEngine` entrega PCM en RAM al analyzer y lo descarta. No existe ninguna ruta de escritura de audio en el código. |
| Sin transcripciones en disco | El texto vive en memoria (pipeline → eventos → estado React). No hay persistencia local alguna (sin AsyncStorage, sin ficheros). |
| Sin texto a servidores | SpeechAnalyzer y Translation son on-device. No hay ningún cliente de red en el pipeline. |
| Logs sin contenido | `Logger` solo emite eventos y números (`speechFinalReceived length=31`, `translationFinished ms=102`). No hay ninguna llamada que registre texto. |
| Sin analytics | No hay ninguna dependencia de analytics en package.json. |
| UI limpia al reabrir | El estado de subtítulos vive en memoria de sesión; al cerrar la app desaparece. |

## Permisos

- **Micrófono** (`NSMicrophoneUsageDescription`): se pide solo con acción explícita del
  usuario (Preparar offline / INICIAR SUBTÍTULOS). Texto en app.json:
  «El micrófono se utiliza únicamente mientras los subtítulos están activos…».
- SpeechAnalyzer on-device no requiere permiso de reconocimiento de voz (verificado contra
  WWDC25 277 y el sample oficial; riesgo residual documentado en el research).

## Verificación (QA)

Tras una sesión completa:

1. Inspeccionar el sandbox de la app (Xcode/Finder en device, o `eas` diagnostics):
   - No deben existir ficheros de audio (`*.wav`, `*.m4a`, caches de audio).
   - No deben existir ficheros de transcripción/traducción.
2. Cerrar y volver a abrir la app: ningún diálogo anterior debe aparecer.
3. Revisar los logs del dispositivo: solo eventos y métricas numéricas.

## Modelos de idioma

Los modelos de speech/translation descargados pertenecen al **sistema** (gestión del SO,
fuera del sandbox de la app). La app no puede leer su contenido ni acceder a datos de
otras apps; solo solicitar su instalación.
