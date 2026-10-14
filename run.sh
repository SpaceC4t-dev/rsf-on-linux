#!/usr/bin/env bash
# Launch the RallySimFans launcher under Proton-GE's Wine (log: ./rbr.log)
# System wine 11.19 (dev) has a wineserver crash at exit; GE-Proton11-9 fixes it.
# Settings saved by setup.sh; the environment wins
cfg="${XDG_CONFIG_HOME:-$HOME/.config}/rsf-on-linux/config"
r="${RBR_DIR:-}" p="${WINEPREFIX:-}" g="${GE_DIR:-}"
# shellcheck source=/dev/null
[ -f "$cfg" ] && . "$cfg"
RBR_DIR="${r:-${RBR_DIR:-}}"
export WINEPREFIX="${p:-${WINEPREFIX:-$HOME/.wine-rbr-ge}}"
GE_DIR="${g:-${GE_DIR:-$HOME/.local/share/proton-ge/GE-Proton11-9-x86_64}}"
[ -d "${RBR_DIR:-}/rsf_launcher" ] || { echo "RBR_DIR not set or invalid; run setup.sh or set RBR_DIR" >&2; exit 1; }
G="$GE_DIR/files"
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
status=${PIPESTATUS[0]}

# Clean up anything Wine left behind
wineserver -k 2>/dev/null
exit "$status"
