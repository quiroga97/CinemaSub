import { Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import React from 'react';
import { CinemaProvider } from '../state/CinemaContext';
import { colors } from '../theme';

export default function RootLayout() {
  return (
    <CinemaProvider>
      <StatusBar style="light" />
      <Stack
        screenOptions={{
          headerShown: false,
          contentStyle: { backgroundColor: colors.background },
          animation: 'fade',
        }}
      />
    </CinemaProvider>
  );
}
