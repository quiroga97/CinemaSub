# Investigación Expo / EAS — CinemaSubs (iOS desde Windows 11, sin Mac)

Fecha de verificación: **2026-09-19**. Todo lo abajo fue contrastado contra fuentes oficiales vigentes (docs.expo.dev, expo.dev/changelog, repo github.com/expo/expo). Comandos en **PowerShell**.

## Tabla de versiones (verificadas)

| Componente | Versión | Fuente |
|---|---|---|
| Expo SDK | **57** estable (liberado **2026-06-30**); proyecto local en `expo ~57.0.24` | expo.dev/changelog/sdk-57, docs.expo.dev/versions/latest |
| react-native | **0.86.3** (desde `expo@57.0.17`; 57.0.9→0.86.2) | changelog SDK 57 |
| react | **19.2.3** (sin cambios frente a SDK 56) | docs.expo.dev/versions/latest |
| TypeScript | **~6.0.3** (confirmado en el package.json local; las plantillas oficiales de módulos usan `^5.9.x`) | package.json local; plantilla expo-module-template |
| iOS deployment target | Mínimo del SDK 57: **16.4**. CinemaSubs: **26.0** (ver mecanismo en §2) | docs.expo.dev/versions/latest; sdk/build-properties |
| Xcode / imagen EAS | Requiere **Xcode 26.4+**; imagen EAS a fijar: **`macos-tahoe-26.5-xcode-26.6`** (macOS Tahoe 26.5.2 + Xcode 26.6, alias `latest`/`sdk-57`) | docs.expo.dev/build-reference/infrastructure |
| Node.js | Mínimo **22.13.x**; recomendado **LTS 24.x** (LTS activa a sep-2026; Node 26 entra en LTS en oct-2026) | docs.expo.dev/versions/latest; nodejs.org |
| pnpm | Actual (v10.x). Proyecto local en modo **aislado** (sin `nodeLinker`) — soportado desde SDK 54 | docs.expo.dev/more/create-expo |

---

## 1. Expo SDK 57: estado, versiones fijadas y New Architecture

- **Fecha de salida**: 30 de junio de 2026 (anuncio de Brent Vatne y Alan Hughes). Es un lanzamiento **estable** (no beta); el SDK 58 aún está en preview y saldrá después. Vida útil de un SDK ≈ 1 año.
- Es un lanzamiento "pequeño y enfocado": lleva **React Native 0.86** a Expo. RN 0.86 **no tiene breaking changes** respecto a 0.85 ("el upgrade de SDK más fácil que hayas hecho").
- **Versiones fijadas**: RN 0.86.x (0.86.3 en el proyecto local), React 19.2.x, React Native Web 0.21.0, Android compileSdk/targetSdk 36, **iOS mínimo 16.4**, **Xcode 26.4+**, **Node mínimo 22.13.x**.
- **New Architecture**: en SDK 57 la app corre **íntegramente en New Architecture** — la documentación dice "SDK 55 and later run entirely on the New Architecture" y "SDK 55 and later do not support disabling the New Architecture" (`newArchEnabled: false` no tiene efecto). Fue default en proyectos nuevos desde SDK 52. Conclusión: no hay que activar ni declarar nada.
- Regresiones conocidas ya corregidas: memoria Hermes V1 con reanimated/worklets (corregido en `expo@57.0.9`) y arranque lento en dev (corregido en `expo@57.0.17`).
- Futuro: el **iOS 27 SDK (Xcode 27)** exige ciclo de vida UIKit por escenas. SDK 58 lo trae por defecto; en SDK 57 es opt-in con `ios.enableSceneSupport` en `expo-build-properties` (requiere `expo >= 57.0.23`). CinemaSubs no lo necesita mientras compile con Xcode 26.x.
- Upgrade/mantenimiento: `npx expo install expo@^57.0.0 --fix`, `npx expo-doctor@latest`; con CNG, `npx expo prebuild --clean` **borra y regenera** `android/` e `ios/` por defecto.

## 2. iOS 26 con SDK 57: Xcode en EAS y deployment target

### Xcode / imagen macOS de EAS

- Build server infrastructure vigente (docs.expo.dev/build-reference/infrastructure):
  - `macos-tahoe-26.5-xcode-26.6` — macOS Tahoe 26.5.2, **Xcode 26.6 (17F113)**. Alias: **`latest`** y **`sdk-57`**. Es la imagen que incluye el SDK de iOS 26 más reciente.
  - `macos-tahoe-26.4-xcode-26.4` — alias `sdk-56`.
  - Anteriores: `macos-sequoia-15.6-xcode-26.2` (sdk-55), `-26.0` (sdk-54), Xcode 16.x…
