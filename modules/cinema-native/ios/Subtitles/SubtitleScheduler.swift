import Foundation

enum DropReason: String, Sendable {
  case stale          // el pipeline ya va por delante
  case overflow       // cola desbordada: prioridad = ponerse al día
  case noSignificantChange // el final no cambia nada visible
}

enum SchedulerOutcome: Equatable, Sendable {
  case present(LocalizedSubtitle)
  case dropped(DropReason)
  case none
}

/// Subtítulo traducido listo para presentarse, con su hora de presentación ya calculada.
struct ScheduledSubtitle: Equatable, Sendable {
  let subtitle: LocalizedSubtitle
  /// reloj de sesión (s) a partir del cual puede mostrarse
  let readyAt: TimeInterval
}

///
/// SubtitleScheduler — decide cuándo mostrar, sustituir y borrar.
///
/// Reglas:
///  * anti-flash: un subtítulo permanece en pantalla ≥ `minDisplayDuration`
///  * retraso manual: `delay` desplaza la presentación (positivo = más tarde)
///  * prioridad = ponerse al día: si la cola supera `maxQueueDepth`
///    se descartan los más antiguos (diálogo obsoleto)
///  * un `final` sustituye a su versión rápida solo si hay cambio significativo
///
/// Determinista: sin timers; el dueño consulta `due(now:)` en cada tick.
final class SubtitleScheduler: @unchecked Sendable {
  private let lock = NSLock()

  /// retraso manual en segundos (−2 … +4 en la UI)
  private(set) var delay: TimeInterval = 0
  private let minDisplayDuration: TimeInterval
  private let maxQueueDepth: Int

  private var queue: [LocalizedSubtitle] = []
  private var presentedSubtitle: LocalizedSubtitle?
  private var presentedAt: TimeInterval = 0
  private(set) var droppedCount = 0

  init(minDisplayDuration: TimeInterval = 0.7, maxQueueDepth: Int = 3) {
    self.minDisplayDuration = minDisplayDuration
    self.maxQueueDepth = maxQueueDepth
  }

  func setDelay(_ delay: TimeInterval) {
    lock.lock()
    defer { lock.unlock() }
    self.delay = delay
  }

  /// Registra un subtítulo traducido que llega del servicio de traducción.
  func submit(_ subtitle: LocalizedSubtitle) {
    lock.lock()
    defer { lock.unlock() }

    // upgrade fast→final del mismo segmento: reemplaza la versión rápida encolada
    queue.removeAll { $0.id == subtitle.id }

    // descartar lo obsoleto: segmentos anteriores a lo ya presentado
    if let presented = presentedSubtitle, subtitle.startTime < presented.startTime {
      droppedCount += 1
      Log.event(.subtitleDropped, ["reason": DropReason.stale.rawValue])
      return
    }

    queue.append(subtitle)
    queue.sort { $0.startTime < $1.startTime }

    // ponerse al día: la cola no puede crecer indefinidamente
    while queue.count > maxQueueDepth {
      queue.removeFirst()
      droppedCount += 1
      Log.event(.subtitleDropped, ["reason": DropReason.overflow.rawValue])
    }
  }

  /// Consulta periódica. Devuelve el subtítulo a mostrar si su hora llegó.
  func due(now: TimeInterval) -> SchedulerOutcome {
    lock.lock()
    defer { lock.unlock() }

    guard let candidate = queue.first else { return .none }

    let antiFlashReadyAt = presentedAt + minDisplayDuration
    let delayReadyAt = candidate.arrivalTime + delay
    let readyAt = max(delayReadyAt, antiFlashReadyAt)
    guard now >= readyAt else { return .none }

    queue.removeFirst()

    // un final que no cambia significativamente lo ya en pantalla no se repinta
    if let presented = presentedSubtitle,
       presented.id == candidate.id,
       !isSignificantChange(previous: presented.translatedText, next: candidate.translatedText) {
      droppedCount += 1
      Log.event(.subtitleDropped, ["reason": DropReason.noSignificantChange.rawValue])
      return .dropped(.noSignificantChange)
    }

    presentedSubtitle = candidate
    presentedAt = now
    return .present(candidate)
  }

  /// Hora de presentación prevista del primer elemento encolado (diagnóstico).
  func nextReadyAt(now: TimeInterval) -> TimeInterval? {
    lock.lock()
    defer { lock.unlock() }
    guard let candidate = queue.first else { return nil }
    return max(candidate.arrivalTime + delay, presentedAt + minDisplayDuration, now)
  }

  var queueDepth: Int {
    lock.lock()
    defer { lock.unlock() }
    return queue.count
  }

  func reset() {
    lock.lock()
    defer { lock.unlock() }
    queue.removeAll()
    presentedSubtitle = nil
    presentedAt = 0
    droppedCount = 0
  }
}
