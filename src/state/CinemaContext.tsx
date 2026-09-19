import React, {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
} from 'react';
import {
  cinemaNative,
  type Capabilities,
  type OfflineModelStatus,
  type PipelineMetrics,
  type SessionStatusCode,
  type SubtitleEvent,
} from '../native/cinemaNative';

export interface CinemaSettings {
  /** escala del texto de subtítulos */
  textScale: number;
  /** mostrar la línea original en inglés bajo/delante del español */
  showOriginal: boolean;
  /** retardo manual en ms aplicado en el scheduler nativo */
  delayMs: number;
  /** posición del bloque de subtítulos */
  position: 'bottom' | 'center';
}

const DEFAULT_SETTINGS: CinemaSettings = {
  textScale: 1,
  showOriginal: false,
  delayMs: 0,
  position: 'bottom',
};

interface CinemaState {
  capabilities: Capabilities | null;
  offline: OfflineModelStatus | null;
  preparing: boolean;
  sessionStatus: SessionStatusCode;
  currentSubtitle: SubtitleEvent | null;
  metrics: PipelineMetrics | null;
  error: string | null;
  settings: CinemaSettings;
  startSession: (overrides?: Partial<CinemaSettings>) => Promise<void>;
  stopSession: () => Promise<void>;
  prepareOffline: () => Promise<void>;
  refreshStatus: () => Promise<void>;
  setSettings: (patch: Partial<CinemaSettings>) => void;
  dismissError: () => void;
}

const CinemaContext = createContext<CinemaState | null>(null);

export function CinemaProvider({ children }: { children: React.ReactNode }) {
  const [capabilities, setCapabilities] = useState<Capabilities | null>(null);
  const [offline, setOffline] = useState<OfflineModelStatus | null>(null);
  const [preparing, setPreparing] = useState(false);
  const [sessionStatus, setSessionStatus] = useState<SessionStatusCode>('idle');
  const [currentSubtitle, setCurrentSubtitle] = useState<SubtitleEvent | null>(null);
  const [metrics, setMetrics] = useState<PipelineMetrics | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [settings, setSettingsState] = useState<CinemaSettings>(DEFAULT_SETTINGS);
  const settingsRef = useRef(settings);
  settingsRef.current = settings;

  useEffect(() => {
    let mounted = true;
    const subscriptions = [
      cinemaNative.addListener('onStatusChanged', ({ status }) => {
        if (mounted) setSessionStatus(status);
      }),
      cinemaNative.addListener('onSubtitle', (subtitle) => {
        if (mounted) setCurrentSubtitle(subtitle);
      }),
      cinemaNative.addListener('onPipelineMetrics', (m) => {
        if (mounted) setMetrics(m);
      }),
      cinemaNative.addListener('onModelDownloadProgress', ({ progress }) => {
        if (!mounted) return;
        setOffline((prev) =>
          prev ? { ...prev, state: 'downloading', progress } : prev,
        );
      }),
      cinemaNative.addListener('onError', ({ message }) => {
        if (mounted) setError(message);
      }),
    ];
    cinemaNative
      .getCapabilities()
      .then((caps) => {
        if (!mounted) return;
        setCapabilities(caps);
        return cinemaNative.getOfflineStatus();
      })
      .then((status) => {
        if (mounted && status) setOffline(status);
      })
      .catch((e: unknown) => {
        if (mounted) setError(e instanceof Error ? e.message : String(e));
      });
    return () => {
      mounted = false;
      subscriptions.forEach((s) => s.remove());
    };
  }, []);

  const refreshStatus = useCallback(async () => {
    try {
      const status = await cinemaNative.getOfflineStatus();
      setOffline(status);
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    }
  }, []);

  const prepareOffline = useCallback(async () => {
    setPreparing(true);
    setError(null);
    try {
      await cinemaNative.requestPermissions();
      await cinemaNative.prepareOfflineModels('en-US', 'es');
      await refreshStatus();
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setPreparing(false);
    }
  }, [refreshStatus]);

  const startSession = useCallback(async (overrides?: Partial<CinemaSettings>) => {
    setError(null);
    const effective = { ...settingsRef.current, ...overrides };
    try {
      const permissions = await cinemaNative.requestPermissions();
      if (!permissions.microphoneGranted) {
        setError('Se necesita permiso de micrófono para generar los subtítulos.');
        setSessionStatus('error');
        return;
      }
      await cinemaNative.startSession({
        sourceLanguage: 'en-US',
        targetLanguage: 'es',
        latencyMode: 'low',
        includeOriginalText: effective.showOriginal,
      });
      await cinemaNative.setSubtitleDelay(effective.delayMs);
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
      setSessionStatus('error');
    }
  }, []);

  const stopSession = useCallback(async () => {
    try {
      await cinemaNative.stopSession();
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setCurrentSubtitle(null);
    }
  }, []);

  const setSettings = useCallback((patch: Partial<CinemaSettings>) => {
    setSettingsState((prev) => {
      const next = { ...prev, ...patch };
      if (patch.delayMs !== undefined && patch.delayMs !== prev.delayMs) {
        void cinemaNative.setSubtitleDelay(patch.delayMs);
      }
      if (patch.showOriginal !== undefined) {
        // includeOriginalText es opción de sesión completa; lo aplicamos en la próxima sesión.
        // Evitar reiniciar el pipeline en caliente en el MVP.
      }
      return next;
    });
  }, []);

  const dismissError = useCallback(() => setError(null), []);

  const value = useMemo<CinemaState>(
    () => ({
      capabilities,
      offline,
      preparing,
      sessionStatus,
      currentSubtitle,
      metrics,
      error,
      settings,
      startSession,
      stopSession,
      prepareOffline,
      refreshStatus,
      setSettings,
      dismissError,
    }),
    [
      capabilities,
      offline,
      preparing,
      sessionStatus,
      currentSubtitle,
      metrics,
      error,
      settings,
      startSession,
      stopSession,
      prepareOffline,
      refreshStatus,
      setSettings,
      dismissError,
    ],
  );

  return <CinemaContext.Provider value={value}>{children}</CinemaContext.Provider>;
}

export function useCinema(): CinemaState {
  const ctx = useContext(CinemaContext);
  if (!ctx) throw new Error('useCinema debe usarse dentro de <CinemaProvider>');
  return ctx;
}
