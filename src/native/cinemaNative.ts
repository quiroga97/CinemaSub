import CinemaNative, {
  type Capabilities,
  type CinemaNativeEvents,
  type OfflineModelStatus,
  type PermissionResult,
  type PipelineMetrics,
  type SessionStatusCode,
  type StartSessionOptions,
  type SubtitleEvent,
} from '../../modules/cinema-native/src';

export type {
  Capabilities,
  CinemaNativeEvents,
  OfflineModelStatus,
  PermissionResult,
  PipelineMetrics,
  SessionStatusCode,
  StartSessionOptions,
  SubtitleEvent,
};

/** Suscripción a un evento nativo (misma forma que EventSubscription de Expo). */
export interface CinemaEventSubscription {
  remove: () => void;
}

/** Fachada tipada sobre el módulo nativo. Único punto de contacto UI ↔ nativo. */
export const cinemaNative = {
  getCapabilities: (): Promise<Capabilities> => CinemaNative.getCapabilities(),

  requestPermissions: (): Promise<PermissionResult> => CinemaNative.requestPermissions(),

  prepareOfflineModels: (source = 'en-US', target = 'es'): Promise<void> =>
    CinemaNative.prepareOfflineModels(source, target),

  getOfflineStatus: (): Promise<OfflineModelStatus> => CinemaNative.getOfflineStatus(),

  startSession: (options: Partial<StartSessionOptions> = {}): Promise<void> =>
    CinemaNative.startSession({
      sourceLanguage: 'en-US',
      targetLanguage: 'es',
      latencyMode: 'low',
      includeOriginalText: false,
      ...options,
    }),

  stopSession: (): Promise<void> => CinemaNative.stopSession(),

  setSubtitleDelay: (ms: number): Promise<void> => CinemaNative.setSubtitleDelay(ms),

  getMetrics: (): Promise<PipelineMetrics> => CinemaNative.getMetrics(),

  addListener<K extends keyof CinemaNativeEvents>(
    event: K,
    listener: CinemaNativeEvents[K],
  ): CinemaEventSubscription {
    return CinemaNative.addListener(event, listener);
  },
};
