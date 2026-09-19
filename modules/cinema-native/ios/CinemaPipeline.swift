import AVFAudio
import Foundation
import Speech
import Translation

/// Estados que cruzan el bridge (idénticos a SessionStatusCode en TS).
enum PipelineStatus: String, Sendable {
  case idle, preparing, listening, paused, stopped, error
}

/// Callbacks del pipeline hacia el módulo Expo (todos @Sendable, sin contenido hablado).
struct PipelineHandlers {
  let onStatus: @Sendable (PipelineStatus) -> Void
  let onSubtitle: @Sendable (LocalizedSubtitle) -> Void
  let onMetrics: @Sendable (PipelineMetricsSnapshot) -> Void
  let onError: @Sendable (CinemaError) -> Void
}

///
/// CinemaPipeline — orquesta el flujo completo:
///
///   SpeechRecognitionService (audio + SpeechAnalyzer)
///     → TranscriptStabilizer (volatile/stable/final)
///     → TranslationService (EN→ES, lowLatency, cancelable)
///     → SubtitleScheduler (anti-flash + delay + catch-up)
///     → handlers.onSubtitle
///
/// Reglas de concurrencia:
///  * `lock` NUNCA se mantiene a través de un await.
///  * Todo estado mutable del pipeline (isRunning, tasks, firstSeen) se toca bajo lock.
///  * `generation` detecta un stop() concurrente con un start() en curso.
///  * Un único tick a 20 Hz alimenta estabilizador y scheduler (sin polling agresivo).
final class CinemaPipeline: @unchecked Sendable {
  private let lock = NSLock()

  private let stabilizer: TranscriptStabilizer
  private let scheduler = SubtitleScheduler()
  private let metrics = PipelineMetrics()
  private let translation: TranslationService
  private let includeOriginalText: Bool
  private let handlers: PipelineHandlers

  private var speech: SpeechRecognitionService?
  private var tickTask: Task<Void, Never>?
  private var translationTask: Task<Void, Never>?
  private var clockOrigin: Date?
  private var currentSegmentFirstSeen: TimeInterval?
  private var generation = 0
  private var isRunning = false

  /// Ventana de estabilidad inicial; se ajustará tras medir en dispositivo (D-005).
  init(
    stabilityWindow: TimeInterval = 0.35,
    includeOriginalText: Bool,
    handlers: PipelineHandlers
  ) {
    self.stabilizer = TranscriptStabilizer(stabilityWindow: stabilityWindow)
    self.includeOriginalText = includeOriginalText
    self.handlers = handlers
    self.translation = TranslationService()
  }

  // MARK: - Ciclo de vida

  func start(locale: Locale, fastResults: Bool) async throws {
    lock.lock()
    guard !isRunning else {
      lock.unlock()
      return
    }
    generation += 1
    let myGeneration = generation
    lock.unlock()

    handlers.onStatus(.preparing)

    // el par de traducción debe estar instalado antes (pantalla Preparar modo offline)
    do {
      try translation.open()
    } catch {
      handlers.onError(error as? CinemaError ?? .translationModelMissing(source: "en", target: "es"))
      handlers.onStatus(.error)
      throw error
    }

    lock.lock()
    clockOrigin = Date()
    currentSegmentFirstSeen = nil
    lock.unlock()
    stabilizer.reset()
    scheduler.reset()
    metrics.reset()

    let service = SpeechRecognitionService()
    service.onSessionEvent = { [weak self] event in
      guard let self else { return }
      switch event {
      case .interruptionBegan:
        self.handlers.onStatus(.paused)
      case .interruptionEnded:
        self.handlers.onStatus(.listening)
      case .routeChanged:
        break // el tap ya se reinstaló; el pipeline sigue
      }
    }

    do {
      try await service.start(locale: locale, fastResults: fastResults, handlers: .init(
        onResult: { [weak self] result in self?.handleSpeechResult(result) },
        onError: { [weak self] error in
          self?.handlers.onError(error)
          self?.handlers.onStatus(.error)
        }
      ))
    } catch {
      await service.stop()
      handlers.onError(.speechAnalyzerFailure(reason: String(describing: error)))
      handlers.onStatus(.error)
      throw error
    }

    lock.lock()
    // stop() llegó mientras arrancábamos: deshacer y salir limpio
    guard generation == myGeneration, !isRunning else {
      lock.unlock()
      await service.stop()
      return
    }
    speech = service
    isRunning = true
    lock.unlock()

    Log.event(.pipelineStarted)
    handlers.onStatus(.listening)
    startTickLoop()
  }

  func stop() async {
    lock.lock()
    let wasRunning = isRunning
    isRunning = false
    generation += 1
    let service = speech
    speech = nil
    tickTask?.cancel()
    tickTask = nil
    translationTask?.cancel()
    translationTask = nil
    currentSegmentFirstSeen = nil
    lock.unlock()

    await service?.stop()
    translation.close()
    if wasRunning {
      Log.event(.pipelineStopped)
      handlers.onStatus(.stopped)
    }
  }

