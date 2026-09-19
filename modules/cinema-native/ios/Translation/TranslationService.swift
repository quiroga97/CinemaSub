import Foundation
import Translation

///
/// TranslationService — TranslationSession programática EN→ES, on-device.
///
/// La sesión se crea UNA vez y se reutiliza para todos los segmentos de la película
/// (ver docs/research/APPLE_APIS.md §b.4). Estrategia .lowLatency (iOS 26.4):
/// modelos tradicionales, más rápidos — la elección correcta para subtítulos en vivo.
final class TranslationService: @unchecked Sendable {
  private let lock = NSLock()
  private var session: TranslationSession?

  private let source: Locale.Language
  private let target: Locale.Language
  private let strategy: TranslationSession.Strategy

  init(
    sourceIdentifier: String = "en",
    targetIdentifier: String = "es",
    strategy: TranslationSession.Strategy = .lowLatency
  ) {
    self.source = Locale.Language(identifier: sourceIdentifier)
    self.target = Locale.Language(identifier: targetIdentifier)
    self.strategy = strategy
  }

  /// Abre la sesión. Lanza error tipado si el par de idiomas no está instalado:
  /// hay que pasar por TranslationModelManager antes (pantalla «Preparar modo offline»).
  func open() throws {
    lock.lock()
    defer { lock.unlock() }
    guard session == nil else { return }
    do {
      session = try TranslationSession(
        installedSource: source,
        target: target,
        preferredStrategy: strategy
      )
    } catch {
      throw CinemaError.translationModelMissing(source: source.identifier, target: target.identifier)
    }
  }

  var isOpen: Bool {
    lock.lock()
    defer { lock.unlock() }
    return session != nil
  }

  /// Traduce un segmento corto. Cancelable desde fuera vía Task.cancel().
  func translate(_ text: String) async throws -> String {
    lock.lock()
    let currentSession = session
    lock.unlock()
    guard let currentSession else {
      throw CinemaError.translationModelMissing(source: source.identifier, target: target.identifier)
    }
    do {
      let response = try await currentSession.translate(text)
      return response.targetText
    } catch let error as TranslationError {
      if error.code == .notInstalled {
        throw CinemaError.translationModelMissing(source: source.identifier, target: target.identifier)
      }
      throw CinemaError.translationFailure(reason: String(describing: error.code))
    } catch is CancellationError {
      throw CancellationError()
    } catch {
      throw CinemaError.translationFailure(reason: String(describing: error))
    }
  }

  func close() {
    lock.lock()
    defer { lock.unlock() }
    session?.cancel()
    session = nil
  }
}
