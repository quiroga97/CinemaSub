import { useRouter } from 'expo-router';
import React from 'react';
import { Pressable, ScrollView, StyleSheet, Switch, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { DELAY_OPTIONS_MS } from '../components/CinemaControls';
import { useCinema } from '../state/CinemaContext';
import { colors, fonts, layout } from '../theme';
import { formatDelay } from '../utils/text';

function Row({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <View style={styles.row}>
      <Text style={styles.rowLabel}>{label}</Text>
      {children}
    </View>
  );
}

export default function SettingsScreen() {
  const { settings, setSettings } = useCinema();
  const router = useRouter();

  return (
    <SafeAreaView style={styles.screen}>
      <ScrollView contentContainerStyle={styles.content} keyboardShouldPersistTaps="handled">
        <Text style={styles.title}>Ajustes</Text>

        <Row label="Posición de subtítulos">
          <Pressable
            style={styles.positionToggle}
            onPress={() => setSettings({ position: settings.position === 'bottom' ? 'center' : 'bottom' })}
            accessibilityRole="button"
          >
            <Text style={styles.positionText}>
              {settings.position === 'bottom' ? 'Inferior' : 'Centro'}
            </Text>
          </Pressable>
        </Row>

        <Row label="Mostrar original EN">
          <Switch
            value={settings.showOriginal}
            onValueChange={(value) => setSettings({ showOriginal: value })}
            trackColor={{ false: '#333', true: '#888' }}
            thumbColor="#FFF"
          />
        </Row>

        <View style={styles.sectionLabel}>
          <Text style={styles.sectionLabelText}>Retardo por defecto (ajustable en vivo desde el modo cine)</Text>
        </View>
        <View style={styles.delayRow}>
          {DELAY_OPTIONS_MS.map((ms) => (
            <Pressable
              key={ms}
              onPress={() => setSettings({ delayMs: ms })}
              style={[styles.chip, settings.delayMs === ms && styles.chipActive]}
              accessibilityRole="button"
            >
              <Text style={[styles.chipText, settings.delayMs === ms && styles.chipTextActive]}>
                {formatDelay(ms)}
              </Text>
            </Pressable>
          ))}
        </View>

        <View style={styles.privacy}>
          <Text style={styles.privacyTitle}>Privacidad</Text>
          <Text style={styles.privacyText}>
            El micrófono solo se usa mientras los subtítulos están activos. El audio se procesa en el
            dispositivo para generar los subtítulos. No se almacena ninguna grabación, ni
            transcripciones, ni historial. Nada se envía a servidores.
          </Text>
        </View>

        <Pressable style={styles.back} onPress={() => router.back()} accessibilityRole="button" accessibilityLabel="Volver">
          <Text style={styles.backText}>Volver</Text>
        </Pressable>
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  screen: {
    flex: 1,
    backgroundColor: colors.background,
  },
  content: {
    flexGrow: 1,
    padding: layout.screenPadding,
    gap: 18,
  },
  title: { color: colors.subtitle, fontSize: 32, fontWeight: '800', marginTop: 24 },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    minHeight: 44,
  },
  rowLabel: { color: colors.subtitleOriginal, fontSize: fonts.control + 1 },
  positionToggle: { borderWidth: 1, borderColor: '#333', borderRadius: 8, paddingHorizontal: 14, paddingVertical: 8 },
  positionText: { color: colors.controlActive, fontSize: fonts.control },
  sectionLabel: { marginTop: 6 },
  sectionLabelText: { color: colors.control, fontSize: fonts.control - 2 },
  delayRow: { flexDirection: 'row', flexWrap: 'wrap', gap: 6 },
  chip: { paddingHorizontal: 10, paddingVertical: 6, borderRadius: 8, borderWidth: 1, borderColor: '#333' },
  chipActive: { backgroundColor: '#FFF' },
  chipText: { color: colors.control, fontSize: fonts.control - 2 },
  chipTextActive: { color: '#000', fontWeight: '600' },
  privacy: { marginTop: 24, gap: 8 },
  privacyTitle: { color: colors.subtitleOriginal, fontSize: fonts.control + 1, fontWeight: '600' },
  privacyText: { color: colors.control, fontSize: fonts.control, lineHeight: 21 },
  back: { alignSelf: 'flex-start', marginTop: 12, paddingVertical: 10, paddingHorizontal: 16 },
  backText: { color: colors.controlActive, fontSize: fonts.control },
});
