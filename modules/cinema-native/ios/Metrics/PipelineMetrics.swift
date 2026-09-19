import Foundation

/// Snapshot inmutable de métricas (cruza el bridge hacia el Developer HUD).
struct PipelineMetricsSnapshot: Equatable, Sendable {
  var speechPartialLatencyMs: Int?
  var speechFinalLatencyMs: Int?
  var translationLatencyMs: Int?
  var totalSubtitleLatencyMs: Int?
  var medianTotalLatencyMs: Int?
  var p95TotalLatencyMs: Int?
  var segmentsPerMinute: Double = 0
  var translationCancellationCount: Int = 0
  var droppedSegmentCount: Int = 0
  var queueSize: Int = 0
}

///
/// PipelineMetrics — instrumentación de latencia y salud del pipeline.
/// Solo números: ningún contenido hablado pasa por aquí.
final class PipelineMetrics: @unchecked Sendable {
  private let lock = NSLock()
  private let windowSize: Int

  private var partialLatencies: [Int] = []
  private var finalLatencies: [Int] = []
  private var translationLatencies: [Int] = []
  private var totalLatencies: [Int] = []
  private var segmentTimes: [TimeInterval] = []
  private(set) var cancellationCount = 0
  private(set) var droppedCount = 0

  init(windowSize: Int = 60) {
    self.windowSize = windowSize
  }

  func recordPartialLatency(ms: Int) {
    lock.lock(); defer { lock.unlock() }
    append(&partialLatencies, ms)
  }

  func recordFinalLatency(ms: Int) {
    lock.lock(); defer { lock.unlock() }
    append(&finalLatencies, ms)
  }

  func recordTranslationLatency(ms: Int) {
    lock.lock(); defer { lock.unlock() }
    append(&translationLatencies, ms)
  }

  func recordTotalLatency(ms: Int, at sessionTime: TimeInterval) {
    lock.lock(); defer { lock.unlock() }
    append(&totalLatencies, ms)
    segmentTimes.append(sessionTime)
    let cutoff = sessionTime - 60
    segmentTimes.removeAll { $0 < cutoff }
  }

  func recordCancellation() {
    lock.lock(); defer { lock.unlock() }
    cancellationCount += 1
  }

  func recordDrop() {
    lock.lock(); defer { lock.unlock() }
    droppedCount += 1
  }

  func snapshot(queueSize: Int, now: TimeInterval) -> PipelineMetricsSnapshot {
    lock.lock(); defer { lock.unlock() }
    var snap = PipelineMetricsSnapshot()
    snap.speechPartialLatencyMs = partialLatencies.last
    snap.speechFinalLatencyMs = finalLatencies.last
    snap.translationLatencyMs = translationLatencies.last
    snap.totalSubtitleLatencyMs = totalLatencies.last
    snap.medianTotalLatencyMs = percentile(totalLatencies, 0.5)
    snap.p95TotalLatencyMs = percentile(totalLatencies, 0.95)
    let cutoff = now - 60
    let recent = segmentTimes.filter { $0 >= cutoff }
    snap.segmentsPerMinute = Double(recent.count)
    snap.translationCancellationCount = cancellationCount
    snap.droppedSegmentCount = droppedCount
    snap.queueSize = queueSize
    return snap
  }

  func reset() {
    lock.lock(); defer { lock.unlock() }
    partialLatencies.removeAll()
    finalLatencies.removeAll()
    translationLatencies.removeAll()
    totalLatencies.removeAll()
    segmentTimes.removeAll()
    cancellationCount = 0
    droppedCount = 0
  }

  // MARK: - privados

  private func append(_ buffer: inout [Int], _ value: Int) {
    buffer.append(value)
    if buffer.count > windowSize {
      buffer.removeFirst(buffer.count - windowSize)
    }
  }

  private func percentile(_ values: [Int], _ p: Double) -> Int? {
    guard !values.isEmpty else { return nil }
    let sorted = values.sorted()
    let index = min(sorted.count - 1, Int((p * Double(sorted.count - 1)).rounded()))
    return sorted[index]
  }
}
