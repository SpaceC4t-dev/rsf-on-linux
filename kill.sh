#!/usr/bin/env bash
# Kill everything running in the RBR Wine prefix
# Settings saved by setup.sh; the environment wins
cfg="${XDG_CONFIG_HOME:-$HOME/.config}/rsf-on-linux/config"
r="${RBR_DIR:-}" p="${WINEPREFIX:-}" g="${GE_DIR:-}"
[ -f "$cfg" ] && . "$cfg"
export WINEPREFIX="${p:-${WINEPREFIX:-$HOME/.wine-rbr-ge}}"
GE_DIR="${g:-${GE_DIR:-$HOME/.local/share/proton-ge/GE-Proton11-9-x86_64}}"

in_prefix() {
    [ -r "/proc/$1/environ" ] || return 1
    { tr '\0' '\n' < "/proc/$1/environ" | grep -qx "WINEPREFIX=$WINEPREFIX"; } 2>/dev/null
}

list() {
    for d in /proc/[0-9]*; do
        pid=${d#/proc/}
        [ "$pid" != "$$" ] && in_prefix "$pid" && echo "$pid"
    done
}

# Proton-GE's wineserver: the system one is a different version and can't stop it
"$GE_DIR/files/bin/wineserver" -k 2>/dev/null
sleep 1

# Force-kill orphans (wineserver may already be gone); only this prefix
for pid in $(list); do kill -9 "$pid" 2>/dev/null; done
# Half-dead processes (zombie leader + hung threads) have no readable
# environ, so match them by name instead
for pid in $(pgrep -u "$USER" -x 'richardburnsral|RSF_Launcher.ex|explorer.exe|winedevice.exe|svchost.exe|services.exe|plugplay.exe|rpcss.exe'); do
    kill -9 "$pid" 2>/dev/null
done
sleep 1

echo "Remaining processes in $WINEPREFIX:"
left=$(list)
if [ -n "$left" ]; then
    # shellcheck disable=SC2086
    ps -o pid,stat,cmd -p $(echo $left | tr ' ' ',') | cut -c1-100
else
    echo "  none"
fi
