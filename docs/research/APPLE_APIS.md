# APPLE_APIS.md — Investigación de APIs Apple para CinemaSubs

**Fecha de verificación:** 2026-09-19.
**Método:** consulta directa de la documentación oficial de Apple (`developer.apple.com/documentation/...` vía endpoint JSON de datos de DocC, que es el mismo contenido que renderiza la web), sesión WWDC25 277 y sample code oficial de Apple. Todo lo que sigue fue verificado contra fuentes vivas en la fecha indicada; las afirmaciones de terceros se marcan como tales.

**Contexto de versiones:** iOS 26.0 se lanzó en septiembre de 2025. A la fecha existen iOS 26.x (incluido 26.2 y 26.4, marzo de 2026) e iOS 27 (WWDC26, junio de 2026). La disponibilidad exacta por símbolo se indica en cada sección y en la tabla resumen.

> **Hallazgo crítico nº 1 (cambia el plan del proyecto):** el patrón `SpeechTranscriber(audioEngine:)` + `SpeechTranscriber.Request` + `shouldReportPartialResults` + `SpeechAnalyzer(root:)` que se mostró en las primeras betas de iOS 26 (junio 2025) **ya no existe en la API final**. La API que se envió (y que sigue vigente en iOS 27) es modular: `SpeechTranscriber` es un *módulo* que se pasa a `SpeechAnalyzer(modules:options:)`, los resultados se consumen por `AsyncSequence` (`transcriber.results`) y el audio se entrega como `AnalyzerInput` (verificado en la referencia actual: los únicos inicializadores documentados de `SpeechTranscriber` son `init(locale:preset:)` e `init(locale:transcriptionOptions:reportingOptions:attributeOptions:)`, ambos iOS 26.0+). No existe `SpeechTranscriber.Request` ni `shouldReportPartialResults` en la API final (404 en la documentación oficial).

---

## (a) Tabla resumen de APIs elegidas y disponibilidad