  // MARK: - Control en vivo

  func setDelay(_ seconds: TimeInterval) {
    scheduler.setDelay(seconds)
  }

  func snapshotMetrics() -> PipelineMetricsSnapshot {
    metrics.snapshot(queueSize: scheduler.queueDepth, now: sessionClock())
  }

  // MARK: - Flujo de datos

  private func sessionClock() -> TimeInterval {
    lock.lock()
    defer { lock.unlock() }
    return clockOrigin.map { Date().timeIntervalSince($0) } ?? 0
  }

  private func handleSpeechResult(_ result: SpeechTranscriber.Result) {
    let now = sessionClock()
    let text = String(result.text.characters)
    let audioStart = result.range.start.seconds // tiempo de audio ≈ tiempo de sesión

    lock.lock()
    if currentSegmentFirstSeen == nil { currentSegmentFirstSeen = now }
    let firstSeen = currentSegmentFirstSeen ?? now
    if result.isFinal { currentSegmentFirstSeen = nil }
    lock.unlock()

    if result.isFinal {
      metrics.recordFinalLatency(ms: Int(max(0, now - audioStart) * 1000))
      Log.event(.speechFinalReceived, ["length": "\(text.count)"])
    } else {
      metrics.recordPartialLatency(ms: Int(max(0, now - audioStart) * 1000))
      Log.event(.speechPartialReceived, ["length": "\(text.count)"])
    }

    let emissions = stabilizer.ingest(
      TranscriptUpdate(text: text, isFinal: result.isFinal, startTime: audioStart),
      now: now
    )
    for emission in emissions {
      submitForTranslation(emission, segmentFirstSeen: firstSeen)
    }
  }

  private func submitForTranslation(_ emission: StabilizerEmission, segmentFirstSeen: TimeInterval) {
    lock.lock()
    // candidato más nuevo ⇒ cancelar la traducción pendiente anterior
    if let pending = translationTask {
      pending.cancel()
      metrics.recordCancellation()
      Log.event(.translationCancelled)
    }

    let text: String
    let startTime: TimeInterval
    let isFinal: Bool
    switch emission {
    case .stable(let t, let s):
      text = t; startTime = s; isFinal = false
      Log.event(.stableCandidateEmitted, ["length": "\(t.count)"])
    case .final(let t, let s):
      text = t; startTime = s; isFinal = true
    }
    let segmentID = "seg-\(Int(startTime * 1000))"
    let includeOriginal = includeOriginalText

    translationTask = Task { [weak self] in
      guard let self else { return }
      do {
        let t0 = self.sessionClock()
        Log.event(.translationStarted, ["is_final": isFinal ? "1" : "0"])
        let translated = try await self.translation.translate(text)
        try Task.checkCancellation()
        let now = self.sessionClock()
        self.metrics.recordTranslationLatency(ms: Int((now - t0) * 1000))
        Log.event(.translationFinished, ["ms": "\(Int((now - t0) * 1000))"])
        let subtitle = LocalizedSubtitle(
          id: segmentID,
          originalText: includeOriginal ? text : "",
          translatedText: translated,
          startTime: startTime,
          isFinal: isFinal,
          latencyMs: Int((now - segmentFirstSeen) * 1000),
          arrivalTime: now
        )
        self.scheduler.submit(subtitle)
      } catch is CancellationError {
        // sustituido por un candidato más reciente: correcto, no es error
      } catch {
        Log.failure(.translationFinished, error)
      }
    }
    lock.unlock()
  }

  private func startTickLoop() {
    lock.lock()
    tickTask?.cancel()
    tickTask = Task { [weak self] in
      var lastMetricsAt: TimeInterval = -10
      while !Task.isCancelled {
        try? await Task.sleep(nanoseconds: 50_000_000) // 20 Hz
        guard let self else { return }
        let now = self.sessionClock()

        for emission in self.stabilizer.tick(now: now) {
          self.submitForTranslation(emission, segmentFirstSeen: self.peekSegmentFirstSeen() ?? now)
        }

        while case .present(let subtitle) = self.scheduler.due(now: now) {
          self.present(subtitle, at: now)
        }

        if now - lastMetricsAt >= 2 {
          lastMetricsAt = now
          self.handlers.onMetrics(self.metrics.snapshot(queueSize: self.scheduler.queueDepth, now: now))
        }
      }
    }
    lock.unlock()
  }

  private func peekSegmentFirstSeen() -> TimeInterval? {
    lock.lock()
    defer { lock.unlock() }
    return currentSegmentFirstSeen
  }

  private func present(_ subtitle: LocalizedSubtitle, at now: TimeInterval) {
    metrics.recordTotalLatency(ms: subtitle.latencyMs, at: now)
    Log.event(.subtitlePresented, ["is_final": subtitle.isFinal ? "1" : "0"])
    handlers.onSubtitle(subtitle)
  }
}
