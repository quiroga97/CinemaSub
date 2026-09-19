# DECISIONS — Registro de decisiones de arquitectura

Formato ADR resumido. Cada decisión incluye contexto y consecuencia.
Versiones y APIs exactas verificadas el 2026-09-19 contra documentación oficial viva
(`docs/research/APPLE_APIS.md` y `docs/research/EXPO_EAS.md`).

---

## D-001 — Todo el pipeline crítico en Swift

**Decisión:** micrófono → transcripción → estabilización → traducción → programación de
subtítulos viven íntegramente en Swift dentro de `modules/cinema-native/ios/`. React Native
recibe únicamente eventos ligeros (`SubtitleEvent`, métricas, estados).

**Motivo:** latencia y estabilidad. Enviar PCM por el bridge JS genera copias, GC y
pérdidas de buffers. El STT en TypeScript está prohibido por el master prompt.

**Consecuencia:** los cambios de pipeline exigen build EAS (agruparlos). El contrato
(`modules/cinema-native/src/index.ts`) es la única superficie visible para JS.

---

## D-002 — Motor de STT: SpeechAnalyzer + SpeechTranscriber (API FINAL modular)

**Decisión:** transcripción en vivo con el stack moderno del framework Speech:

```swift
SpeechTranscriber(locale:, transcriptionOptions: [], reportingOptions: [.volatileResults, .fastResults],
                  attributeOptions: [.audioTimeRange])
SpeechAnalyzer(modules: [transcriber])
analyzer.start(inputSequence: AsyncStream<AnalyzerInput>)
for try await result in transcriber.results { ... }   // Result: text, isFinal, range
```

**Hallazgo crítico verificado:** el patrón de las betas de junio 2025
(`SpeechTranscriber(audioEngine:)`, `SpeechTranscriber.Request`, `shouldReportPartialResults`,
`SpeechAnalyzer(root:)`) **no existe en la API final** — produce errores 404 en la
documentación oficial y no compila. Está prohibido copiar código de tutoriales de 2025.

**Consecuencia:** deployment target iOS 26.0 mínimo absoluto (ver D-011: 26.4).

---

## D-003 — Traducción: Apple Translation framework, on-device

**Decisión:** `TranslationSession(installedSource: "en", target: "es", preferredStrategy: .lowLatency)`
programática (sin SwiftUI), reutilizable para toda la película. `translate(_:)` por segmento,
cancelable por Task. Sin APIs cloud.

**Motivo:** privacidad + modo avión (requisito del MVP). `.lowLatency` usa los modelos
tradicionales, más rápidos — la elección correcta para subtítulos en vivo.

**Consecuencia:** el par EN→ES debe estar instalado ANTES de iniciar sesión
(pantalla «Preparar modo offline»); `init(installedSource:)` lanza error si falta.

---

## D-004 — Versiones del stack (fijadas el 2026-09-19)

| Componente | Versión | Notas |
|---|---|---|
| Expo SDK | 57.0.24 | Última estable (2026-06-30); expo-doctor 21/21 |
| React Native | 0.86.3 | Pin del SDK 57; New Arch obligatoria (sin opt-out) |
| React | 19.2.3 | Pin del SDK 57 |
| TypeScript | ~6.0.3 | strict |
| Node | 24.14.1 (LTS) | Entorno Windows (mínimo 22.13) |
| pnpm | 12.4.2 | Modo aislado, soportado desde SDK 54; sin .npmrc |
| iOS deployment target | **26.4** | Propiedad integrada `expo.ios.deploymentTarget` (ver D-011) |
| Xcode en EAS | 26.6 | Imagen `macos-tahoe-26.5-xcode-26.6` fijada en eas.json |
| Navegación | expo-router 57.0.22 | `/`, `/cinema`, `/settings` |
| Tests TS | vitest 3.x | Solo lógica pura (D-009) |

---

## D-005 — Estabilizador determinista con ventana de 350 ms (inicial, a medir)

**Decisión:** `TranscriptStabilizer` sin timers internos (ingest + tick con reloj inyectado,
20 Hz). Ventana inicial de estabilidad: **350 ms**. Punto de partida, no valor final.

**Motivo:** testeable y sin race conditions. El master prompt exige medir 250/350/500/700 ms
en dispositivo antes de fijar el valor definitivo (experimento pendiente, ver STATUS).

---

## D-006 — Dos niveles de subtítulo (fast/final) con re-pintado selectivo

**Decisión:** candidato estable (volatile que no cambia en la ventana) → traducción rápida
(subtítulo "fast"). Segmento `isFinal` → traducción definitiva que SOLO re-pinta si el texto
normalizado difiere (`isSignificantChange`: puntuación/caso/espacios no cuentan).
Anti-flash en scheduler: mínima permanencia 700 ms. Misma ID de segmento (basada en el
timestamp de audio) para que el final sustituya al fast en cola.

---

## D-007 — Scheduler con política de "ponerse al día"

