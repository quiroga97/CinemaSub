# WINDOWS_SETUP — Desarrollo de CinemaSubs desde Windows 11 (sin Mac)

Guía completa desde cero. Todo build iOS se produce en la nube (EAS Build); en Windows
solo se ejecutan Metro, tests y herramientas TS.

## 1. Prerrequisitos (una vez)

```powershell
# Node.js LTS 24.x (mínimo 22.13) — https://nodejs.org
node -v

# Git — https://git-scm.com/download/win
git --version

# pnpm (si no lo tienes ya)
npm install --global pnpm
pnpm -v

# EAS CLI (builds en la nube)
npm install --global eas-cli
```

Cuentas necesarias:

- **Expo** (gratis): https://expo.dev/signup
- **Apple Developer Program** (de pago, ~99 USD/año): necesaria para instalar en iPhone físico.
- Un **iPhone físico con iOS 26.4+** (objetivo de prueba: iOS 27).

## 2. Clonar e instalar el proyecto

```powershell
cd D:\Codex
git clone <tu-repo> CinemaSub   # o descomprime tu copia
cd CinemaSub
pnpm install
pnpm dlx expo-doctor@latest     # debe pasar 21/21
```

## 3. Login y registro del dispositivo

```powershell
eas login          # tu cuenta de Expo; verificar con: eas whoami
```

Registrar el UDID del iPhone (solo la primera vez):

```powershell
eas device:create   # imprime URL + QR: ábrelo EN EL IPHONE, instala el perfil -> captura el UDID
eas device:list     # verificar que aparece
```

> Con cuentas de Apple Developer recién creadas, Apple puede tardar 24–72 h en procesar
> el dispositivo; la primera build puede fallar hasta entonces.

## 4. Primer build de desarrollo (iOS)

```powershell
eas build --platform ios --profile development
```

Durante la primera build EAS pedirá:

1. Iniciar sesión con tu **Apple ID**.
2. Dejar que **EAS genere y gestione las credenciales** (certificado de distribución +
   provisioning profile ad hoc con tu UDID). Recomendado: sí a todo.

Duración típica: 10–25 minutos. La config ya está fijada en `eas.json`
(imagen `macos-tahoe-26.5-xcode-26.6` = Xcode 26.6, deployment target iOS 26.4).

## 5. Instalar en el iPhone

- Al terminar la build, la CLI muestra un enlace/QR: ábrelo **en el iPhone** (Safari) e instala.
- Si iOS lo pide: **Ajustes → Privacidad y seguridad → Modo de desarrollador → activar** (y reiniciar).
- Confía en el perfil de desarrollador si es necesario: Ajustes → General → VPN y gestión de dispositivos.

## 6. Metro desde Windows

```powershell
pnpm start          # = expo start --dev-client
```

- El iPhone debe estar en la **misma Wi-Fi** que el PC (el USB por sí solo NO transporta
  la conexión a Metro en iOS desde Windows).
- Abre CinemaSubs en el iPhone y conéctalo al dev server (`exp://<IP-de-tu-PC>:8081`)
  o escanea el QR de la terminal.
- Red problemática (universidad, hotel): `pnpm exec expo start --dev-client --tunnel`.

## 7. Ciclo de desarrollo (importante)

| Tipo de cambio | ¿Rebuild nativo? |
|---|---|
| TypeScript, UI, estilos, estado | **NO** — Fast Refresh al guardar |
| Swift (`modules/cinema-native/ios/`) | **SÍ** — nuevo `eas build` |
| app.json (Info.plist, plugins), dependencias nativas | **SÍ** |

Antes de cada build:

```powershell
pnpm typecheck
pnpm test
```

Agrupa los cambios nativos: cada build EAS cuesta tiempo (y cuota).

## 8. Verificaciones locales rápidas

```powershell
pnpm typecheck     # tsc --noEmit
pnpm test          # vitest (lógica pura)
pnpm dlx expo-doctor@latest
```

## 9. Problemas comunes

- **Metro no resuelve módulos con pnpm**: añade `nodeLinker: hoisted` a `pnpm-workspace.yaml`
  (fallback documentado de Expo; el proyecto usa modo aislado que es lo soportado).
- **iPhone no ve el dev server**: misma Wi-Fi, que el cortafuegos de Windows permita el puerto 8081, o usa `--tunnel`.
- **Build falla por credenciales**: `eas credentials` para inspeccionar/regenerar.
- **Nuevo iPhone**: `eas device:create` + re-build (o `eas build:resign`).
- **Perfil ad-hoc caducado** (12 meses): nueva build lo regenera.
