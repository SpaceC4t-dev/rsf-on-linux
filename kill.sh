#!/usr/bin/env bash
# Kill everything running in the RBR Wine prefix
DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=common.sh
. "$DIR/common.sh"
rsf_load_config
export WINEPREFIX="$RSF_WINEPREFIX"

# Wine processes whose environment names this prefix. Requiring a Wine binary
# keeps a session-wide WINEPREFIX from matching the terminal or desktop.
# Work per thread: a half-dead process (zombie leader + hung threads) has no
# readable exe or environ on the leader, but its live threads still show them.
# One find call picks the Wine threads; a readlink per thread takes seconds.
wine_threads() {
    local names=() n
    for n in wine wine64 wine-preloader wine64-preloader wineserver; do
        names+=(-o -lname "*/$n" -o -lname "*/$n (deleted)")
    done
    find /proc/[0-9]*/task/*/exe -maxdepth 0 \( "${names[@]:1}" \) 2>/dev/null
}

list() {
    local pid tid seen=" " vars v
    while IFS=/ read -r _ _ pid _ tid _; do
        case "$seen" in *" $pid "*) continue ;; esac
        # The leader of a half-dead process can't be read; try its other threads
        mapfile -d '' -t vars < "/proc/$pid/task/$tid/environ" 2>/dev/null || continue
        [ ${#vars[@]} -gt 0 ] || continue
        seen+="$pid "
        for v in "${vars[@]}"; do
            if [ "$v" = "WINEPREFIX=$WINEPREFIX" ]; then echo "$pid"; break; fi
        done
    done < <(wine_threads)
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
