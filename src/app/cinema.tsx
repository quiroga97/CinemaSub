import { router } from 'expo-router';
import * as Brightness from 'expo-brightness';
import { useKeepAwake } from 'expo-keep-awake';
import React, { useCallback, useRef, useState } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { CinemaControls } from '../components/CinemaControls';
import { DevHud } from '../components/DevHud';
import { SubtitleView } from '../components/SubtitleView';
import { useCinema } from '../state/CinemaContext';
import { colors } from '../theme';
import { formatDelay } from '../utils/text';

const CINEMA_BRIGHTNESS = 0.06;

/**
 * Modo cine: fondo negro OLED, subtítulos en la mitad inferior, controles solo con tap.
 * Sin sonido, sin haptics, sin animaciones brillantes. Pantalla siempre activa.
 */
export default function CinemaScreen() {
  const {
    currentSubtitle,
    sessionStatus,
    metrics,
    settings,
    setSettings,
    startSession,
    stopSession,
    error,
  } = useCinema();
  const [controlsVisible, setControlsVisible] = useState(false);
  const [brightness, setBrightness] = useState(CINEMA_BRIGHTNESS);
  const savedBrightness = useRef<number | null>(null);

  useKeepAwake();

  React.useEffect(() => {
    void (async () => {
      try {
        savedBrightness.current = await Brightness.getBrightnessAsync();
        await Brightness.setBrightnessAsync(CINEMA_BRIGHTNESS);
      } catch {
        // sin permiso o fallo puntual: seguimos con el brillo actual
      }
    })();
    void startSession();
    return () => {
      void stopSession();
      if (savedBrightness.current !== null) {
        void Brightness.setBrightnessAsync(savedBrightness.current).catch(() => undefined);
      }
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const handleBrightness = useCallback((value: number) => {
    const clamped = Math.min(1, Math.max(0.02, Math.round(value * 100) / 100));
    setBrightness(clamped);
    void Brightness.setBrightnessAsync(clamped).catch(() => undefined);
  }, []);

  const handleStop = useCallback(() => {
    void stopSession();
    router.back();
  }, [stopSession]);

  return (
    <Pressable
      style={styles.screen}
      onPress={() => setControlsVisible((v) => !v)}
      accessibilityLabel="Mostrar u ocultar controles"
    >
      <View style={styles.topRow} pointerEvents="none">
        {sessionStatus === 'listening' ? (
          <Text style={styles.listening}>● ESCUCHANDO</Text>
        ) : (
          <Text style={styles.statusMuted}>
            {sessionStatus === 'paused' ? 'PAUSA' : sessionStatus === 'error' ? 'ERROR' : ''}
          </Text>
        )}
        {controlsVisible && settings.delayMs !== 0 ? (
          <Text style={styles.delayIndicator}>Delay {formatDelay(settings.delayMs)}</Text>
        ) : null}
      </View>

      {error ? (
        <Text style={styles.error} pointerEvents="none">
          {error}
        </Text>
      ) : null}

      <SubtitleView
        subtitle={currentSubtitle}
        showOriginal={settings.showOriginal}
        textScale={settings.textScale}
        position={settings.position}
      />

      <DevHud metrics={metrics} />

      {controlsVisible ? (
        <CinemaControls
          settings={settings}
          brightness={brightness}
          onChangeSettings={setSettings}
          onBrightness={handleBrightness}
          onStop={handleStop}
        />
      ) : null}
    </Pressable>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: colors.background },
  topRow: {
    position: 'absolute',
    top: 16,
    left: 0,
    right: 0,
    flexDirection: 'row',
    justifyContent: 'center',
    gap: 16,
  },
  listening: { color: '#4A4A4A', fontSize: 11, letterSpacing: 2 },
  statusMuted: { color: '#4A4A4A', fontSize: 11, letterSpacing: 2 },
  delayIndicator: { color: '#5A5A5A', fontSize: 11 },
  error: {
    position: 'absolute',
    top: 60,
    left: 24,
    right: 24,
    color: colors.danger,
    fontSize: 13,
    textAlign: 'center',
  },
});
