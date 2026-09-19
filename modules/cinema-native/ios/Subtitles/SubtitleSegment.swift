import Foundation

/// Segmento transcrito (inglés) tal y como sale del estabilizador.
struct TranscriptSegment: Equatable, Sendable {
  let id: String
  let text: String
  let startTime: TimeInterval
  var endTime: TimeInterval?
  let isFinal: Bool
}

/// Subtítulo listo para UI: texto original + traducción + latencia medida.
struct LocalizedSubtitle: Equatable, Sendable {
  let id: String
  let originalText: String
  let translatedText: String
  let startTime: TimeInterval
  var endTime: TimeInterval?
  let isFinal: Bool
  var confidence: Double?
  var latencyMs: Int
  /// reloj de sesión (s) en el que llegó al scheduler
  var arrivalTime: TimeInterval

  init(
    id: String,
    originalText: String,
    translatedText: String,
    startTime: TimeInterval,
    endTime: TimeInterval? = nil,
    isFinal: Bool,
    confidence: Double? = nil,
    latencyMs: Int,
    arrivalTime: TimeInterval
  ) {
    self.id = id
    self.originalText = originalText
    self.translatedText = translatedText
    self.startTime = startTime
    self.endTime = endTime
    self.isFinal = isFinal
    self.confidence = confidence
    self.latencyMs = latencyMs
    self.arrivalTime = arrivalTime
  }
}

/// Normalización para comparar textos sin ruido de puntuación/espacios/caso.
func normalizeForCompare(_ text: String) -> String {
  let lowered = text.lowercased()
  let punctuation = Set(".,!?;:¡¿\"'“”()")
  let squashed = lowered
    .components(separatedBy: .whitespacesAndNewlines)
    .filter { !$0.isEmpty }
    .joined(separator: " ")
  return squashed.filter { !punctuation.contains($0) }
}

/// ¿El cambio entre el subtítulo rápido y el final es lo bastante grande como para re-pintar?
/// Tras normalizar (puntuación/espacios/caso fuera), cualquier diferencia es de palabras:
/// re-pintar. Las diferencias de pura puntuación desaparecen al normalizar.
func isSignificantChange(previous: String, next: String) -> Bool {
  normalizeForCompare(previous) != normalizeForCompare(next)
}
