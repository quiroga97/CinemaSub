import { useRouter } from 'expo-router';
import React from 'react';
import { Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useCinema } from '../state/CinemaContext';
import { colors, fonts, layout } from '../theme';

function ModelRow({ label, ready }: { label: string; ready: boolean | undefined }) {
  return (
    <View style={styles.modelRow}>
      <Text style={[styles.modelMark, ready === true && styles.modelMarkReady]}>
        {ready === true ? '✓' : ready === false ? '○' : '·'}
      </Text>
      <Text style={styles.modelLabel}>{label}</Text>
    </View>
  );
}

export default function HomeScreen() {
  const { offline, preparing, prepareOffline, capabilities, error } = useCinema();
  const router = useRouter();

  const modelsReady =
    offline?.speechEnglishInstalled === true && offline?.translationSpanishInstalled === true;

  return (
    <SafeAreaView style={styles.screen}>
      <ScrollView contentContainerStyle={styles.content} keyboardShouldPersistTaps="handled">
        <View style={styles.hero}>
          <Text style={styles.title}>CinemaSubs</Text>
          <Text style={styles.subtitle}>English → Español</Text>
        </View>

        <View style={styles.statusCard}>
          <ModelRow
            label="Speech English (on-device)"
            ready={offline?.speechEnglishInstalled}
          />
          <ModelRow
            label="Translation English → Español"
            ready={offline?.translationSpanishInstalled}
          />
          {modelsReady ? (
            <Text style={styles.offlineOk}>✓ Funciona sin conexión</Text>
          ) : (
            <Text style={styles.offlinePending}>
              Prepara los modelos antes de entrar al cine
            </Text>
          )}
          {capabilities && !capabilities.supportsSpeechAnalyzer ? (
            <Text style={styles.offlinePending}>
              Este dispositivo no soporta SpeechAnalyzer (se requiere iOS 26+)
            </Text>
          ) : null}
        </View>

        {error ? <Text style={styles.error}>{error}</Text> : null}

        <View style={styles.actions}>
          <Pressable
            style={[styles.button, styles.secondaryButton]}
            onPress={() => void prepareOffline()}
            disabled={preparing}
            accessibilityRole="button"
            accessibilityLabel="Preparar modo offline"
          >
            <Text style={styles.secondaryButtonText}>
              {preparing ? 'Preparando…' : 'Preparar modo offline'}
            </Text>
          </Pressable>

          <Pressable
            style={[styles.button, styles.primaryButton]}
            onPress={() => router.push('/cinema')}
            accessibilityRole="button"
            accessibilityLabel="Iniciar subtítulos"
          >
            <Text style={styles.primaryButtonText}>INICIAR SUBTÍTULOS</Text>
          </Pressable>
        </View>
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
    paddingHorizontal: layout.screenPadding,
    justifyContent: 'center',
    gap: 32,
  },
  hero: { alignItems: 'center', gap: 6 },
  title: { color: colors.subtitle, fontSize: 40, fontWeight: '800' },
  subtitle: { color: colors.control, fontSize: fonts.control + 2 },
  statusCard: { gap: 10 },
  modelRow: { flexDirection: 'row', alignItems: 'center', gap: 10 },
  modelMark: { color: colors.control, fontSize: 18, width: 22, textAlign: 'center' },
  modelMarkReady: { color: colors.success },
  modelLabel: { color: colors.subtitleOriginal, fontSize: fonts.control + 1 },
  offlineOk: { color: colors.success, fontSize: fonts.control, marginTop: 4 },
  offlinePending: { color: colors.control, fontSize: fonts.control },
  error: { color: colors.danger, fontSize: fonts.control },
  actions: { gap: 12 },
  button: {
    borderRadius: 14,
    paddingVertical: 16,
    alignItems: 'center',
  },
  secondaryButton: { borderWidth: 1, borderColor: '#333' },
  secondaryButtonText: { color: colors.controlActive, fontSize: fonts.control + 1 },
  primaryButton: { backgroundColor: '#FFFFFF' },
  primaryButtonText: { color: '#000000', fontSize: fonts.control + 3, fontWeight: '700' },
});
