#!/usr/bin/env bash
# Kill everything running in the RBR Wine prefix
# Settings saved by setup.sh; the environment wins
cfg="${XDG_CONFIG_HOME:-$HOME/.config}/rsf-on-linux/config"
p="${WINEPREFIX:-}" g="${GE_DIR:-}"
# shellcheck source=/dev/null
[ -f "$cfg" ] && . "$cfg"
export WINEPREFIX="${p:-${WINEPREFIX:-$HOME/.wine-rbr-ge}}"
GE_DIR="${g:-${GE_DIR:-$HOME/.local/share/proton-ge/GE-Proton11-9-x86_64}}"

# A Wine process whose environment names this prefix. Requiring a Wine binary
# keeps a session-wide WINEPREFIX from matching the terminal or desktop.
# Check every thread: a half-dead process (zombie leader + hung threads) has
# no readable environ or exe on the leader, but its live threads still show them
in_prefix() {
    local t exe
    for t in "/proc/$1/task/"*; do
        exe=$(readlink "$t/exe" 2>/dev/null)
        case "${exe% (deleted)}" in
            */wine|*/wine64|*/wine-preloader|*/wine64-preloader|*/wineserver) ;;
            *) continue ;;
        esac
        { tr '\0' '\n' < "$t/environ" | grep -Fqx "WINEPREFIX=$WINEPREFIX"; } 2>/dev/null && return 0
    done
    return 1
}

list() {
    for d in /proc/[0-9]*; do
        in_prefix "${d#/proc/}" && echo "${d#/proc/}"
    done
}

# Proton-GE's wineserver: the system one is a different version and can't stop it
"$GE_DIR/files/bin/wineserver" -k 2>/dev/null
sleep 1

# Force-kill orphans (wineserver may already be gone); only this prefix
for pid in $(list); do kill -9 "$pid" 2>/dev/null; done
sleep 1

echo "Remaining processes in $WINEPREFIX:"
left=$(list)
if [ -n "$left" ]; then
    ps -o pid,stat,cmd -p "$(paste -sd, <<< "$left")" | cut -c1-100
else
    echo "  none"
fi
