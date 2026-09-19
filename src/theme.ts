import { StyleSheet } from 'react-native';

/** Sistema visual mínimo. Modo cine: negro OLED puro, sin adornos. */
export const colors = {
  background: '#000000',
  subtitle: '#FFFFFF',
  subtitleOriginal: '#B8B8B8',
  control: '#9A9A9A',
  controlActive: '#FFFFFF',
  danger: '#FF6B6B',
  success: '#5BD75B',
  hud: '#7A7A7A',
} as const;

export const fonts = {
  subtitleBase: 30,
  subtitleOriginalBase: 16,
  control: 15,
} as const;

export const layout = {
  screenPadding: 24,
  subtitleMaxWidthRatio: 0.92,
} as const;

export const baseStyles = StyleSheet.create({
  screen: {
    flex: 1,
    backgroundColor: colors.background,
  },
});