| API | Uso en CinemaSubs | Disponibilidad (iOS) | Fuente |
|---|---|---|---|
| `SpeechAnalyzer` (actor) + `init(modules:options:)` | Orquesta la transcripción en vivo | **26.0** | [SpeechAnalyzer](https://developer.apple.com/documentation/speech/speechanalyzer) |
| `SpeechTranscriber` + `init(locale:preset:)` | Módulo de transcripción EN | **26.0** | [SpeechTranscriber](https://developer.apple.com/documentation/speech/speechtranscriber) |
| `SpeechTranscriber.Preset.progressiveTranscription` / `.timeIndexedProgressiveTranscription` | Resultados inmediatos (volátiles) para subtítulos | **26.0** | [Preset](https://developer.apple.com/documentation/speech/speechtranscriber/preset) |
| `ReportingOption` (`.volatileResults`, `.fastResults`, `.alternativeTranscriptions`) | Entrega parcial + baja latencia | **26.0** | [ReportingOption](https://developer.apple.com/documentation/speech/speechtranscriber/reportingoption) |
| `ResultAttributeOption.audioTimeRange` / `.transcriptionConfidence` | Timestamps por palabra | **26.0** | [ResultAttributeOption](https://developer.apple.com/documentation/speech/speechtranscriber/resultattributeoption) |
| `transcriber.results` (`AsyncSequence` de `SpeechTranscriber.Result`) | Streaming de subtítulos | **26.0** | [results](https://developer.apple.com/documentation/speech/speechtranscriber/results) |
| `Result.text: AttributedString`, `isFinal`, `range: CMTimeRange` | Texto final vs volátil + sincronización | **26.0** | [Result](https://developer.apple.com/documentation/speech/speechtranscriber/result), [isFinal](https://developer.apple.com/documentation/speech/speechmoduleresult/isfinal) |
| `SpeechTranscriber.isAvailable` / `installedLocales` / `supportedLocales` | Chequeos estáticos de dispositivo/idioma | **26.0** | [isAvailable](https://developer.apple.com/documentation/speech/speechtranscriber/isavailable) |
| `AssetInventory.assetInstallationRequest(supporting:)` + `AssetInstallationRequest.downloadAndInstall()` | Pre-descarga del modelo de inglés | **26.0** | [AssetInventory](https://developer.apple.com/documentation/speech/assetinventory) |
| `AssetInventory.status(forModules:)` / `.Status` (`installed/downloading/supported/unsupported`) | Estado de descarga | **26.0** | [Status](https://developer.apple.com/documentation/speech/assetinventory/status) |
| `AssetInventory.reserve(locale:)` / `release(reservedLocale:)` | Reservar modelos descargados | **26.0** | [reserve](https://developer.apple.com/documentation/speech/assetinventory/reserve(locale:)) |
| `SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith:)` | Formato de entrada óptimo | **26.0** | [bestAvailableAudioFormat](https://developer.apple.com/documentation/speech/speechanalyzer/bestavailableaudioformat(compatiblewith:)) |
| `AnalyzerInput(buffer:)` / `AnalyzerInput(buffer:bufferStartTime:)` | Alimentar audio desde el tap | **26.0** | [AnalyzerInput](https://developer.apple.com/documentation/speech/analyzerinput) |
| `DictationTranscriber` (módulo fallback) | Dispositivos sin Apple Intelligence | **26.0** | [DictationTranscriber](https://developer.apple.com/documentation/speech/dictationtranscriber) |
| `SpeechDetector` (VAD) | Opcional: detectar voz vs música/ruido | **26.0** | [SpeechDetector](https://developer.apple.com/documentation/speech/speechdetector) |
| `AVAudioApplication.requestRecordPermission()` | Permiso de micrófono (moderno) | **17.0** | [requestRecordPermission](https://developer.apple.com/documentation/avfaudio/avaudioapplication/requestrecordpermission(completionhandler:)) |
| `AVAudioSession.setCategory(_:mode:options:)` | Sesión de audio para captura | 10.0 | [setCategory](https://developer.apple.com/documentation/avfaudio/avaudiosession/setcategory(_:mode:options:)) |
| `AVAudioSession.CategoryOptions.farFieldInput` | Captura de campo lejano (altavoces de la sala) | **26.2** | [farFieldInput](https://developer.apple.com/documentation/avfaudio/avaudiosession/categoryoptions-swift.struct/farfieldinput) |
| `TranslationSession.init(installedSource:target:)` | Sesión de traducción programática (sin SwiftUI) | **26.0** | [init(installedSource:target:)](https://developer.apple.com/documentation/translation/translationsession/init(installedsource:target:)) |
| `TranslationSession.translate(_ string: String) -> Response` | Traducir segmento | **18.0** | [translate(_:)](https://developer.apple.com/documentation/translation/translationsession/translate(_:)-4m20l) |
| `TranslationSession.translate(_ string: AttributedString)` | Traducir texto con formato | **26.4** | [translate(_:)](https://developer.apple.com/documentation/translation/translationsession/translate(_:)-59zi2) |
| `TranslationSession.Strategy` (`.lowLatency` / `.highFidelity`) | Estrategia latencia vs calidad | **26.4** | [Strategy](https://developer.apple.com/documentation/translation/translationsession/strategy) |
| `init(installedSource:target:preferredStrategy:)` | Sesión programática con estrategia | **26.4** | [init](https://developer.apple.com/documentation/translation/translationsession/init(installedsource:target:preferredstrategy:)) |
| `LanguageAvailability` + `status(from:to:)` | Estado instalado del par EN→ES | **18.0** (`init(preferredStrategy:)`: 26.4) | [LanguageAvailability](https://developer.apple.com/documentation/translation/languageavailability) |
| `TranslationSession.prepareTranslation()` | Pedir al usuario descargar idiomas | **18.0** | [prepareTranslation()](https://developer.apple.com/documentation/translation/translationsession/preparetranslation()) |
| `TranslationSession.canRequestDownloads` / `isReady` / `cancel()` | Gestión de la sesión | **26.0** | [TranslationSession](https://developer.apple.com/documentation/translation/translationsession) |
| `CaptureInputSequenceProvider` (reemplazo del tap manual) | Captura integrada con el analyzer | **27.0** | [CaptureInputSequenceProvider](https://developer.apple.com/documentation/speech/captureinputsequenceprovider) |
| `AVAudioSession.interruptionNotification` / `routeChangeNotification` | Interrupciones / cambios de ruta | 6.0 (**deprecado en 27.0**; nuevos tipos `DidBecomeActiveMessage`, etc.) | [interruptionNotification](https://developer.apple.com/documentation/avfaudio/avaudiosession/interruptionnotification) |

**Conclusión de deployment target:** el mínimo absoluto es **iOS 26.0** (SpeechAnalyzer + TranslationSession programático + AssetInventory). Para usar `farFieldInput` se requiere **iOS 26.2** y para `TranslationSession.Strategy`/`translate(AttributedString)` se requiere **iOS 26.4**. Recomendación: target **iOS 26.0** con `if #available(iOS 26.2/26.4, *)` para las mejoras, o target 26.4 si se acepta perder dispositivos.

---

## (b.1) SpeechAnalyzer + SpeechTranscriber — transcripción en vivo (iOS 26.0+)

### Arquitectura de la API final (modular)

- `SpeechAnalyzer` es un **actor final** (`final actor SpeechAnalyzer`): gestiona la sesión de análisis y el pipeline de módulos. Documentación: <https://developer.apple.com/documentation/speech/speechanalyzer>.
- `SpeechTranscriber` es un módulo (`final class SpeechTranscriber`, conforme a `SpeechModule`): <https://developer.apple.com/documentation/speech/speechtranscriber>.
- El audio se entrega como `AnalyzerInput` (elemento "time-coded audio data") a través de cualquier `AsyncSequence` cuyo elemento sea `AnalyzerInput`: <https://developer.apple.com/documentation/speech/analyzerinput>.

### Patrón recomendado (verificado en WWDC25 sesión 277 + docs actuales)

```swift
import Speech
import AVFAudio

// 1) Crear el módulo transcriptor para el idioma deseado (EN para CinemaSubs).
//    Preset para vivo: .progressiveTranscription (volátil sin timestamps)
//    o .timeIndexedProgressiveTranscription (volátil + timecodes).
let transcriber = SpeechTranscriber(
    locale: Locale(identifier: "en-US"),
    transcriptionOptions: [],                    // p.ej. [.etiquetteReplacements]
    reportingOptions: [.volatileResults],        // parciales (volátiles) + finales
    attributeOptions: [.audioTimeRange]          // timestamps por run de texto
)

// 2) Crear el analyzer con el módulo.
let analyzer = SpeechAnalyzer(modules: [transcriber])
// Declaración exacta: convenience init(modules: [any SpeechModule], options: SpeechAnalyzer.Options? = nil)

// 3) Formato óptimo soportado por el modelo instalado.
guard let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
    throw SetupError.noCompatibleFormat
}

// 4) Canal de entrada (iOS 26: lo construye la app; ver §(b.5) para iOS 27).
let (inputSequence, inputContinuation) = AsyncStream<AnalyzerInput>.makeStream()

// 5) Arrancar el análisis (start devuelve inmediatamente; analyzeSequence bloquea hasta el fin).
try await analyzer.start(inputSequence: inputSequence)
// Declaración exacta:
// final func start<InputSequence>(inputSequence: InputSequence) async throws
//   where InputSequence : Sendable, InputSequence : AsyncSequence, InputSequence.Element == AnalyzerInput

// 6) Consumir resultados.
for try await result in transcriber.results {
    // result.text es AttributedString; result.isFinal indica si ya es definitivo.
    if result.isFinal {
        finalTranscript.append(result.text)
        volatileTranscript = AttributedString()
    } else {
        volatileTranscript = result.text
    }
}

// 7) Parada limpia: terminar la secuencia de entrada y finalizar.
inputContinuation.finish()
try await analyzer.finalizeAndFinishThroughEndOfInput()
```

Alternativa a `start`: `analyzeSequence(_:)` (`final func analyzeSequence<InputSequence>(_ inputSequence: InputSequence) async throws -> CMTime?`) corre hasta que la secuencia termina y devuelve el último tiempo consumido; es la que usa el sample oficial de Apple.

**Dónde arranca el audio engine:** en iOS 26 la app es dueña del `AVAudioEngine`, instala el tap en `inputNode` (bus 0) y hace `engine.prepare()` + `engine.start()`; el tap convierte el buffer al `analyzerFormat` y hace `inputContinuation.yield(AnalyzerInput(buffer: convertido))`. En el sample WWDC25 el orden es: permiso de micro → `AVAudioSession` activa → crear transcriber/analyzer → `start(inputSequence:)` → `engine.start()`. En iOS 27 esto lo reemplaza `CaptureInputSequenceProvider` (ver §(b.5)).

### Resultados parciales vs finales

- Tipo entregado: `SpeechTranscriber.Result` (struct), en orden, vía `transcriber.results` (`final var results: some Sendable & AsyncSequence<SpeechTranscriber.Result, any Error> { get }`).
- Propiedades:
  - `var text: AttributedString` — "la interpretación más probable del audio en este rango".
  - `let alternatives: [AttributedString]` — solo si `.alternativeTranscriptions`; en orden descendente de probabilidad.
  - `var range: CMTimeRange` (heredado de `SpeechModuleResult`) — rango de audio al que aplica el resultado.
  - `var isFinal: Bool` — "si este resultado es final en el momento en que se produce" (`SpeechModuleResult.isFinal`).
  - `resultsFinalizationTime` (heredado).
- **Volatile vs final:** con `.volatileResults` el módulo emite primero resultados tentativos (`isFinal == false`) para un rango de audio y luego el resultado refinado/final (`isFinal == true`) para ese mismo rango. El sample oficial de Apple describe dos técnicas:
  1. Dos buffers separados: `finalTranscript` (solo se añade con `isFinal`) + `volatileTranscript` (se sustituye entero con cada volátil); lo mostrado = final + volátil actual (técnica del código-along de WWDC25).
  2. Un solo `AttributedString` maestro: usar `transcript.rangeOfAudioTimeRangeAttributes(intersecting: result.range)` para reemplazar solo el tramo de texto cuyo timecode coincide con el nuevo resultado (técnica del sample iOS 27).
- Timestamps: el atributo `audioTimeRange` (`AttributeScopes.SpeechAttributes.TimeRangeAttribute`) se adjunta por run dentro del `AttributedString`; confianza con `.transcriptionConfidence`.

### Opciones/presets relevantes para vivo

- `SpeechTranscriber.Preset`:
  - `.transcription` — "básica y precisa".
  - `.transcriptionWithAlternatives`, `.timeIndexedTranscriptionWithAlternatives`.
  - **`.progressiveTranscription`** — "transcripción inmediata de audio en vivo".
  - **`.timeIndexedProgressiveTranscription`** — ídem, "cross-referenced to stream time-codes" (la elegida para subtítulos).
- `ReportingOption`: `.volatileResults` (tentativos + final), `.fastResults` ("sesga hacia capacidad de respuesta: más rápido pero menos preciso"), `.alternativeTranscriptions`.
- `TranscriptionOption`: `.etiquetteReplacements` (útil para limpiar tacos en el audio de películas).
- `SpeechAnalyzer.Options`: `init(priority: TaskPriority, modelRetention: SpeechAnalyzer.Options.ModelRetention)` — `ModelRetention` = `.whileInUse` / `.processLifetime` / `.lingering` (estrategia de caché del modelo).
- Restricción de idiomas: no existe un parámetro "supportedLocales" en el request; la restricción se hace chequeando `SpeechTranscriber.supportedLocales` / `installedLocales` antes de crear el módulo, y creando el módulo con el `Locale` devuelto por `supportedLocale(equivalentTo:)`.

### Chequeos estáticos

```swift
// ¿El hardware soporta SpeechTranscriber? (estático, síncrono)
guard SpeechTranscriber.isAvailable else { /* usar DictationTranscriber */ }

// Idiomas instalados (solo los presentes en el dispositivo)
let installed: [Locale] = await SpeechTranscriber.installedLocales
// Idiomas soportados (incluye descargables)
let supported: [Locale] = await SpeechTranscriber.supportedLocales
// Equivalente canónico de un locale pedido por el usuario
let canon = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: "en-US"))
```

Declaraciones exactas: `static var isAvailable: Bool { get }`; `static var installedLocales: [Locale] { get async }`; `static var supportedLocales: [Locale] { get async }`; `static func supportedLocale(equivalentTo locale: Locale) async -> Locale?`.

### Errores a manejar

- La nueva API **no define un enum de error propio** (no existe `SpeechAnalyzerError`; el único enum de error del framework es `SFSpeechError`/`SFSpeechErrorCode`, que pertenece a la API legacy). Manejar `Error` genérico y `CancellationError` (aparece al cancelar la tarea que consume `results`).
- `AssetInventory.assetInstallationRequest(supporting:)` y `downloadAndInstall()` lanzan errores de red/instalación.
- En Translation sí existe `TranslationError` (ver §(b.4)).

Fuentes principales: [SpeechAnalyzer](https://developer.apple.com/documentation/speech/speechanalyzer) · [SpeechTranscriber](https://developer.apple.com/documentation/speech/speechtranscriber) · [SpeechTranscriber.Result](https://developer.apple.com/documentation/speech/speechtranscriber/result) · [SpeechModuleResult](https://developer.apple.com/documentation/speech/speechmoduleresult) · [artículo "Bringing advanced speech-to-text capabilities to your app"](https://developer.apple.com/documentation/speech/bringing-advanced-speech-to-text-capabilities-to-your-app) · [WWDC25 sesión 277 "Bring advanced speech-to-text to your app with SpeechAnalyzer"](https://developer.apple.com/videos/play/wwdc2025/277/) · [sample "Recognizing speech in live audio"](https://developer.apple.com/documentation/speech/recognizing-speech-in-live-audio).

---

## (b.2) Pre-descarga del modelo de inglés (AssetInventory, iOS 26.0+)

API exacta (todo iOS/macOS 26.0+):

```swift
// ¿Hay algo que descargar para este módulo? nil = ya está todo instalado.
let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber])
// static func assetInstallationRequest(supporting modules: [any SpeechModule]) async throws -> AssetInstallationRequest?

// Estado por módulo (sin descarga):
let status = await AssetInventory.status(forModules: [transcriber])
switch status {           // AssetInventory.Status
case .installed:    break // listo
case .downloading:  break // descarga en curso ( iniciada por otra app / sistema)
case .supported:    break // descargable pero no instalado
case .unsupported:  break // ni siquiera soportado en este dispositivo
}

// Descargar + instalar:
if let request {
    // progreso (Foundation.Progress) — así lo muestra el código del WWDC25 (session 277):
    progressView.observedProgress = request.progress
    try await request.downloadAndInstall()   // final func downloadAndInstall() async throws
}
```

Notas oficiales:

- "El sistema consolida las peticiones de descarga e instalación; puedes obtener varias instancias y llamar `downloadAndInstall()` varias veces sin causar descargas redundantes" ([AssetInstallationRequest](https://developer.apple.com/documentation/speech/assetinstallationrequest)).
- **Reservas** (evita que el sistema expulse los modelos descargados cuando hay presión de recursos; límite `maximumReservedLocales`):
  - `static func reserve(locale: Locale) async throws -> Bool` — "añade un locale de assets a las reservas actuales de la app".
  - `static func release(reservedLocale: Locale) async -> Bool`.
  - `static var reservedLocales` / `static var maximumReservedLocales: Int { get }`.
  - Ojo: el código de la sesión WWDC25 usaba los nombres de beta `allocatedLocales` / `deallocate(locale:)`; **los nombres que se enviaron son `reserve`/`release`/`reservedLocales`** (verificado en la referencia oficial).
- Los modelos "corren en el dispositivo pero fuera del espacio de memoria de tu app", no engordan el binario y se actualizan vía sistema (WWDC25 277).

Para CinemaSubs: en el primer arranque con conexión, chequear `status(forModules:)` y ejecutar `downloadAndInstall()` para `en-US` **antes** de ir al cine; mantener `AssetInventory.reserve(locale: enUS)` activo durante el uso de la app.

---

## (b.3) Permisos requeridos por SpeechAnalyzer en vivo (iOS 26+)

**Conclusión: solo permiso de micrófono (`NSMicrophoneUsageDescription`). No se requiere autorización de reconocimiento de voz (`NSSpeechRecognitionUsageDescription` / `SFSpeechRecognizer.requestAuthorization`) para la nueva API**, según toda la evidencia oficial disponible:

1. El código-along oficial de la sesión WWDC25 277 solo pide permiso de audio antes de arrancar la sesión (función `record()` → `isAuthorized()` de micrófono + `setUpAudioSession()`); no aparece ninguna llamada a `SFSpeechRecognizer.requestAuthorization` en toda la sesión, y la justificación explícita del diseño es la privacidad: "mantuvimos el discurso privado… nuestro nuevo modelo on-device logra todo eso".
2. El sample oficial actual de Apple ("Recognizing speech in live audio") pide permiso únicamente con `AVCaptureDevice.requestAccess(for: .audio)` y lanza `TranscriptionError.micPermissionDenied` si se deniega; no hay ninguna clave ni llamada de speech-recognition.
3. El artículo oficial ["Asking Permission to Use Speech Recognition"](https://developer.apple.com/documentation/speech/asking-permission-to-use-speech-recognition) (que exige `NSSpeechRecognitionUsageDescription` + `SFSpeechRecognizer.requestAuthorization`) habla explícitamente de reconocimiento **que envía el audio a los servidores de Apple** — el flujo legacy de `SFSpeechRecognizer`. No menciona `SpeechAnalyzer` en su cuerpo (solo como "see also").

API moderna de permiso de micro (iOS 17+, preferible a la deprecada `AVAudioSession.requestRecordPermission`):

```swift
let granted = await AVAudioApplication.requestRecordPermission()   // class func ... () async -> Bool
let status = AVAudioApplication.recordPermission                   // .undetermined/.granted/.denied
```

Fuentes: [AVAudioApplication.requestRecordPermission](https://developer.apple.com/documentation/avfaudio/avaudioapplication/requestrecordpermission(completionhandler:)) · [AVAudioApplication](https://developer.apple.com/documentation/avfaudio/avaudioapplication) · [Asking Permission to Use Speech Recognition](https://developer.apple.com/documentation/speech/asking-permission-to-use-speech-recognition).

**Advertencia práctica (riesgo residual):** varias guías de terceros (picovoice.ai, tutoriales de 2025) recomiendan incluir *ambas* claves en Info.plist. No existe declaración oficial de Apple que diga que la nueva API lee `NSSpeechRecognitionUsageDescription`; la evidencia oficial apunta a que no la necesita. Mitigación: incluir igualmente `NSSpeechRecognitionUsageDescription` es inofensivo (nunca se muestra el prompt si nadie llama a `requestAuthorization`) y protege si se añade un fallback con `SFSpeechRecognizer` legacy. **Pendiente: probar en dispositivo físico sin la clave.**

---

## (b.4) Translation framework programático (sin SwiftUI)

### Crear sesión y traducir

```swift
import Translation

// Chequear estado del par EN -> ES (iOS 18+):
let availability = LanguageAvailability()
let status = await availability.status(from: Locale.Language(identifier: "en"), to: Locale.Language(identifier: "es"))
// enum LanguageAvailability.Status { case installed, supported, unsupported }

// Sesión PROGRAMÁTICA sin UI (iOS 26+). LANZA error si los idiomas NO están instalados.
let session = try TranslationSession(
    installedSource: Locale.Language(identifier: "en"),
    target: Locale.Language(identifier: "es")
)
// Declaración exacta: convenience init(installedSource source: Locale.Language, target: Locale.Language?)
// Texto oficial: "Another way, for contexts where there's no UI, you can directly initialize the
// TranslationSession using init(installedSource:target:) ... throws an error if the languages
// aren't already installed on the person's device."

// Con estrategia (iOS 26.4+):
let session2 = try TranslationSession(
    installedSource: Locale.Language(identifier: "en"),
    target: Locale.Language(identifier: "es"),
    preferredStrategy: .lowLatency        // o .highFidelity
)

// Traducir un segmento (String, iOS 18+):
let response = try await session.translate("Leave now, and never come back!")
let subtitleES = response.targetText      // TranslationSession.Response

// Variantes:
//   func translate(_ string: AttributedString) async throws -> TranslationSession.Response   (iOS 26.4+)
//   func translate(batch: [TranslationSession.Request]) -> TranslationSession.BatchResponse  (iOS 18+, no async)
//   func translations(from:) — secuencia de respuestas
```

`Response` expone `sourceText`, `targetText`, `attributedSourceText`, `attributedTargetText`, `sourceLanguage`, `targetLanguage`, `clientIdentifier`.

### Estrategias de latencia/calidad — CONFIRMADAS (iOS 26.4+)

- `struct TranslationSession.Strategy` — "el modelo preferido para manejar traducciones en tu app".
  - `static let lowLatency` — "traducciones rápidas usando modelos tradicionales".
  - `static let highFidelity` — "traducciones más fluidas usando Apple Intelligence".
- Disponibles en: `init(installedSource:target:preferredStrategy:)`, `TranslationSession.Configuration.preferredStrategy` / `init(source:target:preferredStrategy:)`, y `LanguageAvailability.init(preferredStrategy:)`. **Todas iOS 26.4** (macOS 26.0). Para subtítulos en vivo: `.lowLatency` (y los modelos "tradicionales" son además los que ya están instalados por defecto).

### Descarga de paquetes de idiomas y estado

- Estado: `LanguageAvailability().status(from:to:)` → `.installed` / `.supported` (soportado pero hay que descargarlo) / `.unsupported`. También `status(for:to:)` (detecta idioma fuente desde texto de muestra).
- Descarga: **la única vía documentada es `TranslationSession.prepareTranslation()` (iOS 18+)**: "puedes pedirle a la persona que descargue esos idiomas por adelantado llamando a este método… el framework pide permiso para descargar el idioma fuente y objetivo; si ya están instalados o descargándose, retorna sin preguntar".
- `TranslationSession.canRequestDownloads` (iOS 26.0, `Bool`) — indica si *esa* sesión puede pedir descargas; `isReady` (iOS 26.0, `async Bool`) — "el sistema ya instaló los idiomas fuente y objetivo y está listo".
- **No existe API pública de descarga con progreso** para paquetes de Translation (equivalente al `AssetInventory`/`AssetInstallationRequest.progress` de Speech): la descarga la maneja el sistema con su propia UI. Ausencia confirmada repasando todos los símbolos del framework Translation en la referencia oficial.
- Restricción importante del flujo 100% programático: como `init(installedSource:target:)` lanza error si el par no está instalado, el *bootstrap* de la primera descarga EN→ES debe hacerse (a) con un flujo SwiftUI auxiliar (`.translationTask(source:target:)` sobre una vista y `session.prepareTranslation()` dentro del closure), o (b) pidiendo al usuario que instale el idioma en Ajustes → General → Traducción. Después de eso, la vía programática pura funciona siempre.

### Reutilización, cancelación y errores

- Reutilización: sí — la clase está pensada para "traducir una o más líneas de texto a la vez"; un mismo `TranslationSession` acepta múltiples `translate` secuenciales y `translate(batch:)` para colas de segmentos. No hay que recrearla por segmento (recrear solo si cambia la configuración de idiomas; en el flujo SwiftUI eso se hace con `Configuration.invalidate()`).
- `func cancel()` (iOS 26.0) — "intenta detener todo el trabajo en curso de la sesión".
- Errores (`TranslationError`, iOS 18+): `.nothingToTranslate`, `.unableToIdentifyLanguage`, `.internalError`, `.alreadyCancelled`, `.notInstalled`, `.unsupportedSourceLanguage`, `.unsupportedTargetLanguage`, `.unsupportedLanguagePairing`.

Fuentes: [TranslationSession](https://developer.apple.com/documentation/translation/translationsession) · [init(installedSource:target:)](https://developer.apple.com/documentation/translation/translationsession/init(installedsource:target:)) · [Strategy](https://developer.apple.com/documentation/translation/translationsession/strategy) · [lowLatency](https://developer.apple.com/documentation/translation/translationsession/strategy/lowlatency) · [highFidelity](https://developer.apple.com/documentation/translation/translationsession/strategy/highfidelity) · [prepareTranslation()](https://developer.apple.com/documentation/translation/translationsession/preparetranslation()) · [LanguageAvailability](https://developer.apple.com/documentation/translation/languageavailability) · [TranslationError](https://developer.apple.com/documentation/translation/translationerror) · [Configuration](https://developer.apple.com/documentation/translation/translationsession/configuration).

---

## (b.5) AVAudioSession para audio de campo lejano (diálogo de película desde altavoces de sala)

### Recomendación verificada

- El código oficial de WWDC25 277 usa: `setCategory(.playAndRecord, mode: .spokenAudio)` + `setActive(true, options: .notifyOthersOnDeactivation)`. Ese modo `.spokenAudio` está pensado para *reproducción* continua de audio hablado (pausa cuando otra app suena), no aporta nada a la captura.
- Para CinemaSubs (solo captura, sin reproducción):
  - **Categoría `.record`** si la app nunca reproduce audio (evita ambigüedad de altavoz); **`.playAndRecord`** si en el futuro se añade TTS o prueba de nivel. Ambas son categorías de entrada válidas para `farFieldInput`.
  - **Modo:** `.default` (mantiene el procesado de señal del sistema para voz) o `.measurement` ("indica que tu app hace medición de audio" — desactiva el procesado software como el AGC). No hay guía pública de Apple que recomiende un modo concreto para "voz lejana" con SpeechAnalyzer; es un parámetro a A/B-testear en dispositivo. Empezar con `.measurement` (audio lo más crudo posible, sin filtros pensados para voz cercana) y comparar contra `.default`.
  - **Opción clave (iOS 26.2+): `.farFieldInput`** — literal: "Esta opción debería usarse si una sesión prefiere usar FarFieldInput cuando esté disponible. Solo es válida con categorías que soportan entrada — `playAndRecord`, `record`…". Es la señal explícita del sistema para micrófono de campo lejano (p.ej. los mics de cámara trasera en dispositivos soportados).
  - Bluetooth: `.allowBluetooth`/`.allowBluetoothA2DP` si se quiere aceptar micro Bluetooth; `defaultToSpeaker` solo con `.playAndRecord`.

```swift
let session = AVAudioSession.sharedInstance()
var options: AVAudioSession.CategoryOptions = []
if #available(iOS 26.2, *) {
    options.insert(.farFieldInput)     // válido solo con categorías de entrada (.record/.playAndRecord)
}
try session.setCategory(.record, mode: .measurement, options: options)
try session.setActive(true, options: .notifyOthersOnDeactivation)
```

- Interacción con el pipeline: en iOS 26 la app posee el `AVAudioEngine`; SpeechAnalyzer solo consume el `AsyncSequence<AnalyzerInput>`. El tap debe convertir cada `AVAudioPCMBuffer` al formato devuelto por `bestAvailableAudioFormat(compatibleWith:)` antes de construir el `AnalyzerInput` (patrón del sample WWDC25 277 con `AVAudioConverter`).

### Interrupciones (llamada) y cambios de ruta (Bluetooth)

Requisitos oficiales (artículos "Handling audio interruptions" y "Responding to audio route changes"):

```swift
// Interrupciones: observar AVAudioSession.interruptionNotification (iOS 6+; deprecado en iOS 27
// en favor de nuevos tipos de mensajes p.ej. AVAudioSession.DidBecomeActiveMessage).
for await n in NotificationCenter.default.notifications(
    named: AVAudioSession.interruptionNotification,
    object: AVAudioSession.sharedInstance()) {
    guard let info = n.userInfo,
          let raw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
          let type = AVAudioSession.InterruptionType(rawValue: raw) else { continue }
    switch type {
    case .began:  // pausar: parar engine, NO finalizar el analyzer (o sí, según UX)
        audioEngine.stop()
    case .ended:  // reactivar sesión, reinstalar tap con el formato actual, engine.start()
        try? AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
        restartEngineAndTap()
    default: break
    }
}

// Cambios de ruta (conexión/desconexión de Bluetooth/auriculares):
for await n in NotificationCenter.default.notifications(
    named: AVAudioSession.routeChangeNotification) {
    guard let info = n.userInfo,
          let raw = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
          let reason = AVAudioSession.RouteChangeReason(rawValue: raw) else { continue }
    switch reason {
    case .newDeviceAvailable, .oldDeviceUnavailable:
        // El formato de inputNode puede cambiar: quitar tap, releer
        // inputNode.outputFormat(forBus: 0) (y bestAvailableAudioFormat), reinstalar tap.
        restartEngineAndTap()
    default: break
    }
}
```

Notas: al quitar auriculares, iOS interrumpe la sesión por privacidad (hay que reactivarla explícitamente); con Bluetooth el formato de hardware cambia y el tap debe reinstalarse con el formato nuevo o la conversión falla. En iOS 27 `interruptionNotification` aparece marcado **deprecado** (27.0) — los reemplazos aún poco documentados (`AVAudioSession.DidBecomeActiveMessage`, `DidBecomeInactiveMessage`, `ResumptionRecommendationMessage`, `InterruptionContext`, todos iOS 27.0+); `NotificationCenter` sigue funcionando y es lo que muestra el artículo oficial vigente.

Fuentes: [setCategory(_:mode:options:)](https://developer.apple.com/documentation/avfaudio/avaudiosession/setcategory(_:mode:options:)) · [CategoryOptions (con farFieldInput)](https://developer.apple.com/documentation/avfaudio/avaudiosession/categoryoptions-swift.struct) · [Mode](https://developer.apple.com/documentation/avfaudio/avaudiosession/mode-swift.struct) · [Handling audio interruptions](https://developer.apple.com/documentation/avfaudio/handling-audio-interruptions) · [Responding to audio route changes](https://developer.apple.com/documentation/avfaudio/responding-to-audio-route-changes) · [WWDC25 277](https://developer.apple.com/videos/play/wwdc2025/277/).

---

## (b.6) Requisitos de primer plano / ejecución en background

- Regla base oficial: "típicamente una app queda **suspendida** cuando pasa a background" ([Configuring background execution modes](https://developer.apple.com/documentation/xcode/configuring-background-execution-modes)). Sin nada especial, al backgroundear CinemaSubs se detienen el tap del `AVAudioEngine` y el consumo de `results`.
- Con la capability **Background Modes → Audio** (`UIBackgroundModes = [audio]` — "la app reproduce contenido audible o **graba audio** en segundo plano", [UIBackgroundModes](https://developer.apple.com/documentation/bundleresources/information-property-list/uibackgroundmodes)) y una sesión de audio **activa con categoría de entrada** (`.record`/`.playAndRecord`) iniciada en primer plano, el sistema mantiene la app corriendo mientras graba. El sistema la detiene si el audio se detiene, y puede rechazarla en revisión si el modo no es esencial para la experiencia (para CinemaSubs lo es: subtítulos mientras la pantalla está bloqueada/atenuada).
- No hay declaración oficial específica sobre SpeechAnalyzer en background. El modelo corre fuera del proceso de la app y el pipeline se maneja por timecodes de audio, por lo que *debería* seguir transcribiendo mientras la app siga viva y el audio fluya — **riesgo a validar en dispositivo** (ver §(d)).
- Comportamiento recomendado para CinemaSubs:
  1. Declarar `UIBackgroundModes: [audio]`.
  2. Activar la sesión ANTES de backgroundear (la sesión de audio activa es lo que da derecho a seguir corriendo).
  3. Pausa/reactivación explícitas: en `UIApplication.didEnterBackgroundNotification` (si se decide no usar background mode) detener engine + suspender subtítulos; en `willEnterForegroundNotification` reactivar sesión + reinstalar tap. Con background mode, gestionar igualmente `AVAudioApplication.recordPermission` y la interrupción `.wasSuspended` (iOS 17+ interrumpe la grabación al backgroundear si no hay background mode: `AVAudioSessionInterruptionWasSuspendedKey`).
  4. Mantener el `AnalyzerInput` con `bufferStartTime:` correcto tras pausas (es el inicializador "para audio que puede ser discontínuo con la entrada previa").

---

## (b.7) Tabla de deployment target mínimo por API usada

| Necesidad | API | Mínimo iOS |
|---|---|---|
| Transcripción en vivo (todo el pipeline Speech) | `SpeechAnalyzer`, `SpeechTranscriber`, `AnalyzerInput`, `AssetInventory`, `DictationTranscriber`, `SpeechDetector` | **26.0** |
| Descarga previa del modelo EN con progreso | `AssetInventory.assetInstallationRequest` + `downloadAndInstall()` | **26.0** |
| Permiso de micro moderno | `AVAudioApplication.requestRecordPermission()` | 17.0 |
| Sesión de traducción programática EN→ES | `TranslationSession(installedSource:target:)` | **26.0** |
| `translate(String)`, `translate(batch:)`, `LanguageAvailability`, `prepareTranslation()`, `TranslationError` | — | 18.0 |
| Estrategia lowLatency/highFidelity + `translate(AttributedString)` + `init(...preferredStrategy:)` | `TranslationSession.Strategy` | **26.4** |
| Captura de campo lejano (opción de sesión) | `AVAudioSession.CategoryOptions.farFieldInput` | **26.2** |
| Captura integrada sin tap manual / converter | `CaptureInputSequenceProvider`, `AssetInputSequenceProvider`, `AnalyzerInputConverter` | **27.0** |

**Mínimo global para cubrir TODO el plan (salvo providers iOS 27): iOS 26.4.** Mínimo viable con `#available` escalonado: **iOS 26.0**.

---

## (c) Uso exacto recomendado para CinemaSubs

### c.1 Pipeline de habla en vivo (EN) — target iOS 26.0

```swift
import Speech
import AVFAudio

@MainActor
final class LiveTranscriptionEngine {
    private let audioEngine = AVAudioEngine()
    private var analyzer: SpeechAnalyzer?
    private var transcriber: SpeechTranscriber?
    private var analyzerFormat: AVAudioFormat?
    private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
    private var resultsTask: Task<Void, Never>?

    // Identidad del idioma con el que trabaja la app.
    static let sourceLocale = Locale(identifier: "en-US")

    // MARK: Setup (llamar una vez, tras conceder permiso de micro)
    func setup() async throws {
        // 1) Hardware: SpeechTranscriber exige hardware reciente; fallback DictationTranscriber
        //    ("compatible con dispositivos más antiguos", mismas capacidades que dictado on-device).
        guard SpeechTranscriber.isAvailable else { throw CSerror.noSpeechTranscriber }

        // 2) Locale canónico soportado (restringe a EN).
        guard let en = await SpeechTranscriber.supportedLocale(equivalentTo: Self.sourceLocale) else {
            throw CSerror.localeUnsupported
        }

        // 3) Módulo con preset de transcripción progresiva + timestamps.
        let module = SpeechTranscriber(
            locale: en,
            transcriptionOptions: [],
            reportingOptions: [.volatileResults],     // parciales + finales
            attributeOptions: [.audioTimeRange]        // timecodes por run
        )
        self.transcriber = module

        // 4) Analyzer (actor) que orquesta el módulo.
        self.analyzer = SpeechAnalyzer(modules: [module])

        // 5) Formato óptimo para el modelo instalado.
        self.analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [module])
    }

    // MARK: Arranque de la sesión de audio + análisis
    func start() async throws {
        // (a) Permiso de micro (iOS 17+). Info.plist: NSMicrophoneUsageDescription.
        guard await AVAudioApplication.requestRecordPermission() else { throw CSerror.micDenied }

        // (b) AVAudioSession para campo lejano (ver §(b.5)).
        let session = AVAudioSession.sharedInstance()
        var opts: AVAudioSession.CategoryOptions = [.allowBluetooth]
        if #available(iOS 26.2, *) { opts.insert(.farFieldInput) }
        try session.setCategory(.record, mode: .measurement, options: opts)
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        // (c) Canal hacia el analyzer y arranque del análisis.
        let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
        self.inputContinuation = continuation
        try await analyzer?.start(inputSequence: stream)

        // (d) Tap -> conversión -> AnalyzerInput.
        let input = audioEngine.inputNode
        let tapFormat = input.outputFormat(forBus: 0)
        guard let analyzerFormat else { throw CSerror.noAnalyzerFormat }
        let converter = AVAudioConverter(from: tapFormat, to: analyzerFormat)

        input.installTap(onBus: 0, bufferSize: 4096, format: tapFormat) { buffer, _ in
            guard let converter,
                  let converted = AVAudioPCMBuffer(
                      pcmFormat: analyzerFormat,
                      frameCapacity: AVAudioFrameCount(Double(buffer.frameLength) *
                          analyzerFormat.sampleRate / tapFormat.sampleRate)) else { return }
            var error: NSError?
            converter.convert(to: converted, error: &error) { _, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }
            if error == nil, converted.frameLength > 0 {
                continuation.yield(AnalyzerInput(buffer: converted))
            }
        }
        audioEngine.prepare()
        try audioEngine.start()

        // (e) Consumo de resultados (parciales -> UI, finales -> traducción).
        guard let transcriber else { return }
        resultsTask = Task { [weak self] in
            do {
                for try await result in transcriber.results {
                    self?.handle(result)
                }
            } catch is CancellationError {
                // parada normal
            } catch {
                self?.handle(error)
            }
        }
    }

    private func handle(_ result: SpeechTranscriber.Result) {
        if result.isFinal {
            // Segmento definitivo: enviar a traducción.
            translationPipeline.enqueue(String(result.text.characters), range: result.range)
        } else {
            // Volátil: pintar en gris como vista previa del subtítulo.
            ui.showVolatile(String(result.text.characters))
        }
    }

    // MARK: Parada limpia
    func stop() async {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        inputContinuation?.finish()                      // corta la secuencia
        try? await analyzer?.finalizeAndFinishThroughEndOfInput()  // finaliza volátiles pendientes
        resultsTask?.cancel()
        resultsTask = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
```

Pausa/reanudación (llamada telefónica, backgrounding): parar solo el engine y el tap; mantener el analyzer vivo y reanudar con un stream nuevo (`start(inputSequence:)` de nuevo) o pausar todo y recrear. Al reanudar, reactivar la `AVAudioSession` primero. Tras pausas largas usar `AnalyzerInput(buffer:bufferStartTime:)` para marcar discontinuidad.

### c.2 Pre-descarga del modelo EN y del paquete de traducción

```swift
// ===== SPEECH (con progreso real) — iOS 26.0 =====
func prepareSpeechModel() async throws {
    let en = try await requireEnglishLocale()             // supportedLocale(equivalentTo:) sobre "en-US"
    let module = SpeechTranscriber(locale: en, preset: .timeIndexedProgressiveTranscription)

    let status = await AssetInventory.status(forModules: [module])
    switch status {
    case .installed:
        break
    case .downloading:
        break   // ya en curso (p.ej. otra app); esperar
    case .supported:
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [module]) {
            progressReporter.observe(request.progress)    // Foundation.Progress (patrón WWDC25 277)
            try await request.downloadAndInstall()
        }
    case .unsupported:
        throw CSerror.localeUnsupported
    @unknown default:
        break
    }
    // Mantener reservado para que el sistema no lo expulse.
    _ = try? await AssetInventory.reserve(locale: en)
}
// Al terminar la sesión de cine (app en background/larga inactividad), liberar:
//   _ = await AssetInventory.release(reservedLocale: en)

// ===== TRANSLATION (sin API de progreso) =====
func prepareTranslationEN_ES() async {
    let availability = LanguageAvailability()   // iOS 26.4+: LanguageAvailability(preferredStrategy: .lowLatency)
    let status = await availability.status(
        from: Locale.Language(identifier: "en"),
        to: Locale.Language(identifier: "es"))
    switch status {
    case .installed:
        break                                   // listo para la vía programática
    case .supported:
        // Requiere consentimiento del usuario vía system UI. Bootstrap mínimo con SwiftUI
        // (una vista auxiliar invisible) — .translationTask(source:target:) { session in
        //     try? await session.prepareTranslation()
        // } — o dirigir al usuario a Ajustes > Traducción.
        await translationBootstrap.requestDownload()
    case .unsupported:
        ui.warnEsUnsupported()
    }
}
```

### c.3 Pipeline de traducción (segmentos cortos, muchos)

```swift
actor TranslationPipeline {
    private var session: TranslationSession?

    func open() throws {
        // Reutilizable para TODOS los segmentos de la película; no recrear por subtítulo.
        if #available(iOS 26.4, *) {
            session = try TranslationSession(
                installedSource: Locale.Language(identifier: "en"),
                target: Locale.Language(identifier: "es"),
                preferredStrategy: .lowLatency)   // rápido, modelos tradicionales, ya instalados
        } else {
            session = try TranslationSession(
                installedSource: Locale.Language(identifier: "en"),
                target: Locale.Language(identifier: "es"))
        }
    }

    func enqueue(_ text: String, range: CMTimeRange) async {
        guard let session, await session.isReady else { return }
        do {
            let response = try await session.translate(text)   // iOS 18+
            await ui.showFinal(response.targetText, range: range)
        } catch let e as TranslationError {
            switch e.code {
            case .notInstalled:         await ui.promptInstallLanguages()
            case .alreadyCancelled:     break
            default:                    break
            }
        } catch {
            // reintentos / degradar a volátil
        }
    }

    func cancelAll() {
        session?.cancel()   // iOS 26+; detiene el trabajo en curso
    }
}
```

Notas: si la latencia acumulada importa, usar `translate(batch:)` (`[TranslationSession.Request]`) drenando una cola con un timer (p.ej. cada 300–500 ms) para aprovechar el pipeline por lotes.

---

## (d) Riesgos / incertidumbres

1. **API rediseñada a mitad de beta (ya resuelto, pero vigilar):** el patrón WWDC25-beta (`SpeechTranscriber(audioEngine:)`, `SpeechTranscriber.Request`, `shouldReportPartialResults`, `SpeechAnalyzer(root:)`, `AssetInventory.deallocate`) NO se envió así. Si se copia código de tutoriales de junio–julio 2025 no compilará. Fuente verificada: referencia oficial actual (solo `init(locale:preset:)`/`init(locale:transcriptionOptions:...)`), y el sample oficial ya usa `modules:`.
2. **Permisos:** toda la evidencia oficial (WWDC25 277 + sample iOS 27) indica que SpeechAnalyzer en vivo solo requiere micro. **No se encontró declaración oficial explícita que lo afirme en una frase** ni que niegue `NSSpeechRecognitionUsageDescription`. Acción: probar en dispositivo físico; mantener la clave como cinturón de seguridad si se añade fallback legacy.
3. **Background:** no hay promesa oficial de que SpeechAnalyzer transcriba con la app en background con `UIBackgroundModes=[audio]`; la inferencia (modelo fuera de proceso + timecodes) es razonable pero hay que validar en dispositivo (y con pantalla bloqueada). Riesgo de rechazo en revisión del App Store si el modo audio se considera accesorio.
4. **Far-field:** `.farFieldInput` (iOS 26.2+) dice "cuando esté disponible" — depende del hardware (mics de cámara/field). En dispositivos sin soporte la opción es no-op. La elección de modo (`.measurement` vs `.default`) para audio de película no está documentada por Apple; requiere pruebas reales en sala.
5. **Descarga de paquete EN→ES de Translation:** no hay API programática pura con progreso; el bootstrap de la primera descarga depende de un flujo con UI (`.translationTask` + `prepareTranslation()`), lo que obliga a mantener una vista SwiftUI auxiliar o enviar al usuario a Ajustes. Además, `init(installedSource:target:)` lanza error si el par no está instalado, así que el chequeo con `LanguageAvailability.status` es obligatorio en cada arranque.
6. **`AssetInstallationRequest.progress`:** el uso de `request.progress` (Foundation.Progress) proviene del código mostrado en la sesión WWDC25 277; la página de referencia de la clase no documenta explícitamente esa propiedad (solo `downloadAndInstall()`). Verificar en headers SDK al implementar.
7. **Calidad ASR en audio de película:** SpeechTranscriber está diseñado para "conversación normal y uso general" (propio de dictado cercano); música, mezclas y efectos pueden degradar la precisión. `DictationTranscriber` no es necesariamente mejor. Considerar `SpeechDetector` (VAD) para enmudecer segmentos sin voz y `SFSpeechLanguageModel`/`SFCustomLanguageModelData` para vocabulario de películas si hiciera falta.
8. **iOS 27 en el horizonte:** `CaptureInputSequenceProvider`/`AnalyzerInputConverter` (iOS 27) simplifican muchísimo la captura (sesión AVCapture configurada automáticamente, sin tap ni convertidor manual) y `interruptionNotification` está deprecado (27.0) a favor de tipos de mensajes aún poco documentados. Diseñar el pipeline de captura detrás de un protocolo para poder migrar.
9. **`volatileResults` y subtítulos:** un volátil puede retractarse (el final del mismo rango difiere). Para no mostrar subtítulos incorrectos, traducir solo resultados finales; los volátiles solo como vista previa sin traducir (traducir volátiles multiplicaría el trabajo y el parpadeo).

---

## Todas las fuentes (verificadas 2026-09-19)

**Speech (iOS 26):**
- https://developer.apple.com/documentation/speech/speechanalyzer
- https://developer.apple.com/documentation/speech/speechanalyzer/init(modules:options:)
- https://developer.apple.com/documentation/speech/speechanalyzer/start(inputsequence:)
- https://developer.apple.com/documentation/speech/speechanalyzer/analyzesequence(_:)
- https://developer.apple.com/documentation/speech/speechanalyzer/finalizeandfinishthroughendofinput()
- https://developer.apple.com/documentation/speech/speechanalyzer/bestavailableaudioformat(compatiblewith:)
- https://developer.apple.com/documentation/speech/speechanalyzer/options
- https://developer.apple.com/documentation/speech/speechtranscriber
- https://developer.apple.com/documentation/speech/speechtranscriber/init(locale:preset:)
- https://developer.apple.com/documentation/speech/speechtranscriber/init(locale:transcriptionoptions:reportingoptions:attributeoptions:)
- https://developer.apple.com/documentation/speech/speechtranscriber/preset
- https://developer.apple.com/documentation/speech/speechtranscriber/reportingoption
- https://developer.apple.com/documentation/speech/speechtranscriber/resultattributeoption
- https://developer.apple.com/documentation/speech/speechtranscriber/result
- https://developer.apple.com/documentation/speech/speechtranscriber/results
- https://developer.apple.com/documentation/speech/speechtranscriber/isavailable
- https://developer.apple.com/documentation/speech/speechtranscriber/installedlocales
- https://developer.apple.com/documentation/speech/speechtranscriber/supportedlocales
- https://developer.apple.com/documentation/speech/speechtranscriber/supportedlocale(equivalentto:)
- https://developer.apple.com/documentation/speech/speechmoduleresult
- https://developer.apple.com/documentation/speech/analyzerinput
- https://developer.apple.com/documentation/speech/speechmodule
- https://developer.apple.com/documentation/speech/dictationtranscriber
- https://developer.apple.com/documentation/speech/speechdetector
- https://developer.apple.com/documentation/speech/captureinputsequenceprovider
- https://developer.apple.com/documentation/speech/assetinputsequenceprovider
- https://developer.apple.com/documentation/speech/analyzerinputconverter
- https://developer.apple.com/documentation/speech/assetinventory
- https://developer.apple.com/documentation/speech/assetinventory/assetinstallationrequest(supporting:)
- https://developer.apple.com/documentation/speech/assetinstallationrequest
- https://developer.apple.com/documentation/speech/assetinstallationrequest/downloadandinstall()
- https://developer.apple.com/documentation/speech/assetinventory/status(formodules:)
- https://developer.apple.com/documentation/speech/assetinventory/reserve(locale:)
- https://developer.apple.com/documentation/speech/assetinventory/release(reservedlocale:)
- https://developer.apple.com/documentation/speech/bringing-advanced-speech-to-text-capabilities-to-your-app
- https://developer.apple.com/documentation/speech/recognizing-speech-in-live-audio (sample oficial, iOS 27)
- https://developer.apple.com/documentation/speech/asking-permission-to-use-speech-recognition
- https://developer.apple.com/videos/play/wwdc2025/277/ (sesión "Bring advanced speech-to-text to your app with SpeechAnalyzer")

**Translation:**
- https://developer.apple.com/documentation/translation
- https://developer.apple.com/documentation/translation/translationsession
- https://developer.apple.com/documentation/translation/translationsession/init(installedsource:target:)
- https://developer.apple.com/documentation/translation/translationsession/init(installedsource:target:preferredstrategy:)
- https://developer.apple.com/documentation/translation/translationsession/strategy
- https://developer.apple.com/documentation/translation/translationsession/strategy/lowlatency
- https://developer.apple.com/documentation/translation/translationsession/strategy/highfidelity
- https://developer.apple.com/documentation/translation/translationsession/translate(_:)-4m20l
- https://developer.apple.com/documentation/translation/translationsession/translate(_:)-59zi2
- https://developer.apple.com/documentation/translation/translationsession/translate(batch:)
- https://developer.apple.com/documentation/translation/translationsession/request
- https://developer.apple.com/documentation/translation/translationsession/response
- https://developer.apple.com/documentation/translation/translationsession/preparetranslation()
- https://developer.apple.com/documentation/translation/translationsession/canrequestdownloads
- https://developer.apple.com/documentation/translation/translationsession/isready
- https://developer.apple.com/documentation/translation/translationsession/cancel()
- https://developer.apple.com/documentation/translation/translationsession/configuration
- https://developer.apple.com/documentation/translation/languageavailability
- https://developer.apple.com/documentation/translation/languageavailability/status(from:to:)
- https://developer.apple.com/documentation/translation/translationerror

**Audio / sesión / background:**
- https://developer.apple.com/documentation/avfaudio/avaudiosession
- https://developer.apple.com/documentation/avfaudio/avaudiosession/setcategory(_:mode:options:)
- https://developer.apple.com/documentation/avfaudio/avaudiosession/category-swift.struct
- https://developer.apple.com/documentation/avfaudio/avaudiosession/mode-swift.struct
- https://developer.apple.com/documentation/avfaudio/avaudiosession/categoryoptions-swift.struct/farfieldinput
- https://developer.apple.com/documentation/avfaudio/avaudiosession/interruptionnotification
- https://developer.apple.com/documentation/avfaudio/avaudiosession/routechangenotification
- https://developer.apple.com/documentation/avfaudio/handling-audio-interruptions
- https://developer.apple.com/documentation/avfaudio/responding-to-audio-route-changes
- https://developer.apple.com/documentation/avfaudio/avaudioapplication
- https://developer.apple.com/documentation/avfaudio/avaudioapplication/requestrecordpermission(completionhandler:)
- https://developer.apple.com/documentation/xcode/configuring-background-execution-modes
- https://developer.apple.com/documentation/bundleresources/information-property-list/uibackgroundmodes

**Terceros (solo contraste, no autoridad):** guías 2025–2026 de callstack.com, blakecrosley.com, picovoice.ai, macstories.net sobre SpeechAnalyzer (consenso: fallback `DictationTranscriber` para hardware sin Apple Intelligence).