- Si no se fija `image`, EAS usa el alias `auto` (elige según tu SDK; en el log "Spin up build environment" se ve cuál usó). **Recomendado para reproducibilidad**: fijar el nombre completo en cada perfil:

```json
"ios": { "image": "macos-tahoe-26.5-xcode-26.6" }
```

### Deployment target iOS 26.0 — mecanismo correcto en SDK 57

- **Mecanismo correcto (SDK 56+): la propiedad integrada `expo.ios.deploymentTarget` en app.json.**
- La propiedad `ios.deploymentTarget` del plugin **expo-build-properties está marcada DEPRECATED**: la propia doc dice *"Deprecated: use built-in ios.deploymentTarget property instead (SDK 56 and greater)"*.
- El deployment target es el **mínimo de iOS** para instalar la app (no confundir con el SDK de iOS con el que compila Xcode). Default SDK 57: 16.4. Para exigir iOS 26+:

```json
{
  "expo": {
    "ios": {
      "deploymentTarget": "26.0"
    }
  }
}
```

- El prebuild actual aplica esto al proyecto Xcode generado (IPHONEOS_DEPLOYMENT_TARGET). El `.podspec` de un módulo local puede seguir declarando `:ios => '16.4'` (el mínimo del pod); no impide que la app fije 26.0.
- Nota importante: subir el mínimo a 26.0 hace que la app **solo se instale en iPhones con iOS 26+**. Verifica que tu iPhone físico cumpla.

## 3. Expo Modules API — sintaxis Swift vigente (SDK 57)

### `npx create-expo-module --local` hoy

Desde la raíz del proyecto (donde está package.json):

```powershell
pnpm dlx create-expo-module@latest --local
```

- Crea `modules/<slug>/`. La plantilla se descarga de npm (`expo-module-template`) usando el **dist-tag `sdk-57`** derivado de tu `expo` local, así que lo generado coincide con tu SDK.
- Flags útiles: `--name` (nombre nativo), `--package` (paquete Android), `-p <plataformas>`, `--features <...>` / `--full-example`, y `--barrel` (genera `index.ts` raíz de re-export; solo módulos locales).
- **Un módulo local HOY no lleva package.json** (la CLI lo excluye: "these are skipped so the host project's tooling is used instead") ni `src/index.ts`; genera (si elige iOS): `ios/<Nombre>.podspec`, `ios/<Nombre>Module.swift`, `src/<Nombre>Module.ts`, `src/<Nombre>.types.ts`, `src/<Nombre>Module.web.ts`, `expo-module.config.json` y, con `--barrel`, `index.ts` raíz. Sin barrel, importa desde `./modules/<slug>/src/<Nombre>Module`.
- Tras crearlo o tocar código nativo: `npx expo prebuild --clean` (CNG) y nueva build — Fast Refresh no recarga Swift.

### `expo-module.config.json` (schema vigente)

```json
{
  "platforms": ["apple"],
  "apple": {
    "modules": ["CinemaNativeModule"]
  }
}
```

- `platforms`: `android`, `apple` (o granular `ios`/`macos`/`tvos` — ambas formas valen; el proyecto local usa `"ios"`, válido), `web`, `devtools`.
- `apple.modules`: nombres de las clases Swift a registrar en el provider generado.
- `apple.appDelegateSubscribers`: clases que enganchan el ciclo de vida de `ExpoAppDelegate`.
- `android.modules`: nombres completos (paquete + clase) Kotlin.
- Sin `expo-module.config.json` con la plataforma en `platforms`, el módulo se ignora en el autolinking.

### `.podspec` de un módulo local (contenido exacto de la plantilla actual)

```ruby
Pod::Spec.new do |s|
  s.name           = 'CinemaNative'
  s.version        = '1.0.0'
  s.summary        = 'A sample project summary'
  s.description    = 'A sample project description'
  s.author         = ''
  s.homepage       = 'https://docs.expo.dev/modules/'
  s.platforms      = {
    :ios => '16.4',
    :tvos => '16.4'
  }
  s.source         = { git: '' }
  s.static_framework = true

  s.dependency 'ExpoModulesCore'

  # Swift/Objective-C compatibility
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
  }

  s.source_files = "**/*.{h,m,mm,swift,hpp,cpp}"
end
```

(La variante "remote" añade `require 'json'` + lectura de package.json, `s.swift_version = '5.9'` y datos del repo; no aplica a módulos locales.)

