import React, { useMemo } from 'react';
import { StyleSheet, Text, useWindowDimensions, View } from 'react-native';
import type { SubtitleEvent } from '../native/cinemaNative';
import { colors, fonts, layout } from '../theme';
import { splitTwoLines } from '../utils/text';

interface SubtitleViewProps {
  subtitle: SubtitleEvent | null;
  showOriginal: boolean;
  textScale: number;
  position: 'bottom' | 'center';
}

/**
 * Presentación del subtítulo: máx 2 líneas equilibradas, tipografía grande,
 * alto contraste, mitad inferior (o centro). Sin animaciones brillantes.
 */
export function SubtitleView({ subtitle, showOriginal, textScale, position }: SubtitleViewProps) {
  const { width } = useWindowDimensions();

  const fontSize = Math.round(fonts.subtitleBase * textScale);
  const maxCharsPerLine = Math.max(
    16,
    Math.floor((width * layout.subtitleMaxWidthRatio) / (fontSize * 0.55)),
  );

  const lines = useMemo(
    () => splitTwoLines(subtitle?.translatedText ?? '', maxCharsPerLine),
    [subtitle?.translatedText, maxCharsPerLine],
  );

  if (!subtitle || subtitle.translatedText.length === 0) return null;

  return (
    <View style={[styles.wrap, position === 'center' ? styles.center : styles.bottom]}>
      {showOriginal && subtitle.originalText.length > 0 ? (
        <Text style={[styles.original, { fontSize: Math.round(fonts.subtitleOriginalBase * textScale) }]} numberOfLines={1}>
          {subtitle.originalText}
        </Text>
      ) : null}
      {lines.map((line, index) => (
        <Text key={index} style={[styles.line, { fontSize }]} numberOfLines={1} adjustsFontSizeToFit={false}>
          {line}
        </Text>
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: {
    alignSelf: 'center',
    width: `${Math.round(layout.subtitleMaxWidthRatio * 100)}%`,
    alignItems: 'center',
    gap: 2,
    paddingHorizontal: 8,
  },
  bottom: { position: 'absolute', bottom: '22%' },
  center: { position: 'absolute', top: '42%' },
  original: { color: colors.subtitleOriginal, textAlign: 'center' },
  line: {
    color: colors.subtitle,
    fontWeight: '700',
    textAlign: 'center',
    textShadowColor: 'rgba(0,0,0,0.9)',
    textShadowRadius: 2,
  },
});
