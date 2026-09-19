import Foundation

/// Update tal y como llega del transcriptor (volatile o final).
struct TranscriptUpdate: Sendable {
  let text: String
  let isFinal: Bool
  let startTime: TimeInterval
}

/// Lo que el estabilizador decide emitir hacia traducción.
enum StabilizerEmission: Equatable, Sendable {
  /// candidato estable: texto sin cambios durante la ventana de estabilidad
  case stable(text: String, startTime: TimeInterval)
  /// resultado marcado final por el transcriptor: prioridad absoluta
  case final(text: String, startTime: TimeInterval)
}

///
/// TranscriptStabilizer — componente CRÍTICO anti-parpadeo.
///
/// Distingue tres niveles:
///  1. volatile: el texto sigue cambiando (no se emite nada)
///  2. stable candidate: lleva `stabilityWindow` sin cambiar → emite `.stable`
///  3. final: el transcriptor marca final → emite `.final` inmediatamente
///
/// Diseño determinista y testeable: no crea timers ni hilos. El dueño del
/// pipeline llama `ingest(_:now:)` con cada parcial y `tick(now:)`
/// periódicamente (p. ej. cada 50 ms), pasando siempre el mismo reloj.
///
/// La ventana óptima (250–700 ms) se decide midiendo en dispositivo;
/// 350 ms es el punto de partida documentado en docs/DECISIONS.md.
final class TranscriptStabilizer: @unchecked Sendable {
  private let lock = NSLock()
  private let stabilityWindow: TimeInterval

  private var currentText = ""
  private var currentStartTime: TimeInterval = 0
  private var lastChangeAt: TimeInterval = 0
  private var hasEmittedStableForCurrent = false
  private var lastEmittedText = ""

  init(stabilityWindow: TimeInterval = 0.35) {
    precondition(stabilityWindow > 0, "stabilityWindow debe ser > 0")
    self.stabilityWindow = stabilityWindow
  }

  /// Registra un update del transcriptor. Un final vacía el estado pendiente
  /// (el parcial correspondiente ya quedó cubierto por el final).
  func ingest(_ update: TranscriptUpdate, now: TimeInterval) -> [StabilizerEmission] {
    lock.lock()
    defer { lock.unlock() }

    let normalized = update.text.trimmingCharacters(in: .whitespacesAndNewlines)

    if update.isFinal {
      currentText = ""
      currentStartTime = 0
      hasEmittedStableForCurrent = false
      lastEmittedText = normalized
      guard !normalized.isEmpty else { return [] }
      return [.final(text: normalized, startTime: update.startTime)]
    }

    if normalized != currentText {
      // el texto volvió a cambiar: la ventana de estabilidad se reinicia
      currentText = normalized
      currentStartTime = update.startTime
      lastChangeAt = now
      hasEmittedStableForCurrent = false
    }
    return []
  }

  /// Consulta periódica: emite el candidato estable cuando procede.
  func tick(now: TimeInterval) -> [StabilizerEmission] {
    lock.lock()
    defer { lock.unlock() }

    guard !currentText.isEmpty,
          !hasEmittedStableForCurrent,
          now - lastChangeAt >= stabilityWindow,
          currentText != lastEmittedText
    else { return [] }

    hasEmittedStableForCurrent = true
    lastEmittedText = currentText
    return [.stable(text: currentText, startTime: currentStartTime)]
  }

  /// ¿Hay texto parcial pendiente de estabilizar? (diagnóstico)
  var hasPendingText: Bool {
    lock.lock()
    defer { lock.unlock() }
    return !currentText.isEmpty
  }

  func reset() {
    lock.lock()
    defer { lock.unlock() }
    currentText = ""
    currentStartTime = 0
    lastChangeAt = 0
    hasEmittedStableForCurrent = false
    lastEmittedText = ""
  }
}
