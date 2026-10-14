# Richard Burns Rally (RallySimFans) on Linux: issues and fixes

Setup date: 2026-10-14. Game dir: `/mnt/storage-1tb/Richard Burns Rally/`.
Host: openSUSE-style system, kernel 7.2.9, Wayland, AMD RX 6800-class GPU.

## Final working setup

| Part | Value |
|---|---|
| Wine | Proton-GE `GE-Proton11-9` (Wine 11.0 Staging), `~/.local/share/proton-ge/GE-Proton11-9-x86_64/files` |
| Prefix | `~/.wine-rbr-ge` (copy of `~/.wine-rbr`; the old prefix can be deleted) |
| Installed in prefix | .NET Desktop Runtime 10 (x86 + x64), VC++ 2015-2022 (x86 + x64), corefonts, tahoma, d3dx9, DXVK 3.1.1 |
| Start | `./run.sh` (log in `rbr.log`) |
| Clean up | `./kill.sh` |

## Setup from scratch

One-liner, no clone needed (installs `run.sh`/`kill.sh` to `~/.local/share/rsf-on-linux` and adds a menu entry):

```bash
curl -fsSL https://raw.githubusercontent.com/SpaceC4t-dev/rsf-on-linux/main/setup.sh | bash
```

Or from a clone: `./setup.sh`, then `./run.sh`. Needs `curl`, `cabextract`, `sha512sum`, `tar`; `magick` is optional (menu icon).

`setup.sh` downloads Proton-GE (SHA-512 verified), fetches upstream winetricks at a pinned commit, creates the prefix, installs the runtimes listed above and applies the rendering tweaks from issue 6. It skips finished steps, so it is safe to re-run. It expects the RSF launcher already installed in `RBR_DIR`.

Paths are overridable: `RBR_DIR` (game folder), `GE_DIR` (Proton-GE), `WINEPREFIX`.

`run.sh` sets: GE `PATH`/`WINEDLLPATH`/`LD_LIBRARY_PATH`, `DOTNET_SYSTEM_GLOBALIZATION_USENLS=1`, and the DLL overrides below.

## Issues and fixes (in the order they appeared)

### 1. Launcher: ".NET location: Not found"
- **Cause:** `RSF_Launcher.exe` is a 32-bit .NET 10 WPF app (apphost 10.0.9). The prefix had no .NET.
- **Fix:** install .NET Desktop Runtime 10. The system winetricks (20260125) has no `dotnetdesktop10` verb, but upstream master does. Used the upstream script with `dotnetdesktop10` in a new prefix. It installs the x86 and x64 runtimes from Microsoft with pinned checksums.

### 2. Launcher crash in WPF text code (`TypefaceMap.MapUnresolvedCharacters`)
- **Cause:** the new prefix had no fonts.
- **Fix:** `winetricks corefonts tahoma`.

### 3. Error box: "Missing or old version of Microsoft Visual C++ runtime libraries"
- **Cause:** a true positive. The prefix had no VC++ runtimes.
- **Fix:** `winetricks vcrun2022` (installs x86 and x64). Verified with `reg query ...\VC\Runtimes\x86 /reg:32` and `x64` = v14.44.35211.00.

### 4. Game exit hangs on a black screen with the launcher
- **Symptom:** after quitting the game, the launcher stayed on a black screen. `richardburnsral` and `explorer.exe` showed as `<defunct>` zombies whose other threads were stuck in futex/ntsync waits. `wineserver -k` found nothing to kill.
- **Root cause:** `wineserver` of the distro's Wine **11.19 (a development release)** segfaulted on every run (4 of 4 cores in `coredumpctl`, same instruction at `wineserver+0x2f0ef`, NULL `rdi`, in handle-table allocation). With the server dead, the Wine processes were orphaned.
- **Not the cause:** DXVK, `WINE_DISABLE_NTSYNC=1`, fullscreen mode.
- **Fix:** Proton-GE 11-9 (its release notes list fixes for process-exit hangs and Richard Burns Rally's exit crash). Downloaded from GitHub and the SHA-256 was verified.
- **Manual cleanup if it ever recurs:** `./kill.sh`. Zombie leaders can only be removed with `kill -9 <pid>`.

### 5. Under GE: launcher fails with `Error: 127` / `Cannot get symbol u_charsToUChars from libicuuc`
- **Cause:** .NET loads Wine's `icu.dll`, which forwards to `icuuc68`, and GE doesn't provide that.
- **Fix:** `DOTNET_SYSTEM_GLOBALIZATION_USENLS=1` (use Windows NLS, not ICU).
- **Did not work:** `DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1` made WPF fail with `XamlParseException: Cannot find non-neutral culture related to 'en-us'`.

### 6. Launcher: blurry font and black flicker when resizing
- **Tweaks applied to `~/.wine-rbr-ge`:** `HKCU\Software\Microsoft\Avalon.Graphics\DisableHWAcceleration=1` (software WPF rendering) and `FontSmoothingType=2` (ClearType). Backup: `user.reg.bak-before-ui-tweaks`.
- **Status:** judged cosmetic and set aside. If blur persists, it is probably Wayland/XWayland scaling. In KDE, use Display → Legacy applications → "Apply scaling themselves" and set Wine's DPI in `winecfg` to match.

### 7. Engine RPM needle rose extremely slowly in stages
- **Observed:** the car physics looked fine, but holding the throttle made the needle crawl, regardless of input device.
- **Change made:** the same DLL overrides as the Lutris RSF installer, so the game uses its bundled old runtimes instead of Wine's builtin replacements:
  `WINEDLLOVERRIDES="dinput8=n,b;mfc70,mfc71,msvci70,msvcp70,msvcp71,msvcr70,msvcr71=n"`
- **Status:** the game runs fine now. The fix was not isolated, so the overrides are the most likely cause but are not confirmed.

## Harmless log messages
- `OpenRBRTriples.dll` / `OpenRBRVR.dll` not loaded (only needed for triple screens or VR).
- `CPC_SaveFileManager::Init: LoadMenuSettings failed` at game start.
- `RBRControls`: "Failed to find any joystick devices" when no wheel or pedals are connected.

## Useful commands
```bash
./run.sh                     # start the launcher
./kill.sh                    # kill everything in the prefix
coredumpctl list wineserver  # check for wineserver crashes
```
For gamepads: the game reads LT/RT as one axis. Rebind them with input-remapper or sc-controller, and keep the launcher's "Split xbox gamepad triggers" option off.
