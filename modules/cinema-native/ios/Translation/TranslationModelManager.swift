import Foundation
import SwiftUI
import Translation
import UIKit

///
/// TranslationModelManager — estado y descarga del par EN→ES.
///
/// LIMITACIÓN OFICIAL DOCUMENTADA (docs/research/APPLE_APIS.md §b.4):
/// no existe API programática con progreso para descargar packs de Translation.
/// La primera descarga requiere consentimiento del usuario vía `prepareTranslation()`,
/// que solo se obtiene desde un flujo `.translationTask` (SwiftUI). Aquí se presenta
/// una vista auxiliar invisible que ejecuta exactamente ese flujo.
enum TranslationModelManager {

  enum ModelState: String, Sendable {
    case installed
    case supported   // descargable pero no instalado
    case unsupported
  }

  static func state(
    source: Locale.Language = Locale.Language(identifier: "en"),
    target: Locale.Language = Locale.Language(identifier: "es")
  ) async -> ModelState {
    let status = await LanguageAvailability(preferredStrategy: .lowLatency)
      .status(from: source, to: target)
    switch status {
    case .installed: return .installed
    case .supported: return .supported
    case .unsupported: return .unsupported
    @unknown default: return .unsupported
    }
  }

  static func isSpanishInstalled() async -> Bool {
    await state() == .installed
  }

  /// Si el par no está instalado, dispara el flujo oficial de descarga (UI del sistema).
  /// Devuelve true si tras el flujo el par queda instalado (o ya lo estaba).
  @MainActor
  static func requestInstallIfNeeded(
    source: Locale.Language = Locale.Language(identifier: "en"),
    target: Locale.Language = Locale.Language(identifier: "es")
  ) async -> Bool {
    let before = await state(source: source, target: target)
    if before == .installed { return true }
    guard before == .supported else { return false }

    // presentar vista auxiliar invisible con .translationTask + prepareTranslation()
    guard let presenter = topViewController() else { return false }

    let box = ResumeBox()
    let host = UIHostingController(
      rootView: DownloadBootstrapView(source: source, target: target) {
        box.resume()
      }
    )
    host.view.backgroundColor = .clear
    host.view.isUserInteractionEnabled = false // la UI de descarga la pone el sistema
    host.modalPresentationStyle = .overFullScreen
    presenter.present(host, animated: false)

    // seguridad: nunca colgar la UI más de 3 minutos esperando al usuario
    let timeout = Task { @MainActor in
      try? await Task.sleep(nanoseconds: 180_000_000_000)
      host.dismiss(animated: false)
      box.resume()
    }
    await box.wait()
    timeout.cancel()
    host.dismiss(animated: false)

    let after = await state(source: source, target: target)
    return after == .installed
  }

  // MARK: - privados

  private final class ResumeBox: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Never>?
    private var resumed = false

    func wait() async {
      await withCheckedContinuation { cont in
        lock.lock()
        defer { lock.unlock() }
        if resumed {
          cont.resume()
        } else {
          continuation = cont
        }
      }
    }

    func resume() {
      lock.lock()
      defer { lock.unlock() }
      guard !resumed else { return }
      resumed = true
      continuation?.resume()
      continuation = nil
    }
  }

  private struct DownloadBootstrapView: View {
    let source: Locale.Language
    let target: Locale.Language
    let onDone: @Sendable () -> Void

    var body: some View {
      Color.clear
        .frame(width: 1, height: 1)
        .translationTask(source: source, target: target) { session in
          do {
            try await session.prepareTranslation()
          } catch {
            Log.failure(.modelDownloadProgress, error)
          }
          onDone()
        }
    }
  }

  private static func topViewController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    guard let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first,
          let root = scene.keyWindow?.rootViewController else { return nil }
    var top = root
    while let presented = top.presentedViewController { top = presented }
    return top
  }
}
