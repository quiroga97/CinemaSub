import { NativeModule, requireNativeModule } from 'expo';

/**
 * Contrato CinemaNative ↔ React Native.
 * Regla de oro: por este puente NO circula audio PCM ni nada pesado.
 * Solo eventos ligeros con texto ya estabilizado/traducido y métricas sin contenido.
 */

export type SessionStatusCode =
  | 'idle'
  | 'preparing'
  | 'listening'
  | 'paused'
  | 'stopped'
  | 'error';

export interface Capabilities {
  /** true si el dispositivo soporta SpeechAnalyzer (iOS 26+) */
  supportsSpeechAnalyzer: boolean;
  supportedSpeechLocales: string[];
  /** true si el framework Translation está disponible */
  supportsTranslation: boolean;
  osVersion: string;
}

export interface OfflineModelStatus {
  /** modelo de speech en-US instalado y listo para uso offline */
  speechEnglishInstalled: boolean;
  /** pack de traducción en→es instalado y listo para uso offline */
  translationSpanishInstalled: boolean;
  state: 'unknown' | 'notInstalled' | 'downloading' | 'ready' | 'error';
  /** progreso 0..1 de la descarga en curso, si la hay */
  progress: number;
  error?: string;
}

export interface SubtitleEvent {
  id: string;
  /** texto original en inglés (solo se envía si includeOriginalText) */
  originalText: string;
  /** traducción al español lista para mostrar */
  translatedText: string;
  /** ms desde el inicio de la sesión */
  startTime: number;
  endTime?: number;
  /** false = subtítulo rápido (parcial estable); true = subtítulo final */
  isFinal: boolean;
  confidence?: number;
  /** latencia total pipeline hasta presentar este subtítulo, en ms */
  latencyMs: number;
}

export interface PipelineMetrics {
  speechPartialLatencyMs?: number;
  speechFinalLatencyMs?: number;
  translationLatencyMs?: number;
  totalSubtitleLatencyMs?: number;
  /** p50 de la latencia total (ventana móvil) */
  medianTotalLatencyMs?: number;
  /** p95 de la latencia total (ventana móvil) */
  p95TotalLatencyMs?: number;
  segmentsPerMinute: number;
  translationCancellationCount: number;
  droppedSegmentCount: number;
  queueSize: number;
}

export interface StartSessionOptions {
  sourceLanguage: string;
  targetLanguage: string;
  latencyMode: 'low' | 'high';
  includeOriginalText: boolean;
}

export interface PermissionResult {
  microphoneGranted: boolean;
  speechGranted: boolean;
}

export type CinemaNativeEvents = {
  onStatusChanged: (event: { status: SessionStatusCode; reason?: string }) => void;
  onModelDownloadProgress: (event: { model: 'speech' | 'translation'; progress: number }) => void;
  onSubtitle: (event: SubtitleEvent) => void;
  onPipelineMetrics: (event: PipelineMetrics) => void;
  onError: (event: { code: string; message: string }) => void;
}

declare class CinemaNativeModuleType extends NativeModule<CinemaNativeEvents> {
  getCapabilities(): Promise<Capabilities>;
  requestPermissions(): Promise<PermissionResult>;
  prepareOfflineModels(sourceLanguage: string, targetLanguage: string): Promise<void>;
  getOfflineStatus(): Promise<OfflineModelStatus>;
  startSession(options: StartSessionOptions): Promise<void>;
  stopSession(): Promise<void>;
  setSubtitleDelay(milliseconds: number): Promise<void>;
  getMetrics(): Promise<PipelineMetrics>;
}

export default requireNativeModule<CinemaNativeModuleType>('CinemaNative');
