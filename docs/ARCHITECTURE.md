# ARCHITECTURE — CinemaSubs

## Diagrama del pipeline

```mermaid
flowchart TD
    A[Micrófono iPhone] --> B[AVAudioSession / AVAudioEngine]
    B --> C[SpeechAnalyzer + SpeechTranscriber\n(transcripción progresiva EN)]
    C -->|parciales + finales| D[TranscriptStabilizer\nvolatile / stable / final]
    D -->|estable o final| E[TranslationService\nApple Translation EN→ES on-device]
    E --> F[SubtitleScheduler\nanti-flash · delay · catch-up]
    F --> G[Expo Module Event\nonSubtitle]
    G --> H[React Native UI\nCinema Mode]
    H --> I[Subtítulos españoles\nmáx 2 líneas]
```

Todo lo que está entre B y F vive en Swift (`modules/cinema-native/ios/`).
Por el bridge JS ↔ Swift solo circulan eventos ligeros. Nunca PCM.

## Estructura del repositorio

```text
CinemaSub/
├── app.json                     # config Expo (iOS 26.0 target, permisos mic, plugins)
├── eas.json                     # perfiles development / preview / production
├── src/
│   ├── app/                     # expo-router: _layout, index (Home), cinema, settings
│   ├── components/              # SubtitleView, CinemaControls, DevHud
│   ├── native/cinemaNative.ts   # fachada tipada del módulo nativo (único contacto)
│   ├── state/CinemaContext.tsx  # estado de sesión/métricas/ajustes + suscripción a eventos
│   ├── theme.ts                 # negro OLED, tipografías
│   └── utils/text.ts            # 2 líneas equilibradas, comparación significativa (puras)
└── modules/cinema-native/
    ├── src/index.ts             # CONTRATO TS ↔ Swift (tipos de eventos y funciones)
    └── ios/
        ├── CinemaNativeModule.swift        # Expo Modules API: funciones + eventos (✅)
        ├── CinemaPipeline.swift            # orquestación completa del flujo (✅)
        ├── Audio/AudioCaptureService.swift          # AVAudioEngine + tap + farFieldInput (✅)
        ├── Speech/SpeechRecognitionService.swift    # SpeechAnalyzer modular iOS 26 (✅)
        ├── Speech/SpeechModelManager.swift          # AssetInventory: descarga EN con progreso (✅)
        ├── Translation/TranslationService.swift     # TranslationSession lowLatency (✅)
        ├── Translation/TranslationModelManager.swift# packs EN→ES + bootstrap SwiftUI (✅)
        ├── Subtitles/TranscriptStabilizer.swift     # ✅
        ├── Subtitles/SubtitleScheduler.swift        # ✅
        ├── Subtitles/SubtitleSegment.swift          # ✅ (modelos + comparación)
        ├── Metrics/PipelineMetrics.swift            # ✅
        └── Support/{CinemaError, Logger}.swift      # ✅
```

> Nota crítica: la implementación usa la **API final modular** de SpeechAnalyzer
> (`SpeechAnalyzer(modules:)` + `AsyncStream<AnalyzerInput>` + `transcriber.results`).
> El patrón de las betas de 2025 (`SpeechTranscriber(audioEngine:)`, `SpeechAnalyzer(root:)`)
> ya no existe. Ver `docs/research/APPLE_APIS.md`.

## Contrato JS ↔ Swift

Definido en `modules/cinema-native/src/index.ts`:

- Funciones: `getCapabilities`, `requestPermissions`, `prepareOfflineModels`,
  `getOfflineStatus`, `startSession(options)`, `stopSession`, `setSubtitleDelay(ms)`, `getMetrics`.
- Eventos salientes: `onStatusChanged`, `onModelDownloadProgress`, `onSubtitle`,
  `onPipelineMetrics`, `onError`.
- `SubtitleEvent`: `{ id, originalText, translatedText, startTime, endTime?, isFinal,
  confidence?, latencyMs }` — exactamente el payload mínimo del master prompt.

## Flujo de datos y tiempo

1. `SpeechTranscriber` emite parciales (volatile) con timestamps.
2. `TranscriptStabilizer.ingest/tick` decide cuándo un texto está estable (ventana 350 ms inicial)
   o llega un final (prioridad absoluta).
3. `TranslationService` traduce; si llega un candidato más nuevo, la traducción pendiente
   se **cancela** (contador de cancelaciones en métricas).
4. `SubtitleScheduler` aplica: retraso manual, anti-flash (≥700 ms), re-pintado solo con
   cambio significativo, descarte de obsoletos, cola acotada (catch-up).
5. El módulo emite `onSubtitle` → `CinemaContext` → `SubtitleView` (máx 2 líneas equilibradas).

## Concurrency y ciclo de vida (reglas)

- Una sola sesión activa: `startSession` con sesión en curso = error tipado.
- `stopSession()` debe cancelar Tasks (transcripción, traducciones pendientes, tick),
  retirar el tap de audio, desactivar la sesión de audio y liberar estabilizador/scheduler.
- Sin polling agresivo: el tick del estabilizador/scheduler a ~20 Hz como máximo.
- Interrupciones (llamada, cambio de ruta Bluetooth, background): pausa o parada limpia
  con evento `onStatusChanged`; nunca dejar la UI en "Loading..." eterno.

## Privacidad (diseño fijo)

- Audio: RAM → modelo → descartar. Sin ficheros de audio jamás.
- `Logger` solo emite eventos y números; está prohibido loguear texto transcrito/traducido.
- Sin analytics, sin crash reports con contenido, sin persistencia local.
- Verificación de privacidad prevista en QA (inspección de sandbox tras sesión).

## Decisiones versionadas

Ver `docs/DECISIONS.md` (D-001…D-010). APIs exactas de Apple y disponibilidad:
`docs/research/APPLE_APIS.md` (Wave 1).

## Estrategia de builds

- Desarrollo local Windows: Metro (`pnpm start`) + development client instalado por EAS.
- Cambios TS/UI: sin rebuild nativo. Cambios Swift/config: nuevo build EAS agrupado.
- Antes de cada build: `pnpm typecheck && pnpm test` + revisión nativa.
