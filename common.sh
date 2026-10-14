# shellcheck shell=bash disable=SC2034
# Shared by setup.sh, run.sh and kill.sh; sourced, not run.
RSF_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/rsf-on-linux/config"
RSF_GE_VERSION="GE-Proton11-9"  # bump here; setup.sh installs it on its next run
RSF_GE_ROOT="$HOME/.local/share/proton-ge"

# Settings: the environment, else what setup.sh saved, else the defaults.
# The prefix is RSF_WINEPREFIX, not WINEPREFIX: that one is often set
# session-wide for another prefix, and the runtimes would end up in it.
rsf_load_config() {
    local env_rbr="${RBR_DIR:-}" env_prefix="${RSF_WINEPREFIX:-}" env_ge="${GE_DIR:-}"
    local WINEPREFIX=""  # configs written before RSF_WINEPREFIX used this name
    RBR_DIR="" RSF_WINEPREFIX="" GE_DIR=""
    # shellcheck source=/dev/null
    if [ -f "$RSF_CONFIG" ]; then . "$RSF_CONFIG"; fi
    RBR_DIR="${env_rbr:-$RBR_DIR}"
    RSF_WINEPREFIX="${env_prefix:-${RSF_WINEPREFIX:-${WINEPREFIX:-$HOME/.wine-rbr-ge}}}"
    GE_DIR="${env_ge:-${GE_DIR:-$RSF_GE_ROOT/$RSF_GE_VERSION-x86_64}}"
}
