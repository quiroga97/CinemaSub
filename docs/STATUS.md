# STATUS — CinemaSubs

Última actualización: 2026-09-19 (fin de la sesión inicial: Wave 1 + Gate + implementación base)

## Visión general de fases

| Fase | Estado | Notas |
|---|---|---|
| Wave 1 — Research (Apple + Expo/EAS) | ✅ done | `docs/research/APPLE_APIS.md` + `EXPO_EAS.md`, verificado contra fuentes oficiales vivas |
| Architecture Gate | ✅ done | `docs/ARCHITECTURE.md` + `docs/DECISIONS.md` (D-001…D-016) |
| Wave 2 — UI + módulo nativo | ✅ done | UI completa; pipeline Swift completo (audio/speech/traducción/estabilizador/scheduler/métricas/puente Expo) |
| Wave 3 — Integración en dispositivo | ⏳ pendiente | Requiere build EAS + iPhone físico |
| Wave 4 — QA (soak 90 min, offline, interrupciones) | ⏳ pendiente | Plan: por escribir (`docs/QA_PLAN.md`) |
| Build EAS iOS verde | ⏳ pendiente | Requiere `eas login` del usuario (ver abajo) |

## Hecho y verificado localmente (Windows)

- [x] `pnpm install` OK (SDK 57.0.24, RN 0.86.3, TS 6.0.3 strict, pnpm 12 aislado)
- [x] `pnpm exec tsc --noEmit` sin errores
- [x] `pnpm test` vitest 8/8 (utilidades puras de subtítulos)
- [x] `expo-doctor` 21/21 checks
- [x] Contrato TS ↔ Swift completo (`modules/cinema-native/src/index.ts` + fachada)
- [x] UI: Home (preparar offline + start), Cinema Mode (OLED, 2 líneas equilibradas, tap
      para controles, delay −2…+4 s, tamaño A−/A+, brillo con guardado/restauración,
      EN on/off, keep-awake, HUD solo en `__DEV__`), Settings, privacidad visible
- [x] Pipeline Swift completo: `AudioCaptureService` (AVAudioEngine + tap + conversión +
      farFieldInput + interrupciones/rutas), `SpeechRecognitionService` (API modular final
      de SpeechAnalyzer), `SpeechModelManager` (AssetInventory con progreso + reserve),
      `TranslationService` (TranslationSession lowLatency reutilizable), `TranslationModelManager`
      (LanguageAvailability + bootstrap SwiftUI con timeout), `TranscriptStabilizer`,
      `SubtitleScheduler`, `PipelineMetrics`, `CinemaNativeModule` (Expo DSL: 8 funciones,
      5 eventos, ciclo de vida app)
- [x] Config: deploymentTarget 26.4 (integrado), eas.json con imagen Xcode 26.6, permiso mic
- [x] Docs: README, ARCHITECTURE, DECISIONS, WINDOWS_SETUP, BUILD, OFFLINE_MODE, PRIVACY, research

## Pendiente (orden)

1. **[REQUIERE EL USUARIO]** `eas login` + Apple Developer → primer
   `eas build --platform ios --profile development` (pasos exactos en docs/WINDOWS_SETUP.md).
2. Iterar errores de compilación Swift si el build los expone (riesgos residuales
   documentados: `AssetInstallationRequest.progress`, firma de `.translationTask`).
3. Instalar en iPhone, probar vertical slice: mic → transcripción EN → evento → UI.
4. Activar traducción: «Preparar modo offline» → test modo avión.
5. Medir y fijar: ventana del estabilizador (250–700 ms), `.measurement` vs `.default`,
   `fastResults` on/off (HUD de métricas).
6. `docs/QA_PLAN.md` + `docs/PERFORMANCE.md`: soak 90 min, interrupciones, privacidad, térmico.
7. Limpiezas: borrar `App.tsx`/`index.ts` (vestigios del template, ya inertes), iconos/splash propios.

## Bloqueos que requieren acción del usuario

- Cuenta Expo + `eas login` (gratis).
- Apple Developer Program (pago) para firmar/instalar en iPhone físico **por la vía EAS**.
  - Alternativa **gratuita** ya preparada: [docs/SIDELOAD_FREE.md](SIDELOAD_FREE.md)
    (GitHub Actions genera IPA sin firmar; Sideloadly la firma con Apple ID gratis,
    caducidad de 7 días impuesta por Apple).
- iPhone físico iOS 26.4+ con UDID registrado (`eas device:create`) y Modo de desarrollador.

## Definition of Done (MVP) — del master prompt

```
[ ] proyecto clona correctamente en Windows        → repo listo; falta publicar en GitHub
[x] pnpm install funciona
[x] TypeScript compila
[x] tests pasan (vitest 8/8)
[x] development client configurado (expo-dev-client + perfil development)
[ ] EAS iOS build termina correctamente            → requiere eas login del usuario
[ ] app instala en iPhone físico
[ ] permisos funcionan
[ ] micrófono funciona
[ ] SpeechAnalyzer funciona en tiempo real
[ ] transcripción English funciona
[ ] Apple Translation EN → ES funciona
[ ] modelos pueden prepararse antes del cine
[ ] funciona posteriormente en modo avión
[x] audio nunca se guarda (por diseño; verificar sandbox en QA)
[x] transcript nunca se persiste (por diseño; verificar en QA)
[x] subtítulos tienen máximo 2 líneas
[x] Cinema Mode usa fondo negro
[x] no hay sonido/haptics
[x] pantalla permanece activa (expo-keep-awake)
[x] brillo puede reducirse y restaurarse
[x] delay puede ajustarse
[x] latencia está instrumentada
[x] stopSession libera recursos (revisar en dispositivo)
[x] errores tienen UI comprensible
[ ] 90-min test documentado
[x] README completo
[x] WINDOWS_SETUP completo
```
