import AVFAudio
import Foundation
import Speech

///
/// SpeechRecognitionService — transcripción en vivo con la API modular de iOS 26:
/// SpeechTranscriber (módulo) + SpeechAnalyzer (actor) + AsyncStream<AnalyzerInput>.
///
/// NOTA (docs/research/APPLE_APIS.md §d.1): el patrón de las betas de 2025
/// (SpeechTranscriber(audioEngine:), SpeechTranscriber.Request, shouldReportPartialResults,
/// SpeechAnalyzer(root:)) YA NO EXISTE en la API final. Este archivo usa solo la API enviada.
final class SpeechRecognitionService: @unchecked Sendable {

  private let audio = AudioCaptureService()
  private var transcriber: SpeechTranscriber?
  private var analyzer: SpeechAnalyzer?
  private var resultsTask: Task<Void, Never>?
  private(set) var isRunning = false

  var onSessionEvent: (@Sendable (AudioCaptureService.SessionEvent) -> Void)? {
    get { audio.onSessionEvent }
    set { audio.onSessionEvent = newValue }
  }

  struct Handlers {
    let onResult: @Sendable (SpeechTranscriber.Result) -> Void
    let onError: @Sendable (CinemaError) -> Void
  }

  /// Verifica soporte del dispositivo y del locale ANTES de crear nada.
  static func validateSupport(localeIdentifier: String) async throws -> Locale {
    guard SpeechTranscriber.isAvailable else {
      throw CinemaError.notAvailableOnDevice(minimumOS: "26")
    }
    guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: localeIdentifier)) else {
      throw CinemaError.unsupportedLocale(locale: localeIdentifier)
    }
    return locale
  }

  /// Arranca sesión de audio + analyzer + consumo de resultados.
  func start(
    locale: Locale,
    fastResults: Bool,
    handlers: Handlers
  ) async throws {
    guard !isRunning else { return }

    // 1) módulo transcriptor: parciales volátiles + timestamps de audio
    var reportingOptions: Set<SpeechTranscriber.ReportingOption> = [.volatileResults]
    if fastResults {
      // sesga hacia capacidad de respuesta (más rápido, menos preciso); ajustable
      reportingOptions.insert(.fastResults)
    }
    let module = SpeechTranscriber(
      locale: locale,
      transcriptionOptions: [],
      reportingOptions: reportingOptions,
      attributeOptions: [.audioTimeRange]
    )
    self.transcriber = module

    // 2) analyzer actor que orquesta el módulo
    self.analyzer = SpeechAnalyzer(modules: [module])

    // 3) formato óptimo exigido por el modelo instalado
    guard let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [module]) else {
      throw CinemaError.speechAnalyzerFailure(reason: "sin formato de audio compatible")
    }

    // 4) sesión de audio (voz lejana) + tap → stream
    try audio.activateSession()
    let stream = try audio.start(analyzerFormat: analyzerFormat)

    // 5) el analyzer consume el stream
    try await analyzer?.start(inputSequence: stream)

    // 6) consumo de resultados (volátiles + finales)
    resultsTask = Task { [weak self] in
      do {
        for try await result in module.results {
          handlers.onResult(result)
        }
      } catch is CancellationError {
        // parada normal
      } catch {
        Log.failure(.speechAnalyzerFailure, error)
        handlers.onError(.speechAnalyzerFailure(reason: String(describing: error)))
        self?.stopSync()
      }
    }
    isRunning = true
  }

  /// Parada limpia: tap → stream → analyzer → sesión.
  func stop() async {
    stopSync()
    try? await analyzer?.finalizeAndFinishThroughEndOfInput()
  }

  private func stopSync() {
    guard isRunning || transcriber != nil else { return }
    audio.stop()
    audio.deactivateSession()
    resultsTask?.cancel()
    resultsTask = nil
    isRunning = false
  }
}
