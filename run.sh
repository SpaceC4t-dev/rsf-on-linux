#!/usr/bin/env bash
# Launch the RallySimFans launcher under Proton-GE's Wine (log: ./rbr.log)
# System wine 11.19 (dev) has a wineserver crash at exit; GE-Proton11-9 fixes it.
# Override any of these from the environment.
RBR_DIR="${RBR_DIR:-/mnt/storage-1tb/Richard Burns Rally}"
G="${GE_DIR:-$HOME/.local/share/proton-ge/GE-Proton11-9-x86_64}/files"
export WINEPREFIX="${WINEPREFIX:-$HOME/.wine-rbr-ge}"
export PATH="$G/bin:$PATH"
export WINEDLLPATH="$G/lib/wine"
export LD_LIBRARY_PATH="$G/lib:$G/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export DOTNET_SYSTEM_GLOBALIZATION_USENLS=1
# Same overrides as the Lutris RSF installer: use the game's bundled old MSVC/MFC runtimes
export WINEDLLOVERRIDES="dinput8=n,b;mfc70,mfc71,msvci70,msvcp70,msvcp71,msvcr70,msvcr71=n${WINEDLLOVERRIDES:+;$WINEDLLOVERRIDES}"
export WINEDEBUG="${WINEDEBUG:-err+all}"

LOG="$(cd "$(dirname "$0")" && pwd)/rbr.log"

cd "$RBR_DIR/rsf_launcher" || exit 1
wine RSF_Launcher.exe "$@" 2>&1 | grep --line-buffered -v fixme > "$LOG"

# Clean up anything Wine left behind
wineserver -k 2>/dev/null
