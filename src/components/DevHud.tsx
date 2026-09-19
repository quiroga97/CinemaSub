import React from 'react';
import { StyleSheet, Text, View } from 'react-native';
import type { PipelineMetrics } from '../native/cinemaNative';
import { colors } from '../theme';

/** HUD de desarrollo: solo en __DEV__. Nunca en producción. */
export function DevHud({ metrics }: { metrics: PipelineMetrics | null }) {
  if (!__DEV__ || !metrics) return null;
  const speech = metrics.speechFinalLatencyMs ?? metrics.speechPartialLatencyMs;
  return (
    <View style={styles.hud}>
      <Text style={styles.text}>
        Speech: {speech !== undefined ? `${speech} ms` : '—'}
      </Text>
      <Text style={styles.text}>
        Translation: {metrics.translationLatencyMs !== undefined ? `${metrics.translationLatencyMs} ms` : '—'}
      </Text>
      <Text style={styles.text}>
        Total: {metrics.totalSubtitleLatencyMs !== undefined ? `${metrics.totalSubtitleLatencyMs} ms` : '—'}
      </Text>
      <Text style={styles.text}>Queue: {metrics.queueSize}</Text>
      <Text style={styles.text}>Cancel: {metrics.translationCancellationCount}</Text>
      <Text style={styles.text}>Dropped: {metrics.droppedSegmentCount}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  hud: {
    position: 'absolute',
    top: 54,
    left: 12,
    backgroundColor: 'rgba(0,0,0,0.75)',
    borderRadius: 8,
    paddingHorizontal: 10,
    paddingVertical: 8,
  },
  text: { color: colors.hud, fontFamily: 'monospace', fontSize: 11, lineHeight: 15 },
});
