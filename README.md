# CinemaSubs

Subtítulos en español, en tiempo real, para películas en inglés — directamente desde el
micrófono de tu iPhone. Diseñado para usarse en el cine: pantalla negra OLED, texto grande,
máximo 2 líneas, cero molestias a las personas de alrededor.

```
Audio de la película → micrófono → SpeechAnalyzer (EN) → estabilizador
→ Apple Translation EN→ES on-device → scheduler → subtítulos en español
```

- **Latencia**: subtítulo estable en 1–2 s (objetivo), instrumentado y visible en el HUD de dev.
- **Offline**: todo on-device tras preparar los modelos una vez (modo avión soportado).
- **Privacidad**: no se guarda audio ni transcripciones; nada sale del dispositivo.

## Requisitos

- iPhone con **iOS 26.4+** (probado en iOS 27).
- Desarrollo desde **Windows 11 sin Mac**: builds iOS en la nube vía **EAS Build**.
- Cuenta Expo + Apple Developer Program (para instalar en dispositivo físico).

## Arranque rápido (Windows)

```powershell
pnpm install
pnpm typecheck && pnpm test
pnpm dlx expo-doctor@latest

eas login
eas device:create        # registrar el iPhone (una vez)
eas build --platform ios --profile development
# instalar el build en el iPhone (QR/enlace), luego:
pnpm start               # Metro; iPhone en la misma Wi-Fi
```

Guía completa: [docs/WINDOWS_SETUP.md](docs/WINDOWS_SETUP.md) · Builds: [docs/BUILD.md](docs/BUILD.md)

## Estructura

```
src/                      # UI React Native (expo-router): Home, Cinema Mode, Settings
modules/cinema-native/    # módulo Expo local: TODO el pipeline en Swift
  └── ios/                #   audio · speech · traducción · estabilizador · scheduler · métricas
docs/                     # arquitectura, decisiones, research verificado, QA, offline, privacidad
```

## Documentación

| Doc | Contenido |
|---|---|
| [ARCHITECTURE](docs/ARCHITECTURE.md) | Diagrama del pipeline, contrato JS↔Swift, concurrencia |
| [DECISIONS](docs/DECISIONS.md) | ADRs: versiones, APIs, target iOS 26.4, estrategia lowLatency |
| [research/APPLE_APIS](docs/research/APPLE_APIS.md) | APIs Apple verificadas contra docs oficiales (2026-09-19) |
| [research/EXPO_EAS](docs/research/EXPO_EAS.md) | Expo SDK 57 / EAS / pnpm verificados |
| [WINDOWS_SETUP](docs/WINDOWS_SETUP.md) | De cero a dev build instalada, desde Windows (vía Apple Developer) |
| [SIDELOAD_FREE](docs/SIDELOAD_FREE.md) | Instalación **gratuita** en iPhone (GitHub Actions + Sideloadly, renovación 7 días) |
| [BUILD](docs/BUILD.md) | Perfiles EAS, checklist, resolución de fallos |
| [OFFLINE_MODE](docs/OFFLINE_MODE.md) | Preparación de modelos y test en modo avión |
| [PRIVACY](docs/PRIVACY.md) | Privacidad by design y su verificación |
| [STATUS](docs/STATUS.md) | Estado por fases y Definition of Done |

## Estado

Fase: implementación base completa (UI + pipeline Swift + docs); pendiente primer build EAS
(requiere `eas login` y Apple Developer) y validación en iPhone. Detalle en [docs/STATUS.md](docs/STATUS.md).