### Definición Swift — DSL actual

Esqueleto exacto de la plantilla:

```swift
import ExpoModulesCore

public class CinemaNativeModule: Module {
  public func definition() -> ModuleDefinition {
    Name("CinemaNative")
    // ... componentes DSL
  }
}
```

Componentes verificados en la referencia actual (docs.expo.dev/modules/module-api):

- `Function("hello") { (name: String) in "Hello \(name)!" }` — síncrono, hasta 8 argumentos.
- `AsyncFunction("x") { (value: String) in value }` — devuelve Promise, corre fuera del hilo JS. Forma explícita con `Promise`:

```swift
AsyncFunction("myAsyncFunction") { (message: String, promise: Promise) in
  promise.resolve(message)
}
```

- Encadenable `.runOnQueue(.main)` para correr en el hilo principal.
- Eventos: declarar `Events("onChange")` en la definición; emitir con `self.sendEvent("onChange", ["value": value])` (payload `[String: Any?]`); hooks por evento `OnStartObserving("onURLReceived") { ... }` / `OnStopObserving("onURLReceived") { ... }` (ejemplo oficial: observer de `NotificationCenter` que llama `sendEvent`).
- `Constant("PI") { Double.pi }` (evaluación perezosa y cacheada; `Constants([...])` está deprecado), `Property("foo")` con `.get`/`.set`.
- **Records** (maps tipados) en lugar de diccionarios sueltos:

```swift
struct FileReadOptions: Record {
  @Field var encoding: String = "utf8"
  @Field var position: Int = 0
  @Field var length: Int?
}
```

  Los enums dentro de Records deben conformar `Enumerable` (p. ej. `enum FileEncoding: String, Enumerable { case utf8, base64 }`). Un enum `Enumerable` también se puede usar directamente como argumento de función.
- Convertibles incluidos: `URL`, `CGPoint`, `CGSize`, `CGRect`, `UIColor`, `Data` (desde `Uint8Array`); protocolo `Convertible` con `convert(from:appContext:)` para tipos propios; `Either`/`EitherOfThree`/`EitherOfFour` para uniones; `JavaScriptValue`/`JavaScriptObject`/`JavaScriptFunction` para JS crudo (solo en funciones sync).
- `AppContext`: disponible como `self.appContext` / `appContext` del módulo (`constants`, `permissions` — interfaz legacy `EXPermissionsInterface`, `reactContext`, `utilities`…). Es el único canal para hablar con otros módulos y el runtime JS.
- **Permissions**: la referencia actual de la Modules API **ya no documenta un DSL `Permissions`** (solo menciona `appContext.permissions` como gestor legacy). Para CinemaSubs es irrelevante: ni keep-awake ni brightness necesitan permisos en iOS (ver §8). Si algún día hiciera falta un permiso (p. ej. micrófono, ya declarado en Info.plist), el flujo moderno es pedirlo en JS con el módulo correspondiente o exponer un `AsyncFunction` propio.
- Ciclo de vida iOS: `OnCreate`, `OnDestroy`, `OnAppEntersForeground`, `OnAppEntersBackground`, `OnAppBecomesActive`, `OnAppContextDestroys`.

### Ejemplo mínimo completo y real (async + eventos), según plantilla y docs actuales

```swift
// modules/cinema-native/ios/CinemaNativeModule.swift
import ExpoModulesCore

public class CinemaNativeModule: Module {
  public func definition() -> ModuleDefinition {
    Name("CinemaNative")

    // 1) Eventos: declarar nombres
    Events("onSubtitleTick")

    // 2) Síncrono
    Function("hello") { () -> String in
      return "Hello world! 🌎🍎"
    }

    // 3) Asíncrono (devuelve Promise) que emite un evento
    //    (idéntico al snippet oficial de AsyncFunction + Event)
    AsyncFunction("setValueAsync") { (value: String) in
      self.sendEvent("onSubtitleTick", [
        "value": value
      ])
    }

    // 4) Asíncrono con Promise explícito (p. ej. trabajo pesado)
    AsyncFunction("prepareAsync") { (options: PrepareOptions, promise: Promise) in
      // options es un Record tipado (ver abajo)
      promise.resolve(options.encoding)
    }
    .runOnQueue(.main)

    // 5) Arrancar/detener emisión cuando JS subscribe/cancela
    OnStartObserving("onSubtitleTick") {
      // p. ej. NotificationCenter.default.addObserver(...)
    }
    OnStopObserving("onSubtitleTick") {
      // p. ej. NotificationCenter.default.removeObserver(...)
    }
  }
}

// Record tipado (reemplaza diccionarios no tipados)
struct PrepareOptions: Record {
  @Field var encoding: String = "utf8"
  @Field var position: Int = 0
  @Field var length: Int?
}
```

