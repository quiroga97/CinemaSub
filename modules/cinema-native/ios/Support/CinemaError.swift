import Foundation

/// Errores tipados del pipeline. `code` viaja a JS; `userMessage` es texto para UI en español.
enum CinemaError: Error, Sendable {
  case microphonePermissionDenied
  case speechPermissionDenied
  case speechModelMissing(locale: String)
  case translationModelMissing(source: String, target: String)
  case unsupportedLocale(locale: String)
  case audioEngineFailure(reason: String)
  case speechAnalyzerFailure(reason: String)
  case translationFailure(reason: String)
  case interruption(reason: String)
  case notAvailableOnDevice(minimumOS: String)
  case sessionNotRunning

  var code: String {
    switch self {
    case .microphonePermissionDenied: return "E_MIC_PERMISSION"
    case .speechPermissionDenied: return "E_SPEECH_PERMISSION"
    case .speechModelMissing: return "E_SPEECH_MODEL_MISSING"
    case .translationModelMissing: return "E_TRANSLATION_MODEL_MISSING"
    case .unsupportedLocale: return "E_UNSUPPORTED_LOCALE"
    case .audioEngineFailure: return "E_AUDIO_ENGINE"
    case .speechAnalyzerFailure: return "E_SPEECH_ANALYZER"
    case .translationFailure: return "E_TRANSLATION"
    case .interruption: return "E_INTERRUPTED"
    case .notAvailableOnDevice: return "E_NOT_SUPPORTED"
    case .sessionNotRunning: return "E_NO_SESSION"
    }
  }

  var userMessage: String {
    switch self {
    case .microphonePermissionDenied:
      return "Se necesita permiso de micrófono. Actívalo en Ajustes → CinemaSubs → Micrófono."
    case .speechPermissionDenied:
      return "Se necesita permiso de reconocimiento de voz. Actívalo en Ajustes → CinemaSubs."
    case .speechModelMissing(let locale):
      return "Falta el modelo de voz \(locale). Usa «Preparar modo offline» antes de entrar al cine."
    case .translationModelMissing:
      return "Falta el paquete de traducción EN→ES. Usa «Preparar modo offline» con conexión."
    case .unsupportedLocale(let locale):
      return "Idioma no soportado en este dispositivo: \(locale)."
    case .audioEngineFailure(let reason):
      return "Problema de audio: \(reason)"
    case .speechAnalyzerFailure(let reason):
      return "El transcriptor de voz falló: \(reason)"
    case .translationFailure(let reason):
      return "La traducción falló: \(reason)"
    case .interruption(let reason):
      return "Sesión interrumpida (\(reason)). Pulsa START para continuar."
    case .notAvailableOnDevice(let minimumOS):
      return "Esta función requiere iOS \(minimumOS) o superior."
    case .sessionNotRunning:
      return "No hay ninguna sesión activa."
    }
  }
}