**Decisión:** cola acobada (3). Si el pipeline se retrasa, se descartan segmentos antiguos
antes que acumular conversación obsoleta. Retraso manual (−2…+4 s) aplicado en el scheduler.
Traducción pendiente anterior se CANCELA al llegar un candidato más nuevo (contador en métricas).

---

## D-008 — Brillo y keep-awake con módulos Expo oficiales

**Decisión:** `expo-brightness` (guardar brillo al entrar en Cinema Mode, aplicar ~6%,
restaurar al salir/parar — iOS no tiene restore automático) y `expo-keep-awake`
(`useKeepAwake` montado en CinemaScreen). Sin Swift propio para esto.

---

## D-009 — Tests TS con Vitest (solo lógica pura)

**Decisión:** vitest en entorno node para utilidades puras (`src/utils`). La lógica crítica
de pipeline está en Swift; sus tests unitarios se ejecutarán en CI macOS (pendiente) porque
en Windows no hay toolchain iOS.

---

## D-010 — Sin persistencia de ningún tipo en el MVP

**Decisión:** nada de audio, transcripciones ni historial en disco. Sin cuentas, backend,
analytics ni bases de datos. Los ajustes viven en memoria de sesión.

---

## D-011 — Deployment target iOS 26.4 (no 26.0)

**Decisión:** `expo.ios.deploymentTarget = "26.4"` en app.json (propiedad integrada del SDK 56+;
la de `expo-build-properties` está deprecada — plugin eliminado del proyecto).

**Motivo:** 26.2 añade `AVAudioSession.CategoryOptions.farFieldInput` (clave para voz lejana
en sala de cine) y 26.4 añade `TranslationSession.Strategy` (lowLatency/highFidelity).
Con 26.4 no hacen falta escalones `#available`. El dispositivo objetivo es un iPhone moderno
con iOS 27; perder iOS 26.0–26.3 es aceptable.

**Mecanismo:** NO usar expo-build-properties para el target (deprecado).

---

## D-012 — Sesión de audio: .record + .measurement + farFieldInput

**Decisión:** `setCategory(.record, mode: .measurement, options: [.allowBluetooth, .farFieldInput])`.
`farFieldInput` es la señal oficial del sistema para micrófono de campo lejano (iOS 26.2+).
`.measurement` desactiva el procesado pensado para voz cercana; **A/B contra `.default`
pendiente de medir en sala real** (sin guía pública de Apple para este caso).

---

## D-013 — Bootstrap de descarga del pack EN→ES vía flujo SwiftUI auxiliar

**Decisión:** `TranslationModelManager.requestInstallIfNeeded()` presenta una vista auxiliar
invisible con `.translationTask(source:target:)` + `session.prepareTranslation()`, que dispara
la UI de consentimiento del sistema. Timeout de seguridad de 3 minutos.

**Motivo:** limitación OFICIAL verificada — no existe API programática con progreso para
descargar packs de Translation; `prepareTranslation()` requiere un contexto de sesión que
solo el modificador SwiftUI proporciona. El modelo de speech SÍ tiene descarga programática
con progreso (AssetInventory), y esa vía se usa para EN.

**Consecuencia:** la primera preparación muestra un diálogo del sistema (una vez); después
todo es programático y offline.

---

## D-014 — reportingOptions: [.volatileResults, .fastResults] en modo low

**Decisión:** en `latencyMode == "low"` se piden volátiles + `fastResults` (sesgo hacia
capacidad de respuesta). El estabilizador y el correctivo final mitigan la menor precisión.
En modo "high" se pediría solo `.volatileResults`.

---

## D-015 — Imagen EAS fijada: macos-tahoe-26.5-xcode-26.6

**Decisión:** todos los perfiles de eas.json fijan `"image": "macos-tahoe-26.5-xcode-26.6"`
(Xcode 26.6 = alias `latest`/`sdk-57` hoy). Reproducibilidad frente al alias `auto`.

---

## D-016 — Foreground-only: stop limpio al backgroundear

**Decisión:** la app no declara `UIBackgroundModes`. En `OnAppEntersBackground` el pipeline
se detiene de forma segura (tap fuera, analyzer finalizado, sesión de audio desactivada,
Tasks canceladas) y el estado pasa a `stopped`. Sin grabación oculta.

**Motivo:** el master prompt lo exige (app diseñada para primer plano visible) y el
comportamiento de SpeechAnalyzer en background no está prometido oficialmente.

---

## Pendientes de decisión (tras mediciones en dispositivo)

- [ ] Ventana óptima del estabilizador (250–700 ms) — experimento con Developer HUD.
- [ ] `.measurement` vs `.default` para voz lejana — A/B en sala real.
- [ ] `.fastResults` on/off — comparar precisión vs latencia con métricas reales.
- [ ] Validar en dispositivo si SpeechAnalyzer realmente NO requiere
      `NSSpeechRecognitionUsageDescription` (evidencia oficial apunta a que solo micro).
- [ ] `AssetInstallationRequest.progress` (Foundation.Progress) — verificar en headers
      del SDK durante el primer build (riesgo nº6 del research).
