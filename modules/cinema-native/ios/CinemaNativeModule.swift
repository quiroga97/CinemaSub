import AVFAudio
import ExpoModulesCore
import Foundation
import Speech
import Translation
import UIKit

// MARK: - Records (contrato tipado; ver modules/cinema-native/src/index.ts)

struct StartSessionRecord: Record {
  @Field var sourceLanguage: String = "en-US"
  @Field var targetLanguage: String = "es"
  @Field var latencyMode: String = "low"
  @Field var includeOriginalText: Bool = false
}

// MARK: - Módulo

public class CinemaNativeModule: Module {
  private var pipeline: CinemaPipeline?
  private let pipelineLock = NSLock()

  public func definition() -> ModuleDefinition {
    Name("CinemaNative")
    Events(
      "onStatusChanged",
      "onModelDownloadProgress",
      "onSubtitle",
      "onPipelineMetrics",
      "onError"
    )

    // MARK: Capacidades

    AsyncFunction("getCapabilities") { () async -> [String: Any?] in
      let speechOK = SpeechTranscriber.isAvailable
      let locales: [String]
      if speechOK {
        locales = await SpeechTranscriber.supportedLocales.map { $0.identifier }.sorted()
      } else {
        locales = []
      }
      return [
        "supportsSpeechAnalyzer": speechOK,
        "supportedSpeechLocales": locales,
        "supportsTranslation": true,
        "osVersion": UIDevice.current.systemVersion,
      ]
    }

    AsyncFunction("requestPermissions") { () async -> [String: Any?] in
      // SpeechAnalyzer (on-device) solo requiere micrófono (docs/research/APPLE_APIS.md §b.3)
      let granted = await AVAudioApplication.requestRecordPermission()
      return [
        "microphoneGranted": granted,
        "speechGranted": true,
      ]
    }

    // MARK: Preparación offline

    AsyncFunction("prepareOfflineModels") { (source: String, target: String) async throws -> Bool in
      let module = self
      module.emitStatus(.preparing)

      // 1) modelo de speech EN con progreso real (AssetInventory)
      try await SpeechModelManager.install(localeIdentifier: source) { progress in
        module.sendEvent("onModelDownloadProgress", [
          "model": "speech",
          "progress": progress,
        ])
      }

      // 2) pack de traducción EN→ES (descarga con consentimiento vía UI del sistema)
      let sourceCode = Self.languageCode(from: source)
      let targetCode = Self.languageCode(from: target)
      module.sendEvent("onModelDownloadProgress", [
        "model": "translation",
        "progress": 0.1,
      ])
      let installed = await TranslationModelManager.requestInstallIfNeeded(
        source: Locale.Language(identifier: sourceCode),
        target: Locale.Language(identifier: targetCode)
      )
      module.sendEvent("onModelDownloadProgress", [
        "model": "translation",
        "progress": 1.0,
      ])
      guard installed else {
        let error = CinemaError.translationModelMissing(source: sourceCode, target: targetCode)
        module.emitError(error)
        module.emitStatus(.error)
        throw error
      }

      module.emitStatus(.idle)
      return true
    }

    AsyncFunction("getOfflineStatus") { () async -> [String: Any?] in
      async let speechInstalled = SpeechModelManager.isEnglishInstalled()
      async let translationInstalled = TranslationModelManager.isSpanishInstalled()
      let speech = await speechInstalled
      let translation = await translationInstalled
      // parcial (solo uno de los dos) también cuenta como no instalado
      let state = (speech && translation) ? "ready" : "notInstalled"
      return [
        "speechEnglishInstalled": speech,
        "translationSpanishInstalled": translation,
        "state": state,
        "progress": 0,
      ]
    }

    // MARK: Sesión

    AsyncFunction("startSession") { (options: StartSessionRecord) async throws in
      let module = self
      module.pipelineLock.lock()
      let existing = module.pipeline
      module.pipelineLock.unlock()
      guard existing == nil else {
        let error = CinemaError.sessionAlreadyRunning
        module.emitError(error)
        throw error
      }

      let locale = try await SpeechRecognitionService.validateSupport(
        localeIdentifier: options.sourceLanguage
      )
      let pipeline = CinemaPipeline(
        includeOriginalText: options.includeOriginalText,
        handlers: PipelineHandlers(
          onStatus: { status in module.emitStatus(status) },
          onSubtitle: { subtitle in module.emitSubtitle(subtitle) },
          onMetrics: { snapshot in module.emitMetrics(snapshot) },
          onError: { error in module.emitError(error) }
        )
      )
      module.pipelineLock.lock()
      module.pipeline = pipeline
      module.pipelineLock.unlock()

      do {
        try await pipeline.start(locale: locale, fastResults: options.latencyMode == "low")
      } catch {
        module.clearPipeline()
        let cinemaError = (error as? CinemaError) ?? .speechAnalyzerFailure(reason: String(describing: error))
        module.emitError(cinemaError)
        module.emitStatus(.error)
        throw cinemaError
      }
    }

    AsyncFunction("stopSession") { () async in
      let pipeline = self.takePipeline()
      await pipeline?.stop()
    }

    AsyncFunction("setSubtitleDelay") { (milliseconds: Double) in
      self.pipeline?.setDelay(milliseconds / 1000.0)
    }

    AsyncFunction("getMetrics") { () -> [String: Any?] in
      self.pipeline?.snapshotMetrics().dictionary() ?? emptyMetricsDictionary()
    }

    // MARK: Ciclo de vida de la app

    // Foreground-only por diseño: al backgroundear se detiene la sesión de forma segura.
    OnAppEntersBackground {
      let pipeline = self.takePipeline()
      Task {
        await pipeline?.stop()
      }
    }

    OnDestroy {
      let pipeline = self.takePipeline()
      Task {
        await pipeline?.stop()
      }
    }
  }