## 4. Lado JS actual de Expo Modules

Patrón exacto del tutorial oficial vigente (docs.expo.dev/modules/native-module-tutorial):

```ts
// src/native/CinemaNativeModule.ts
import { NativeModule, requireNativeModule } from 'expo';
import { EventSubscription } from 'expo-modules-core';
import type { SubtitleTickEvent, CinemaNativeEvents } from './CinemaNative.types';

// La clase declarada tipa el módulo nativo cargado desde JSI
declare class CinemaNativeNativeModule extends NativeModule<CinemaNativeEvents> {
  hello(): string;
  setValueAsync(value: string): Promise<void>;
  prepareAsync(options: PrepareOptions): Promise<string>;
}

export default requireNativeModule<CinemaNativeNativeModule>('CinemaNative');
```

- El string de `requireNativeModule` debe coincidir con `Name("CinemaNative")` en Swift.
- Tipado de eventos (archivo `.types.ts`):

```ts
export type SubtitleTickEvent = { value: string };
export type CinemaNativeEvents = {
  onSubtitleTick: (params: SubtitleTickEvent) => void;
};
```

- Suscripción: el parámetro genérico de `NativeModule<CinemaNativeEvents>` habilita `addListener` en la instancia, que devuelve un `EventSubscription`:

```ts
import CinemaNativeModule from './CinemaNativeModule';
import type { SubtitleTickEvent } from './CinemaNative.types';

export function addSubtitleTickListener(
  listener: (event: SubtitleTickEvent) => void
): EventSubscription {
  return CinemaNativeModule.addListener('onSubtitleTick', listener);
}

// En React: limpiar con subscription.remove() en el cleanup del efecto.
```

## 5. Módulo local dentro de la app: autolinking

- Autolinking busca módulos locales en `expo.autolinking.nativeModulesDir`, **por defecto `./modules/`** — en un proyecto simple **no hay que tocar package.json**. (Configuración opcional en package.json: `"expo": { "autolinking": { "nativeModulesDir": "./modules" } }`; `searchPaths` es para otras rutas/monorepos.)
- Orden de búsqueda actual: (1) módulos RN con `root` en react-native.config.js, (2) `searchPaths`, (3) módulos locales en `nativeModulesDir`, (4) dependencias del app resueltas como Node. Para que un directorio cuente como módulo debe tener `expo-module.config.json` en su raíz (junto a package.json si existe).
- El módulo local de CinemaSubs (`modules/cinema-native`) **ya tiene** un `package.json` (`"main": "src/index.ts"`): es opcional con la CLI actual (el scaffold `--local` ya no lo genera), pero es válido — autolinking solo exige `expo-module.config.json`; el package.json ayuda a Metro/TS a resolver el entry. Su `"platforms": ["ios"` con `"ios": { "modules": [...] }` es la forma granular válida del schema (la plantilla nueva usa `"apple"`).
- En EAS Build no hay que hacer nada: `modules/` viaja en el repo y el autolinking se ejecuta en la nube durante prebuild/pod install.

## 6. pnpm con Expo hoy (SDK 57)

- Guía oficial vigente (docs.expo.dev/more/create-expo): un proyecto creado con `create-expo-app` + pnpm usa por defecto **`nodeLinker: hoisted` en `pnpm-workspace.yaml`** (ya no en `.npmrc`; `node-linker=hoisted` en `.npmrc` sigue siendo equivalente para pnpm).
- **"In SDK 54 and later, Expo supports isolated installations, and you can delete the `nodeLinker` setting"** — desde SDK 54+, pnpm en modo aislado (symlinks) está soportado. **CinemaSubs ya está en modo aislado** (su `pnpm-workspace.yaml` no define `nodeLinker`): es la configuración moderna y funciona sin `.npmrc`.
- EAS Build: pnpm **soportado por defecto si existe `pnpm-lock.yaml`** en el directorio del proyecto. No hace falta `EXPO_USE_PNPM` ni settings extra en eas.json.
- Issues conocidos con pnpm:
  - Con **jest**, `transformIgnorePatterns` necesita `.pnpm` en el lookahead negativo (no aplica con `nodeLinker: hoisted`; y CinemaSubs usa vitest, ver §9).
  - Con monorepos/aislado, algunas librerías RN que asumen `node_modules` plano pueden fallar — si aparece algo raro en Metro, el fallback oficial es añadir `nodeLinker: hoisted` a `pnpm-workspace.yaml`.

