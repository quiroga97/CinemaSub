# BUILD — Builds EAS de CinemaSubs

## Perfiles (`eas.json`)

| Perfil | Uso | Distribución | Notas |
|---|---|---|---|
| `development` | iteración diaria | internal (ad hoc) | `developmentClient: true`, Debug, Metro |
| `preview` | probar release-like | internal (ad hoc) | sin herramientas de dev |
| `production` | TestFlight/App Store | store | `autoIncrement` |

Todos fijan la imagen `macos-tahoe-26.5-xcode-26.6` (Xcode 26.6, alias `sdk-57`/`latest`)
para reproducibilidad. El deployment target iOS 26.4 vive en `app.json`
(`expo.ios.deploymentTarget` — propiedad integrada del SDK 56+).

## Comandos

```powershell
# build de desarrollo (la que usarás el 90% del tiempo)
eas build --platform ios --profile development

# release interna para probar sin Metro
eas build --platform ios --profile preview

# subir a TestFlight (requiere perfil production + App Store Connect)
eas build --platform ios --profile production
eas submit --platform ios --profile production
```

## Checklist antes de CADA build

```powershell
pnpm typecheck    # TypeScript sin errores
pnpm test         # vitest verde
pnpm dlx expo-doctor@latest
```

Además: revisar el diff de `modules/cinema-native/ios/` (no hay compilador Swift local
en Windows; el primer error de compilación se verá en EAS — agrupa y revisa cambios).

## Qué exige un rebuild

- Cualquier archivo de `modules/cinema-native/ios/**`.
- `app.json` (permisos, plugins, deployment target).
- Cambios en dependencias nativas (package.json).

## Qué NO lo exige (Fast Refresh)

- `src/**` completo: pantallas, componentes, estado, tema, utils.

## Credenciales

- Gestionadas por EAS (recomendado): certificado de distribución + perfil ad hoc con los
  UDID registrados. Inspección: `eas credentials`.
- Máx. 100 iPhones/año (ad hoc); perfiles caducan a los 12 meses (nueva build los regenera).
- Nuevo dispositivo: `eas device:create` y re-build.

## Si el build falla

1. Leer el log completo en el enlace de EAS (o `eas build:list` → log).
2. Identificar el error raíz (Swift compile, pod install, prebuild, credenciales).
3. Corregir, re-ejecutar `pnpm typecheck && pnpm test`, lanzar nuevo build.
4. Repetir hasta verde. No asumir "debería compilar".

## Cadena de confianza del código nativo

La API de Apple usada fue verificada contra documentación oficial viva (2026-09-19):
`docs/research/APPLE_APIS.md`. Riesgos residuales documentados allí (§d) — especialmente
`AssetInstallationRequest.progress` y la firma exacta de `.translationTask(source:target:)`,
que el primer build confirmará.