  // MARK: - Privados

  private func takePipeline() -> CinemaPipeline? {
    pipelineLock.lock()
    defer { pipelineLock.unlock() }
    let pipeline = self.pipeline
    self.pipeline = nil
    return pipeline
  }

  private func clearPipeline() {
    pipelineLock.lock()
    pipeline = nil
    pipelineLock.unlock()
  }

  private func emitStatus(_ status: PipelineStatus) {
    sendEvent("onStatusChanged", ["status": status.rawValue] as [String: Any?])
  }

  private func emitError(_ error: CinemaError) {
    sendEvent("onError", [
      "code": error.code,
      "message": error.userMessage,
    ] as [String: Any?])
  }

  private func emitSubtitle(_ subtitle: LocalizedSubtitle) {
    sendEvent("onSubtitle", [
      "id": subtitle.id,
      "originalText": subtitle.originalText,
      "translatedText": subtitle.translatedText,
      "startTime": subtitle.startTime * 1000,
      "endTime": subtitle.endTime.map { $0 * 1000 },
      "isFinal": subtitle.isFinal,
      "confidence": subtitle.confidence,
      "latencyMs": subtitle.latencyMs,
    ] as [String: Any?])
  }

  private func emitMetrics(_ snapshot: PipelineMetricsSnapshot) {
    sendEvent("onPipelineMetrics", snapshot.dictionary())
  }

  /// "en-US" → "en" (Language trabaja con códigos base)
  private static func languageCode(from identifier: String) -> String {
    String(identifier.prefix(while: { $0 != "-" }).prefix(3))
  }
}

// MARK: - Conversión de métricas a diccionario (bridge)

extension PipelineMetricsSnapshot {
  func dictionary() -> [String: Any?] {
    [
      "speechPartialLatencyMs": speechPartialLatencyMs,
      "speechFinalLatencyMs": speechFinalLatencyMs,
      "translationLatencyMs": translationLatencyMs,
      "totalSubtitleLatencyMs": totalSubtitleLatencyMs,
      "medianTotalLatencyMs": medianTotalLatencyMs,
      "p95TotalLatencyMs": p95TotalLatencyMs,
      "segmentsPerMinute": segmentsPerMinute,
      "translationCancellationCount": translationCancellationCount,
      "droppedSegmentCount": droppedSegmentCount,
      "queueSize": queueSize,
    ]
  }
}

private func emptyMetricsDictionary() -> [String: Any?] {
  [
    "speechPartialLatencyMs": nil,
    "speechFinalLatencyMs": nil,
    "translationLatencyMs": nil,
    "totalSubtitleLatencyMs": nil,
    "medianTotalLatencyMs": nil,
    "p95TotalLatencyMs": nil,
    "segmentsPerMinute": 0.0,
    "translationCancellationCount": 0,
    "droppedSegmentCount": 0,
    "queueSize": 0,
  ]
}