## 7. EAS Build desde Windows 11 sin Mac (flujo exacto)

Windows no compila iOS localmente; **todas** las builds iOS van por EAS Build (macOS en la nube). Setup verificado:

1. **EAS CLI y login** (docs.expo.dev/build/setup):

```powershell
npm install --global eas-cli
eas login          # cuenta de Expo (crear en expo.dev/signup si no hay)
eas whoami         # verificar
```

2. **Configurar el proyecto** — desde la raíz del repo:

```powershell
eas build:configure
```

Genera `eas.json` (si no existe) con tres perfiles: `development { "developmentClient": true, "distribution": "internal" }`, `preview { "distribution": "internal" }`, `production {}`. En la primera acción `eas`/build, la CLI además registra el proyecto y escribe `extra.eas.projectId` en app.json.

3. **eas.json vigente** — opciones relevantes verificadas (docs.expo.dev/build/eas-json):
   - `developmentClient: true`: la build incluye `expo-dev-client` (herramientas de dev; jamás se sube a stores).
   - `distribution: "internal"`: iOS usa **ad hoc** (o enterprise). EAS genera el provisioning profile ad hoc con la lista blanca de UDIDs.
   - `ios.image`: nombre de imagen macOS (ver §2) o alias `latest`/`auto`/`sdk-57`.
   - `extends` entre perfiles, `env` por perfil, `ios.simulator: true` para simulador (solo simulador), `cli.version` mínimo, `resourceClass`.

4. **Credenciales iOS (desarrollo/ad-hoc, gestionadas por EAS)** — docs.expo.dev/app-signing/app-credentials y docs.expo.dev/build/internal-distribution:
   - Requiere **Apple Developer Program de pago** (~99 USD/año) para builds de dispositivo (ad hoc) y store.
   - En la **primera build iOS**, EAS pide iniciar sesión con el Apple ID y ofrece dejar que **EAS genere y gestione** las credenciales: certificado de distribución (uno por cuenta), provisioning profile **ad hoc** (incluye los UDIDs registrados) y, si aplica, APNs key (máx. 2 por cuenta). Todo queda guardado en los servidores de EAS; se inspecciona con `eas credentials`.
   - Los provisioning profiles **caducan a los 12 meses** (regenerar con nueva build o `eas credentials`); los certificados no afectan a apps ya publicadas.
   - Ad hoc: máximo **100 iPhones por año** por cuenta. Añadir un dispositivo nuevo exige re-build o `eas build:resign`.

5. **Registrar el iPhone físico (UDID)**:

```powershell
eas device:create    # imprime URL + QR; abrir en el iPhone e instalar el perfil de descripción -> captura el UDID
eas device:list      # verificar
eas device:rename    # opcional: poner nombre legible
```

   El dispositivo se registra en el Apple Developer Portal **la primera vez que se incluye en un provisioning profile** (o sea, en la siguiente build). Con cuentas de Apple Developer recién creadas, Apple puede tardar 24–72 h en procesar el dispositivo (la primera build puede fallar).

6. **Primera build de desarrollo**:

```powershell
eas build --platform ios --profile development
```

   Durante el proceso: login Apple ID → dejar que EAS gestione credenciales → genera certificado + perfil ad hoc con tu UDID.

7. **Instalar en el iPhone**: al terminar la build, la CLI muestra enlace; pulsar `Y` (o abrir el enlace / escanear el QR) **en el iPhone** → se instala vía el enlace de distribución interna (URL con UUID de 32 caracteres). Si iOS lo pide, activar **Modo de desarrollador** (Ajustes → Privacidad y seguridad → Modo de desarrollador).

8. **Metro desde Windows**:

```powershell
pnpm exec expo start --dev-client
```

   (Con `expo-dev-client` instalado, `pnpm exec expo start` a secas ya apunta al dev build; `--dev-client` lo fuerza. El package.json local ya tiene `"start": "expo start --dev-client"`.)
   - **iPhone ↔ Metro es por red** (`exp://<IP-de-tu-PC>:8081`): el iPhone y el PC deben estar en la **misma Wi-Fi** (o el iPhone conectado al hotspot del PC). **El USB por sí solo no transporta la conexión en iOS desde Windows** (no existe `adb reverse` para iPhone; el reenvío USB tipo `iproxy` es cosa de macOS/Xcode). Si la red bloquea la conexión, usar `pnpm exec expo start --dev-client --tunnel`.
   - En el launcher del dev client se puede entrar la URL del dev server a mano o escanear el QR de la terminal.
   - Cambios JS/TS → Fast Refresh; cambios nativos (Swift, app.json, plugins) → nueva build (`eas build -p ios --profile development`).

