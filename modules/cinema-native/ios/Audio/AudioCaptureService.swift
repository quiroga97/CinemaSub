import AVFAudio
import Foundation
import Speech

///
/// AudioCaptureService — posee el AVAudioEngine y el ciclo de vida del tap.
///
/// Configura la sesión para voz lejana (.record + .measurement + .farFieldInput),
/// instala el tap en inputNode, convierte cada PCMBuffer al formato del analyzer
/// y lo entrega como AsyncStream<AnalyzerInput>. Nunca escribe audio a disco.
///
/// Gestiona interrupciones (llamada) y cambios de ruta (Bluetooth/auriculares)
/// reinstalando el tap con el formato vigente.
final class AudioCaptureService: @unchecked Sendable {
  private let engine = AVAudioEngine()
  private var continuation: AsyncStream<AnalyzerInput>.Continuation?
  private var analyzerFormat: AVAudioFormat?
  private var monitorTask: Task<Void, Never>?
  private(set) var isRunning = false

  /// Evento de sesión para que el pipeline informe estado (interrupción, etc.).
  var onSessionEvent: (@Sendable (_ event: SessionEvent) -> Void)?

  enum SessionEvent: Sendable {
    case interruptionBegan
    case interruptionEnded
    case routeChanged
  }

  // MARK: - Sesión de audio

  /// Categoría/mode optimizados para diálogo lejano reproducido por altavoces de sala
  /// (ver docs/research/APPLE_APIS.md §b.5: .measurement vs .default queda como A/B en dispositivo).
  func activateSession() throws {
    let session = AVAudioSession.sharedInstance()
    var options: AVAudioSession.CategoryOptions = [.allowBluetooth]
    options.insert(.farFieldInput) // iOS 26.2+; deployment target 26.4
    try session.setCategory(.record, mode: .measurement, options: options)
    try session.setActive(true, options: .notifyOthersOnDeactivation)
    Log.event(.audioSessionActivated)
    startMonitoring()
  }

  func deactivateSession() {
    stopMonitoring()
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
  }

  // MARK: - Captura

  /// Arranca el engine + tap. Devuelve el stream que consume SpeechAnalyzer.
  func start(analyzerFormat: AVAudioFormat) throws -> AsyncStream<AnalyzerInput> {
    self.analyzerFormat = analyzerFormat
    let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
    self.continuation = continuation

    installTap()

    engine.prepare()
    try engine.start()
    isRunning = true
    return stream
  }

  func stop() {
    engine.inputNode.removeTap(onBus: 0)
    engine.stop()
    isRunning = false
    continuation?.finish()
    continuation = nil
  }

  /// Reinstala el tap leyendo el formato de entrada actual (tras cambio de ruta).
  private func restartTap() {
    engine.inputNode.removeTap(onBus: 0)
    guard isRunning || continuation != nil else { return }
    installTap()
    if !engine.isRunning {
      engine.prepare()
      try? engine.start()
    }
  }

  private func installTap() {
    guard let analyzerFormat else { return }
    let input = engine.inputNode
    let tapFormat = input.outputFormat(forBus: 0)
    guard tapFormat.sampleRate > 0 else {
      Log.failure(.audioEngineFailure, CinemaError.audioEngineFailure(reason: "formato de entrada inválido"))
      return
    }
    guard let converter = AVAudioConverter(from: tapFormat, to: analyzerFormat) else {
      Log.failure(.audioEngineFailure, CinemaError.audioEngineFailure(reason: "sin conversor tap→analyzer"))
      return
    }

    input.installTap(onBus: 0, bufferSize: 4096, format: tapFormat) { [weak self] buffer, _ in
      guard let self, let continuation = self.continuation else { return }
      let ratio = analyzerFormat.sampleRate / tapFormat.sampleRate
      let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up))
      guard capacity > 0,
            let converted = AVAudioPCMBuffer(pcmFormat: analyzerFormat, frameCapacity: capacity) else { return }
      var conversionError: NSError?
      converter.convert(to: converted, error: &conversionError) { _, outStatus in
        outStatus.pointee = .haveData
        return buffer
      }
      if conversionError == nil, converted.frameLength > 0 {
        continuation.yield(AnalyzerInput(buffer: converted))
      }
    }
  }

  // MARK: - Interrupciones y rutas

  private func startMonitoring() {
    stopMonitoring()
    let center = NotificationCenter.default
    monitorTask = Task { [weak self] in
      let interruptions = center.notifications(
        named: AVAudioSession.interruptionNotification,
        object: AVAudioSession.sharedInstance())
      let routeChanges = center.notifications(
        named: AVAudioSession.routeChangeNotification,
        object: AVAudioSession.sharedInstance())

      // SERIAL: procesamos ambas fuentes en un solo bucle para evitar carreras
      for await notification in merge(interruptions, routeChanges) {
        guard let self else { return }
        if notification.name == AVAudioSession.interruptionNotification {
          self.handleInterruption(notification)
        } else {
          self.handleRouteChange(notification)
        }
      }
    }
  }

  private func stopMonitoring() {
    monitorTask?.cancel()
    monitorTask = nil
  }

  private func handleInterruption(_ notification: Notification) {
    guard let info = notification.userInfo,
          let raw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
          let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
    switch type {
    case .began:
      Log.event(.audioSessionInterrupted, ["type": "began"])
      engine.inputNode.removeTap(onBus: 0)
      engine.stop()
      onSessionEvent?(.interruptionBegan)
    case .ended:
      Log.event(.audioSessionInterrupted, ["type": "ended"])
      try? AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
      restartTap()
      onSessionEvent?(.interruptionEnded)
    @unknown default:
      break
    }
  }

  private func handleRouteChange(_ notification: Notification) {
    guard let info = notification.userInfo,
          let raw = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
          let reason = AVAudioSession.RouteChangeReason(rawValue: raw) else { return }
    switch reason {
    case .newDeviceAvailable, .oldDeviceUnavailable:
      // el formato de inputNode puede cambiar: reinstalar tap con el formato vigente
      Log.event(.audioSessionInterrupted, ["type": "route"])
      restartTap()
      onSessionEvent?(.routeChanged)
    default:
      break
    }
  }

  /// Fusión serial de dos secuencias de notificaciones (patrón AsyncSequence).
  private func merge(
    _ a: NotificationCenter.Notifications,
    _ b: NotificationCenter.Notifications
  ) -> AsyncStream<Notification> {
    let (stream, continuation) = AsyncStream<Notification>.makeStream()
    Task {
      for await n in a { continuation.yield(n) }
    }
    Task {
      for await n in b { continuation.yield(n) }
    }
    return stream
  }
}
