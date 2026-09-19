# SIDELOAD_FREE — Instalar CinemaSubs en el iPhone SIN pagar Apple Developer

**Vía 0 €:** compilar una IPA sin firmar con GitHub Actions (macOS gratuito) y firmarla
en Windows con tu Apple ID gratuita mediante Sideloadly.

## Por qué no hay nada más simple

| Alternativa | Por qué no |
|---|---|
| Expo Go | No sirve: CinemaSubs tiene módulo nativo propio (Swift). |
| EAS Build en dispositivo | Apple exige Apple Developer Program (99 USD/año) para firmar. |
| Simulador iOS | Requiere macOS; no hay Mac. |
| Firmar tú con Apple ID gratis | Sin Mac no se puede desde Xcode — Sideloadly lo replica en Windows. |

## Límites que impone Apple a cuentas gratuitas (asumidos por esta vía)

- La app **caduca a los 7 días**: re-sideload semanal (2 minutos con cable USB).
- Máximo **3 apps** activas firmadas con la misma Apple ID.
- Máximo 10 App IDs distintos por semana.
- Sin TestFlight ni distribución a otras personas.

Si más adelante pagas los 99 USD/año, pasa a la vía oficial ya documentada
([docs/WINDOWS_SETUP.md](WINDOWS_SETUP.md)) y olvídate de reinstalaciones.

## Requisitos

- PC Windows + **cable USB**.
- Cuenta **GitHub** gratuita.
- **Apple ID** gratuita con 2FA activado
  (y una [contraseña de aplicación](https://appleid.apple.com/account/manage) para Sideloadly).
- **iTunes para Windows** instalado (Apple, no la de la MS Store) — aporta los drivers USB del iPhone.
- iPhone con **iOS 26.4+** (verificar en Ajustes → General → Actualización de software).
  El iPhone 17 Pro Max cumple de sobra; solo actualiza si está en 26.0–26.3.

## Paso 1 — Subir el repo a GitHub

```powershell
cd D:\Codex\CinemaSub
git remote add origin https://github.com/TU-USUARIO/CinemaSub.git
git push -u origin main
```

- Repo **público** = macOS de GitHub Actions **gratis e ilimitado**.
- Repo privado = también vale, pero los minutos macOS consumen 10× la cuota gratuita
  (~200 min reales/mes ≈ 3-6 builds); suficiente para empezar.

## Paso 2 — Generar la IPA (automático)

1. En GitHub: pestaña **Actions** → flujo **«IPA sin firmar (instalación gratuita por sideload)»**.
2. **Run workflow** → `main` → ejecutar.
3. Espera ~30-45 min (prebuild + CocoaPods + archive Release).
4. Al terminar, en la ejecución → **Artifacts** → descargar `CinemaSubs-unsigned-ipa`
   (GitHub lo entrega como ZIP; dentro está `CinemaSubs-unsigned.ipa`).

El workflow también corre solo en cada push a `main` (ignora cambios de docs).

## Paso 3 — Instalar con Sideloadly

1. Descarga [Sideloadly](https://sideloadly.io) (gratis) e instálalo en Windows.
2. Conecta el iPhone 17 Pro Max por USB y desbloquéalo (confía en el PC si lo pide).
3. Abre Sideloadly y arrastra `CinemaSubs-unsigned.ipa`.
4. Apple ID: tu cuenta gratuita → contraseña de aplicación (si tienes 2FA).
   - Opcional (Advanced): cambiar el Bundle ID a algo único tuyo, p. ej. `com.tunombre.cinemasubs`.
5. **Start** → espera "Done".

## Paso 4 — Primera apertura en el iPhone

1. Ajustes → General → **VPN y gestión de dispositivos** → tu Apple ID → **Confiar**.
2. Abre CinemaSubs. Al ser build Release, **funciona sola**: no necesita Metro ni el PC.

## Renovación semanal (los 7 días de Apple)

- **Manual:** repetir Paso 3 con el iPhone conectado (los datos de la app no importan: no hay datos).
- **Automática (opcional):** instala [AltStore](https://altstore.io) con AltServer en el PC
  (requiere iTunes + iCloud de Apple, versiones de escritorio); AltStore re-firma apps por
  Wi-Fi cuando el PC está encendido. Instala el IPA desde AltStore en vez de Sideloadly.

## Problemas típicos

| Síntoma | Solución |
|---|---|
| Sideloadly no ve el iPhone | iTunes instalado (versión Apple, no MS Store); cable de datos; desbloquear el móvil. |
| Error de credenciales Apple | Usar contraseña de aplicación, no la normal (2FA). |
| «No se puede verificar» al abrir | Paso 4: confiar en el perfil en Gestión de dispositivos. |
| La app dejó de abrir | Pasaron 7 días: re-sideload. |
| El workflow falla | Abrir el log en Actions; si es error de compilación Swift, copiarlo al agente para corregirlo. |

## Nota sobre iterar

Esta build es **Release autocontenida**: para probar cambios de UI hay que lanzar el
workflow de nuevo (~30-45 min). Si vas a iterar mucho con Metro en vivo, la vía cómoda
sigue siendo Apple Developer + EAS (docs/WINDOWS_SETUP.md).