## 8. expo-dev-client, expo-keep-awake, expo-brightness (SDK 57)

- **expo-dev-client** (`~57.0.19` ya instalado): se añade con `npx expo install expo-dev-client` (elige la versión del SDK automáticamente). Requisitos: perfil de build con `developmentClient: true` (build en modo Debug con herramientas de desarrollo y launcher). Los dev builds nunca se envían a stores.
- **expo-keep-awake** (`~57.0.2`) — API vigente (docs.expo.dev/versions/latest/sdk/keep-awake). Nombres actuales (ojo: NO son `activate`/`deactivate` a secas):

```ts
import * as KeepAwake from 'expo-keep-awake';
// import { useKeepAwake } from 'expo-keep-awake';

await KeepAwake.activateKeepAwakeAsync('CinemaSubsPlayback'); // activar (tag opcional)
await KeepAwake.deactivateKeepAwake('CinemaSubsPlayback');    // desactivar (tag opcional)
const ok: boolean = await KeepAwake.isAvailableAsync();
// Hook: mantiene la pantalla encendida mientras el componente está montado
useKeepAwake('CinemaSubsPlayback');
```

  `activateKeepAwake(tag)` síncrono está **deprecado** → usar `activateKeepAwakeAsync`. Sin permisos en iOS; tag default `'ExpoKeepAwakeDefaultTag'`; `addListener` solo web.
- **expo-brightness** (`~57.0.2`) — API vigente (docs.expo.dev/versions/latest/sdk/brightness):

```ts
import * as Brightness from 'expo-brightness';

const level = await Brightness.getBrightnessAsync();      // 0..1
await Brightness.setBrightnessAsync(0.05);               // 0..1
const available = await Brightness.isAvailableAsync();   // true en iOS
Brightness.addBrightnessListener((event) => { /* solo iOS */ });
```

  - **iOS no requiere permisos** (los `getPermissionsAsync`/`requestPermissionsAsync`/`usePermissions` existen pero son para Android, que necesita `WRITE_SETTINGS`).
  - **Restore en iOS**: `setBrightnessAsync` **persiste hasta que el dispositivo se bloquea**, momento en que iOS revierte al valor del usuario. **No existe `restoreBrightnessAsync`** en el SDK actual; `restoreSystemBrightnessAsync()` es **solo Android** (igual que get/setSystemBrightness*). Para CinemaSubs: guardar el valor leído antes de fijarlo y restaurarlo con `setBrightnessAsync(valorGuardado)` al salir de reproducción.

## 9. Tests unitarios TS puros: recomendación

- **Oficial**: Expo documenta y recomienda **jest-expo** (docs.expo.dev/develop/unit-testing): `npx expo install jest-expo jest @types/jest -- --save-dev` (en PowerShell hace falta el `--` antes de la opción), preset `"jest": { "preset": "jest-expo" }` en package.json, `@testing-library/react-native` para componentes (con render asíncrono). `react-test-renderer` está deprecado (sin soporte React 19). **Vitest no tiene guía oficial de Expo**; jest-expo es el estándar para tests de componentes/snapshot RN.
- **Para CinemaSubs (lógica TS pura, sin componentes RN)**: el proyecto ya tiene **vitest** (`^3.2.4`) con `vitest.config.ts` (`environment: 'node'`, `include: ['src/**/*.test.ts']`) y script `"test": "vitest run"`. **Recomendación: mantener vitest para la lógica pura** (config mínima ya hecha, arranque rápido, cero presets RN) y **añadir jest-expo solo si/aparecen tests de componentes React Native**.

```jsonc
// package.json (si se añade jest-expo en el futuro)
{
  "scripts": { "test": "vitest run", "test:rn": "jest" },
  "jest": {
    "preset": "jest-expo",
    "transformIgnorePatterns": [
      "node_modules/(?!((jest-)?react-native|@react-native(-community)?)|expo(nent)?|@expo(nent)?/.*|@expo-google-fonts/.*|react-navigation|@react-navigation/.*|@sentry/react-native|native-base|react-native-svg)"
    ]
  }
}
```

(Con pnpm aislado, jest requiere añadir `.pnpm` al lookahead negativo; con vitest esto no aplica.)

---

