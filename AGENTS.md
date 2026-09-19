# CinemaSubs — Reglas del proyecto (para agentes y colaboradores)

Producto: app iOS que transcribe audio ambiental de una película en inglés y muestra
subtítulos en español casi en tiempo real. Una sola experiencia importa: pulsar START
y leer español durante toda la película, sin molestar a nadie.

## Prioridades (en orden estricto)

1. LATENCIA
2. ESTABILIDAD (sin parpadeo de texto)
3. LEGIBILIDAD (modo cine OLED, máx 2 líneas)
4. PRIVACIDAD
5. FUNCIONAMIENTO OFFLINE

## Reglas de arquitectura

- Todo el pipeline crítico vive en Swift (`modules/cinema-native/ios/`). JS solo recibe eventos ligeros.
- PROHIBIDO: procesar PCM en JavaScript, enviar buffers por el bridge, STT en TypeScript, APIs cloud (OpenAI/Google/Azure), SFSpeechRecognizer o Whisper en el MVP.
- Contrato JS ↔ Swift: `modules/cinema-native/src/index.ts`. Cualquier cambio requiere actualizar `docs/ARCHITECTURE.md`.

## Reglas de privacidad (obligatorias)

- NO guardar audio, transcripciones ni traducciones en disco. Nunca.
- NO enviar audio ni texto a servidores. NO analytics en Cinema Mode.
- Los logs NUNCA contienen texto transcrito/traducido: solo eventos y números (`latency=842ms`).
- Usar `Log.event(.translationFinished, ["ms": "102"])`, nunca `print(text)`.

## Reglas de proceso

- Desarrollo desde Windows SIN Mac: los builds iOS son SOLO vía EAS Build. Nunca `expo run:ios`.
- Cambios TS/UI iteran por Metro (sin rebuild nativo). Cambios Swift requieren build EAS: agrúpalos.
- Antes de cada build EAS: `pnpm typecheck` + `pnpm test` + revisión del código nativo.
- PROHIBIDO declarar terminada una fase con TODOs, mocks sin marcar o datos falsos.
  Los mocks de desarrollo deben estar claramente identificados y separados del pipeline real.
- Mantener actualizados `docs/STATUS.md` y `docs/DECISIONS.md` tras cada fase.

## Docs oficiales antes de escribir código

- Expo SDK 57: https://docs.expo.dev/versions/v57.0.0/
- Apple (verificar APIs reales, no de memoria): https://developer.apple.com/documentation/
