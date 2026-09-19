import React from 'react';
import { Pressable, StyleSheet, Switch, Text, View } from 'react-native';
import type { CinemaSettings } from '../state/CinemaContext';
import { colors, fonts } from '../theme';
import { formatDelay } from '../utils/text';

export const DELAY_OPTIONS_MS = [-2000, -1500, -1000, -500, 0, 500, 1000, 1500, 2000, 3000, 4000];
const TEXT_SCALES = [0.85, 1, 1.25, 1.5];

interface CinemaControlsProps {
  settings: CinemaSettings;
  brightness: number;
  onChangeSettings: (patch: Partial<CinemaSettings>) => void;
  onBrightness: (value: number) => void;
  onStop: () => void;
}

function SectionLabel({ children }: { children: React.ReactNode }) {
  return <Text style={styles.sectionLabel}>{children}</Text>;
}

/**
 * Panel de controles del modo cine. Aparece solo con tap. Sin haptics, sin sonido.
 */
export function CinemaControls({
  settings,
  brightness,
  onChangeSettings,
  onBrightness,
  onStop,
}: CinemaControlsProps) {
  const scaleIndex = TEXT_SCALES.indexOf(settings.textScale);

  return (
    <View style={styles.panel} pointerEvents="auto">
      <SectionLabel>Retardo</SectionLabel>
      <View style={styles.chipRow}>
        {DELAY_OPTIONS_MS.map((ms) => (
          <Pressable
            key={ms}
            onPress={() => onChangeSettings({ delayMs: ms })}
            style={[styles.chip, settings.delayMs === ms && styles.chipActive]}
            accessibilityRole="button"
            accessibilityLabel={`Retardo ${formatDelay(ms)}`}
          >
            <Text style={[styles.chipText, settings.delayMs === ms && styles.chipTextActive]}>
              {formatDelay(ms)}
            </Text>
          </Pressable>
        ))}
      </View>

      <SectionLabel>Tamaño del texto</SectionLabel>
      <View style={styles.row}>
        <Pressable
          style={styles.stepButton}
          onPress={() =>
            onChangeSettings({ textScale: TEXT_SCALES[Math.max(0, (scaleIndex < 0 ? 1 : scaleIndex) - 1)] })
          }
          accessibilityRole="button"
          accessibilityLabel="Reducir texto"
        >
          <Text style={styles.stepButtonText}>A−</Text>
        </Pressable>
        <Pressable
          style={styles.stepButton}
          onPress={() =>
            onChangeSettings({
              textScale: TEXT_SCALES[Math.min(TEXT_SCALES.length - 1, (scaleIndex < 0 ? 1 : scaleIndex) + 1)],
            })
          }
          accessibilityRole="button"
          accessibilityLabel="Aumentar texto"
        >
          <Text style={styles.stepButtonText}>A+</Text>
        </Pressable>
      </View>

      <SectionLabel>Brillo</SectionLabel>
      <View style={styles.row}>
        <Pressable
          style={styles.stepButton}
          onPress={() => onBrightness(Math.max(0.02, brightness - 0.05))}
          accessibilityRole="button"
          accessibilityLabel="Bajar brillo"
        >
          <Text style={styles.stepButtonText}>−</Text>
        </Pressable>
        <Text style={styles.brightnessValue}>{Math.round(brightness * 100)}%</Text>
        <Pressable
          style={styles.stepButton}
          onPress={() => onBrightness(Math.min(1, brightness + 0.05))}
          accessibilityRole="button"
          accessibilityLabel="Subir brillo"
        >
          <Text style={styles.stepButtonText}>+</Text>
        </Pressable>
      </View>

      <View style={styles.rowSpaceBetween}>
        <Text style={styles.sectionLabel}>Original EN</Text>
        <Switch
          value={settings.showOriginal}
          onValueChange={(value) => onChangeSettings({ showOriginal: value })}
          trackColor={{ false: '#333', true: '#888' }}
          thumbColor="#FFF"
        />
      </View>

      <Pressable style={styles.stopButton} onPress={onStop} accessibilityRole="button" accessibilityLabel="Detener subtítulos">
        <Text style={styles.stopButtonText}>Stop</Text>
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  panel: {
    position: 'absolute',
    left: 0,
    right: 0,
    bottom: 0,
    backgroundColor: 'rgba(0,0,0,0.96)',
    borderTopWidth: StyleSheet.hairlineWidth,
    borderTopColor: '#222',
    paddingHorizontal: 20,
    paddingTop: 16,
    paddingBottom: 34,
    gap: 8,
  },
  sectionLabel: { color: colors.control, fontSize: fonts.control - 2, textTransform: 'uppercase', letterSpacing: 1 },
  chipRow: { flexDirection: 'row', flexWrap: 'wrap', gap: 6 },
  chip: {
    paddingHorizontal: 10,
    paddingVertical: 6,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#333',
  },
  chipActive: { backgroundColor: '#FFF' },
  chipText: { color: colors.control, fontSize: fonts.control - 2 },
  chipTextActive: { color: '#000', fontWeight: '600' },
  row: { flexDirection: 'row', alignItems: 'center', gap: 16 },
  rowSpaceBetween: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' },
  stepButton: {
    width: 46,
    height: 40,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#333',
    alignItems: 'center',
    justifyContent: 'center',
  },
  stepButtonText: { color: colors.controlActive, fontSize: fonts.control },
  brightnessValue: { color: colors.controlActive, fontSize: fonts.control, minWidth: 44, textAlign: 'center' },
  stopButton: {
    marginTop: 10,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: colors.danger,
    paddingVertical: 12,
    alignItems: 'center',
  },
  stopButtonText: { color: colors.danger, fontSize: fonts.control + 1, fontWeight: '600' },
});
