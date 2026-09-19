import Foundation
import Speech

///
/// SpeechModelManager — estado y descarga del modelo de speech (EN) vía AssetInventory.
/// Permite prepararlo antes de entrar al cine; el modelo vive fuera del proceso
/// de la app y NO se guarda nada en el sandbox propio.
enum SpeechModelManager {

  enum ModelState: String, Sendable {
    case installed
    case downloading
    case supported   // descargable pero no instalado
    case unsupported
  }

  /// Módulo desechable para consultar/descargar assets del locale dado.
  private static func probeModule(for locale: Locale) -> SpeechTranscriber {
    SpeechTranscriber(locale: locale, preset: .timeIndexedProgressiveTranscription)
  }

  /// Locale canónico soportado más cercano al pedido (nil si no hay soporte).
  static func canonicalLocale(for identifier: String) async -> Locale? {
    await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: identifier))
  }

  static func state(for localeIdentifier: String) async -> ModelState {
    guard let locale = await canonicalLocale(for: localeIdentifier) else { return .unsupported }
    let status = await AssetInventory.status(forModules: [probeModule(for: locale)])
    switch status {
    case .installed: return .installed
    case .downloading: return .downloading
    case .supported: return .supported
    case .unsupported: return .unsupported
    @unknown default: return .unsupported
    }
  }

  static func isEnglishInstalled() async -> Bool {
    await state(for: "en-US") == .installed
  }

  /// Descarga e instala el modelo del locale (si falta) e informa progreso 0..1.
  /// `AssetInstallationRequest.progress` es Foundation.Progress (patrón WWDC25 277).
  static func install(
    localeIdentifier: String,
    progress: @escaping @Sendable (Double) -> Void
  ) async throws {
    guard let locale = await canonicalLocale(for: localeIdentifier) else {
      throw CinemaError.unsupportedLocale(locale: localeIdentifier)
    }
    let module = probeModule(for: locale)
    let status = await AssetInventory.status(forModules: [module])
    if status == .installed {
      progress(1)
      return
    }
    guard let request = try await AssetInventory.assetInstallationRequest(supporting: [module]) else {
      // nil = no queda nada por instalar
      progress(1)
      return
    }
    let observation = request.progress.observe(\.fractionCompleted, options: [.new]) { p, _ in
      progress(p.fractionCompleted)
    }
    defer { observation.invalidate() }
    try await request.downloadAndInstall()
    progress(1)
    // reservar para que el sistema no expulse el modelo bajo presión de recursos
    _ = try? await AssetInventory.reserve(locale: locale)
  }
}
