# rsf-on-linux

Run the [RallySimFans](https://rallysimfans.hu) launcher for Richard Burns Rally on Linux, using Proton-GE's Wine with all the runtimes it needs (.NET 10, VC++, DXVK, fonts).

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/SpaceC4t-dev/rsf-on-linux/main/setup.sh | bash
```

Requires `curl`, `cabextract`, `sha512sum`, `tar`, and RBR with the RSF launcher already installed. It finds the game in the usual places (`~/Games`, Steam); if it can't, or to pick one yourself:

```bash
curl -fsSL https://raw.githubusercontent.com/SpaceC4t-dev/rsf-on-linux/main/setup.sh | RBR_DIR="/path/to/Richard Burns Rally" bash
```

Then start **RSF Launcher** from your application menu, or run `~/.local/share/rsf-on-linux/run.sh`. If anything gets stuck, `kill.sh` in the same folder stops everything running in the prefix.

## Options

Environment variables for `setup.sh` (and `run.sh`): `RBR_DIR` (game folder; remembered in `~/.config/rsf-on-linux/config` after setup), `WINEPREFIX` (default `~/.wine-rbr-ge`), `GE_DIR` (Proton-GE location), `INSTALL_DIR` (where the scripts go).

## Known issues and fixes

`setup.sh` already applies the fixes marked ✔. The rest is for troubleshooting or doing it by hand.

1. **".NET location: Not found"** ✔. The launcher is a 32-bit .NET 10 WPF app, so it needs the .NET Desktop Runtime 10 (x86 + x64). Distro winetricks may lack the `dotnetdesktop10` verb, so `setup.sh` uses upstream winetricks at a pinned commit.
2. **Crash in `TypefaceMap.MapUnresolvedCharacters`** ✔. A prefix without fonts. Fix: `winetricks corefonts tahoma`.
3. **"Missing or old version of Microsoft Visual C++ runtime libraries"** ✔. A genuine error. Fix: `winetricks vcrun2022`.
4. **Black screen with the launcher after quitting the game; `richardburnsral` and `explorer.exe` left as `<defunct>`** ✔. Cause: `wineserver` from Wine 11.19 (a development release) segfaults on every run, which orphans the Wine processes. Fix: Proton-GE (GE-Proton11-9), whose notes list fixes for process-exit hangs and RBR's exit crash. If it ever recurs, run `kill.sh`; zombie leaders can only be removed with `kill -9 <pid>`. DXVK, `WINE_DISABLE_NTSYNC=1` and fullscreen mode were ruled out.
5. **Under Proton-GE: `Error: 127` / `Cannot get symbol u_charsToUChars from libicuuc`** ✔ (set in `run.sh`). .NET loads Wine's `icu.dll`, which forwards to `icuuc68`, and GE doesn't provide that. Fix: `DOTNET_SYSTEM_GLOBALIZATION_USENLS=1`. `DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1` does not work (WPF fails with `XamlParseException: Cannot find non-neutral culture related to 'en-us'`).
6. **Launcher: blurry font and flicker when resizing.** Applied ✔: `HKCU\Software\Microsoft\Avalon.Graphics\DisableHWAcceleration=1` (software WPF rendering) and `FontSmoothingType=2` (ClearType). **Not fixed:** the flicker remains, probably XWayland. Ideas: Wine's native Wayland driver (`HKCU\Software\Wine\Drivers\Graphics=wayland,x11`, untested for the game), a Wine virtual desktop, or in KDE Display → Legacy applications → "Apply scaling themselves" with a matching DPI in `winecfg`.
7. **Engine RPM needle rises extremely slowly in stages** ✔ (set in `run.sh`). Likely cause: Wine's builtin runtimes replacing the game's. Fix: the same DLL overrides as the Lutris RSF installer: `WINEDLLOVERRIDES="dinput8=n,b;mfc70,mfc71,msvci70,msvcp70,msvcp71,msvcr70,msvcr71=n"`. The fix was not isolated, so this is probable but unconfirmed.

### Harmless log messages
- `OpenRBRTriples.dll` / `OpenRBRVR.dll` not loaded (only needed for triple screens or VR).
- `CPC_SaveFileManager::Init: LoadMenuSettings failed` at game start.
- `RBRControls`: "Failed to find any joystick devices" when no wheel or pedals are connected.

### Gamepads
The game reads LT/RT as one axis. Rebind them with input-remapper or sc-controller, and keep the launcher's "Split xbox gamepad triggers" option off.
