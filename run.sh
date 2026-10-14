#!/usr/bin/env bash
# Launch the RallySimFans launcher under Proton-GE's Wine (log: ./rbr.log, previous run: ./rbr.log.1)
# System wine 11.19 (dev) has a wineserver crash at exit; GE-Proton11-9 fixes it.
DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=common.sh
. "$DIR/common.sh"
rsf_load_config

# Print the error; from the menu there's no terminal, so also show it in a dialog
fail() {
    echo "$1" >&2
    if [ ! -t 2 ]; then
        zenity --error --no-markup --title="RSF Launcher" --text="$1" 2>/dev/null ||
        kdialog --title "RSF Launcher" --error "$1" 2>/dev/null ||
        notify-send -u critical "RSF Launcher" "$1" 2>/dev/null
    fi
    exit 1
}

if [ -z "${RBR_DIR:-}" ]; then
    fail "Richard Burns Rally folder not set. Run setup.sh or set RBR_DIR."
elif [ ! -d "$RBR_DIR/rsf_launcher" ]; then
    fail "RSF launcher not found in: $RBR_DIR
Was the game moved? Run setup.sh again or set RBR_DIR."
fi
export WINEPREFIX="$RSF_WINEPREFIX"
G="$GE_DIR/files"
export PATH="$G/bin:$PATH"
export WINEDLLPATH="$G/lib/wine"
export LD_LIBRARY_PATH="$G/lib:$G/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export DOTNET_SYSTEM_GLOBALIZATION_USENLS=1
# Same overrides as the Lutris RSF installer: use the game's bundled old MSVC/MFC runtimes
export WINEDLLOVERRIDES="dinput8=n,b;mfc70,mfc71,msvci70,msvcp70,msvcp71,msvcr70,msvcr71=n${WINEDLLOVERRIDES:+;$WINEDLLOVERRIDES}"
export WINEDEBUG="${WINEDEBUG:-err+all}"

LOG="$DIR/rbr.log"
if [ -f "$LOG" ]; then mv -f "$LOG" "$LOG.1"; fi  # keep the log of a crashed run

cd "$RBR_DIR/rsf_launcher" || exit 1
wine RSF_Launcher.exe "$@" 2>&1 | grep --line-buffered -v fixme > "$LOG"
status=${PIPESTATUS[0]}

# Clean up anything Wine left behind
wineserver -k 2>/dev/null
exit "$status"
