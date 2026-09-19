import Foundation
import os

/// Logging estructurado del pipeline.
///
/// REGLA DE PRIVACIDAD: nunca se registra contenido de audio, transcripción ni traducción.
/// Solo eventos y métricas numéricas (`latency=842ms`, `segment_length=31`, ...).
enum Log {
  private static let logger = Logger(subsystem: "com.cinemasubs.app", category: "pipeline")

  enum Event: String, Sendable {
    case pipelineStarted
    case pipelineStopped
    case audioSessionActivated
    case audioSessionInterrupted
    case audioEngineFailure
    case speechAnalyzerFailure
    case speechPartialReceived
    case speechFinalReceived
    case stableCandidateEmitted
    case translationStarted
    case translationFinished
    case translationCancelled
    case subtitlePresented
    case subtitleDropped
    case modelDownloadProgress
    case errorRecovered
  }

  static func event(_ event: Event, _ fields: [String: String] = [:]) {
    let payload = fields.isEmpty
      ? ""
      : " " + fields.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: " ")
    // .public es seguro: por construcción aquí nunca hay contenido hablado.
    logger.info("\(event.rawValue, privacy: .public)\(payload, privacy: .public)")
  }

  static func failure(_ event: Event, _ error: Error) {
    // `String(describing:)` de un CinemaError nunca incluye texto transcrito.
    logger.error("\(event.rawValue, privacy: .public) error=\(String(describing: error), privacy: .public)")
  }
}