## 10. Configuración exacta recomendada para CinemaSubs

### app.json (ajustes clave)

- **Mover `deploymentTarget` fuera del plugin** a la propiedad integrada (la del plugin está deprecada desde SDK 56) y **quitar `newArchEnabled`** (SDK 57 no se puede ejecutar sin New Arch; la opción es un no-op):

```jsonc
{
  "expo": {
    "name": "CinemaSubs",
    "slug": "cinemasubs",
    "version": "0.1.0",
    "scheme": "cinemasub",
    "ios": {
      "supportsTablet": false,
      "bundleIdentifier": "com.cinemasubs.app",
      "deploymentTarget": "26.0",              // <-- mecanismo correcto en SDK 56+
      "infoPlist": {
        "NSMicrophoneUsageDescription": "El micrófono se utiliza únicamente mientras los subtítulos están activos, para transcribir el audio de la película y traducirlo al español. No se guarda ninguna grabación."
      }
    },
    "plugins": [
      "expo-router"
      // expo-build-properties puede eliminarse si solo se usaba para deploymentTarget/newArchEnabled;
      // déjalo solo si en el futuro necesitas otras opciones (useFrameworks, extraPods, enableSceneSupport...)
    ]
  }
}
```

### eas.json (perfiles con imagen fijada)

```jsonc
{
  "cli": {
    "version": ">= 15.0.0",
    "appVersionSource": "remote"
  },
  "build": {
    "development": {
      "developmentClient": true,
      "distribution": "internal",
      "ios": {
        "image": "macos-tahoe-26.5-xcode-26.6",   // Xcode 26.6 (iOS 26 SDK), alias sdk-57/latest
        "resourceClass": "medium",
        "buildConfiguration": "Debug"
      }
    },
    "preview": {
      "distribution": "internal",
      "ios": {
        "image": "macos-tahoe-26.5-xcode-26.6",
        "resourceClass": "medium"
      }
    },
    "production": {
      "autoIncrement": true,
      "ios": {
        "image": "macos-tahoe-26.5-xcode-26.6",
        "resourceClass": "medium"
      }
    }
  },
  "submit": { "production": {} }
}
```

### pnpm / .npmrc

- **No se necesita `.npmrc`** ni `node-linker=hoisted`: el proyecto ya corre en pnpm **aislado**, soportado oficialmente desde SDK 54, y EAS detecta pnpm por `pnpm-lock.yaml`. Mantener `pnpm-workspace.yaml` como está. Fallback documentado si Metro da problemas raros de resolución: añadir `nodeLinker: hoisted` a `pnpm-workspace.yaml`.

### Secuencia PowerShell: de cero a dev build instalada en el iPhone

```powershell
# 0) Prerrequisitos (una vez)
node -v                                  # LTS 24.x (mínimo 22.13)
corepack enable                          # habilita pnpm si no está instalado
pnpm -v
npm install --global eas-cli             # EAS CLI global
eas login                                # cuenta Expo; verificar con: eas whoami

# 1) Dependencias del proyecto (repo ya clonado en D:\Codex\CinemaSub)
cd D:\Codex\CinemaSub
pnpm install
# (expo-dev-client, expo-keep-awake, expo-brightness ya están en package.json;
#  si faltaran: pnpm exec expo install expo-dev-client expo-keep-awake expo-brightness)
pnpm dlx expo-doctor@latest              # sanidad de versiones

# 2) eas.json (si no existiera: eas build:configure) y editarlo con el contenido de arriba

# 3) Registrar el iPhone físico (UDID)
eas device:create                        # abrir la URL/QR EN EL IPHONE -> instala perfil -> capta UDID
eas device:list                          # verificar que aparece

# 4) Primera build de desarrollo iOS (requiere Apple Developer Program de pago)
eas build --platform ios --profile development
#   - Login con Apple ID cuando lo pida
#   - Dejar que EAS genere/gestione credenciales (certificado distribución + perfil ad hoc con tu UDID)

# 5) Instalar en el iPhone
#   - Al terminar la build: pulsar Y / abrir el enlace o QR EN EL IPHONE
#   - Si iOS lo pide: Ajustes > Privacidad y seguridad > Modo de desarrollador -> activar y reiniciar

# 6) Metro desde Windows (iPhone y PC en la MISMA red Wi-Fi)
pnpm exec expo start --dev-client        # o simplemente: pnpm start
#   - Abrir CinemaSubs en el iPhone; conectar al dev server (exp://<IP-PC>:8081) o escanear el QR
#   - Red problemática: pnpm exec expo start --dev-client --tunnel
```

---

## 11. Fuentes

- Anuncio SDK 57: https://expo.dev/changelog/sdk-57 (y https://expo.dev/changelog)
- Versiones/requirements SDK 57: https://docs.expo.dev/versions/latest/
- Imágenes macOS/Xcode de EAS Build: https://docs.expo.dev/build-reference/infrastructure/
- expo-build-properties (deploymentTarget deprecado; enableSceneSupport): https://docs.expo.dev/versions/latest/sdk/build-properties/
- Expo Modules API — get started (`--local`): https://docs.expo.dev/modules/get-started/
- Tutorial módulo nativo (JS + Swift): https://docs.expo.dev/modules/native-module-tutorial/
- Referencia Modules API (Function/AsyncFunction/Events/Records/AppContext): https://docs.expo.dev/modules/module-api/
- Schema expo-module.config.json: https://docs.expo.dev/modules/module-config/
- Autolinking (nativeModulesDir): https://docs.expo.dev/modules/autolinking/
- Plantilla oficial del módulo (podspec, snippets Swift): https://github.com/expo/expo/tree/main/packages/expo-module-template y https://github.com/expo/expo/tree/main/packages/create-expo-module
- pnpm (nodeLinker, modo aislado desde SDK 54, pnpm-lock en EAS): https://docs.expo.dev/more/create-expo/
- Setup EAS Build: https://docs.expo.dev/build/setup/ · esquema eas.json: https://docs.expo.dev/build/eas-json/
- Distribución interna / ad hoc / UDID: https://docs.expo.dev/build/internal-distribution/
- Credenciales iOS: https://docs.expo.dev/app-signing/app-credentials/
- Development builds: https://docs.expo.dev/develop/development-builds/introduction/
- New Architecture (SDK 55+ sin opt-out): https://docs.expo.dev/guides/new-architecture/
- expo-keep-awake: https://docs.expo.dev/versions/latest/sdk/keep-awake/ · expo-brightness: https://docs.expo.dev/versions/latest/sdk/brightness/
- Unit testing con Jest (jest-expo): https://docs.expo.dev/develop/unit-testing/
- Node.js LTS (24 activa a sep-2026): https://nodejs.org / https://endoflife.date/nodejs

## 12. Riesgos e incertidumbres

- **TypeScript ~6.0.3**: confirmado en el proyecto local; las páginas oficiales consultadas no fijan versión de TS para el SDK 57 y la plantilla de módulos (rama main, SDK 58-preview) usa `^5.9.2`. Trátalo como hecho local, no como pin oficial.
- **deploymentTarget 26.0**: reduce drásticamente la base instalable (solo iOS 26+). Apple exige compilar con el SDK de iOS 26 (Xcode 26.x) para App Store; cuando exija iOS 27 SDK (históricamente en primavera del año siguiente) hará falta SDK 58 o `enableSceneSupport` en SDK 57.
- **Imagen EAS**: `macos-tahoe-26.5-xcode-26.6` es `latest`/`sdk-57` hoy (2026-09-19); Expo puede añadir imágenes nuevas (p. ej. Xcode 26.7) — fijar el nombre exacto da reproducibilidad, el alias `sdk-57` se mueve solo si Expo lo decide.
- **Módulos locales sin package.json** y flag `--barrel`: verificados en la rama main de `create-expo-module` (CLI versionada en lockstep: 57.x = SDK 57). Si la 57.x pública difiriera en algún detalle, lo único realmente requerido es `expo-module.config.json`; el `package.json` que ya tiene `modules/cinema-native` es válido y no estorba.
- **Ad hoc**: límite 100 iPhones/año; perfiles caducan a los 12 meses; nuevo UDID ⇒ rebuild o `eas build:resign`; Apple puede tardar 24–72 h en procesar dispositivos de cuentas nuevas (primera build puede fallar).
- **USB vs Wi-Fi**: desde Windows no hay equivalente de `adb reverse` para iPhone; el dev client de iOS necesita alcanzar Metro por red (misma Wi-Fi/hotspot) o `--tunnel` (ngrok). Es una limitación de plataforma, no de Expo.
- **Vitest**: correcto para TS puro, pero sin respaldo oficial de Expo para tests de componentes RN; si se añaden, migrar esos tests a jest-expo.
- **Permissions DSL**: la referencia vigente de la Modules API ya no documenta `Permissions(...)` como componente (solo `appContext.permissions` legacy); si el módulo nativo necesitara permisos propios, verificar el estado del arte en ese momento.
