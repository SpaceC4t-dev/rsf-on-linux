#!/usr/bin/env bash
# One-shot setup for the RSF launcher on Linux: Proton-GE, Wine prefix, runtimes,
# run/kill scripts and a menu entry. Safe to re-run: finished steps are skipped.
#   curl -fsSL https://raw.githubusercontent.com/SpaceC4t-dev/rsf-on-linux/main/setup.sh | bash
# Overridable from the environment:
#   RBR_DIR, RSF_WINEPREFIX, GE_VERSION, GE_DIR, INSTALL_DIR
set -euo pipefail

TARBALL_URL="https://github.com/SpaceC4t-dev/rsf-on-linux/archive/refs/heads/main.tar.gz"
# The distro winetricks (20260125) has no dotnetdesktop10 verb; use upstream at a pinned commit.
WINETRICKS_COMMIT="f3890f670867b5ffbc3938726db45c0f7d16c8ba"
WINETRICKS_URL="https://raw.githubusercontent.com/Winetricks/winetricks/$WINETRICKS_COMMIT/src/winetricks"
VERBS=(corefonts tahoma vcrun2022 d3dx9 dxvk dotnetdesktop10)

say() { printf '\n==> %s\n' "$*"; }
die() { echo "error: $*" >&2; exit 1; }
abspath() { case "$1" in /*) printf '%s' "${1%/}" ;; *) printf '%s/%s' "$PWD" "${1%/}" ;; esac; }

for cmd in curl sha512sum tar cabextract; do
    command -v "$cmd" >/dev/null || die "missing dependency: $cmd"
done

# 0. Run from a full copy of the repo, so setup.sh and the scripts it installs
# always come from the same commit. Piped into bash (or a lone setup.sh), fetch
# main as one tarball into INSTALL_DIR and re-run setup.sh from there.
SELF=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
    SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
fi
if [ -z "$SELF" ] || [ ! -f "$SELF/common.sh" ]; then
    [ -z "${RSF_BOOTSTRAPPED:-}" ] || die "downloaded copy has no common.sh"
    INSTALL_DIR="$(abspath "${INSTALL_DIR:-$HOME/.local/share/rsf-on-linux}")"
    say "Downloading rsf-on-linux to $INSTALL_DIR"
    mkdir -p "$INSTALL_DIR"
    curl -fsSL "$TARBALL_URL" | tar -xz --strip-components=1 -C "$INSTALL_DIR"
    export RSF_BOOTSTRAPPED=1 INSTALL_DIR
    exec bash "$INSTALL_DIR/setup.sh"
fi
INSTALL_DIR="${INSTALL_DIR:-$SELF}"
mkdir -p "$INSTALL_DIR"
INSTALL_DIR="$(cd "$INSTALL_DIR" && pwd -P)"
if [ "$INSTALL_DIR" != "$SELF" ]; then
    say "Copying run.sh, kill.sh and common.sh to $INSTALL_DIR"
    cp "$SELF/run.sh" "$SELF/kill.sh" "$SELF/common.sh" "$INSTALL_DIR/"
fi

# Settings (see common.sh). Proton-GE is the exception: a re-run installs
# GE_VERSION (default: the current one) unless GE_DIR is given, so updating
# this repo also updates Wine.
user_ge_dir="${GE_DIR:-}"
# shellcheck source=common.sh
. "$SELF/common.sh"
rsf_load_config
GE_VERSION="${GE_VERSION:-$RSF_GE_VERSION}"
GE_DIR="$(abspath "${user_ge_dir:-$RSF_GE_ROOT/$GE_VERSION-x86_64}")"
RSF_WINEPREFIX="$(abspath "$RSF_WINEPREFIX")"
export WINEPREFIX="$RSF_WINEPREFIX"

# Game folder: $RBR_DIR, else the saved one, else a few common locations
if [ -z "${RBR_DIR:-}" ]; then
    for d in "$HOME/Games/Richard Burns Rally" "$HOME/Games/richard-burns-rally/drive_c/Richard Burns Rally" \
             "$HOME/.local/share/Steam/steamapps/common/Richard Burns Rally" \
             "$HOME/.steam/steam/steamapps/common/Richard Burns Rally"; do
        [ -d "$d/rsf_launcher" ] && RBR_DIR="$d" && break
    done
fi
if [ -z "${RBR_DIR:-}" ] || [ ! -d "$RBR_DIR/rsf_launcher" ]; then
    die "RSF launcher not found. Pass the game folder: RBR_DIR=\"/path/to/Richard Burns Rally\""
fi
RBR_DIR="$(abspath "$RBR_DIR")"
mkdir -p "${RSF_CONFIG%/*}"
# run.sh and kill.sh read these, so the menu entry uses the same game, prefix and Wine
printf 'RBR_DIR=%q\nRSF_WINEPREFIX=%q\nGE_DIR=%q\n' "$RBR_DIR" "$RSF_WINEPREFIX" "$GE_DIR" > "$RSF_CONFIG"

# 1. Proton-GE (Wine 11.0 Staging), checksum-verified. Extracted next to GE_DIR
# and renamed into place, so an interrupted run can't leave a half-extracted
# Wine that looks installed.
if [ -x "$GE_DIR/files/bin/wine" ]; then
    say "Proton-GE already installed: $GE_DIR"
else
    [ ! -e "$GE_DIR" ] || die "$GE_DIR exists but has no files/bin/wine; remove it or set GE_DIR elsewhere"
    say "Downloading $GE_VERSION"
    mkdir -p "${GE_DIR%/*}"
    tmp=$(mktemp -d "${GE_DIR%/*}/.rsf-download.XXXXXX")
    trap 'rm -rf "$tmp"' EXIT
    name="$GE_VERSION-x86_64"
    ge_url="https://github.com/GloriousEggroll/proton-ge-custom/releases/download/$GE_VERSION"
    curl -fL -o "$tmp/$name.tar.gz" "$ge_url/$name.tar.gz"
    curl -fL -o "$tmp/$name.sha512sum" "$ge_url/$name.sha512sum"
    (cd "$tmp" && sha512sum -c "$name.sha512sum") || die "checksum mismatch, not extracting"
    mkdir "$tmp/x"
    tar -xzf "$tmp/$name.tar.gz" -C "$tmp/x"
    top=("$tmp/x"/*)
    if [ ${#top[@]} -ne 1 ] || [ ! -x "${top[0]}/files/bin/wine" ]; then
        die "unexpected archive layout: no <folder>/files/bin/wine"
    fi
    mv "${top[0]}" "$GE_DIR"
    rm -rf "$tmp"
    trap - EXIT
fi
rm -rf "$RSF_GE_ROOT/dl"  # tarball left behind by older versions of this script

G="$GE_DIR/files"
export PATH="$G/bin:$PATH" WINEDLLPATH="$G/lib/wine"
export LD_LIBRARY_PATH="$G/lib:$G/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export WINEDEBUG=-all

# 2. Upstream winetricks
WT="$RSF_GE_ROOT/winetricks-${WINETRICKS_COMMIT:0:8}"
if [ ! -x "$WT" ]; then
    say "Fetching winetricks @ ${WINETRICKS_COMMIT:0:8}"
    mkdir -p "$RSF_GE_ROOT"
    curl -fL -o "$WT" "$WINETRICKS_URL"
    chmod +x "$WT"
fi

# 3. Prefix
if [ ! -f "$WINEPREFIX/system.reg" ]; then
    say "Creating prefix $WINEPREFIX"
    wineboot -u
    wineserver -w
fi

# 4. Runtimes (winetricks records finished verbs in winetricks.log)
for verb in "${VERBS[@]}"; do
    if grep -qx "$verb" "$WINEPREFIX/winetricks.log" 2>/dev/null; then
        say "$verb: already installed"
    else
        say "Installing $verb"
        "$WT" -q "$verb"
    fi
done

# 5. Launcher rendering tweaks: software WPF rendering and ClearType
say "Applying registry tweaks"
wine reg add 'HKCU\Software\Microsoft\Avalon.Graphics' /v DisableHWAcceleration /t REG_DWORD /d 1 /f
wine reg add 'HKCU\Control Panel\Desktop' /v FontSmoothing /d 2 /f
wine reg add 'HKCU\Control Panel\Desktop' /v FontSmoothingType /t REG_DWORD /d 2 /f
wineserver -w

# 6. Menu entry
say "Creating menu entry"
icon=applications-games
ico="$RBR_DIR/rallysimfans.ico"
icon_png="$HOME/.local/share/icons/hicolor/256x256/apps/rsf-launcher.png"
if [ -f "$ico" ] && command -v magick >/dev/null; then
    # Optional: on failure keep the generic icon rather than abort the setup
    mkdir -p "${icon_png%/*}"
    if best=$(magick identify -format '%[fx:w*h] %p\n' "$ico" | sort -nr | head -1 | cut -d' ' -f2) &&
       [ -n "$best" ] && magick "${ico}[$best]" -resize 256x256 "$icon_png"; then
        icon=rsf-launcher
    else
        echo "warning: couldn't convert $ico, using a generic icon" >&2
    fi
fi
# Desktop entry escaping: inside a quoted Exec argument " ` $ \ need a backslash,
# then every backslash is doubled (string escaping), and % becomes %%
exec_arg() {
    local s=$1
    s=${s//\\/\\\\}; s=${s//\"/\\\"}; s=${s//\`/\\\`}; s=${s//\$/\\\$}
    s=${s//\\/\\\\}; s=${s//%/%%}
    printf '"%s"' "$s"
}
mkdir -p "$HOME/.local/share/applications"
cat > "$HOME/.local/share/applications/rsf-launcher.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=RSF Launcher
Comment=RallySimFans launcher for Richard Burns Rally
Exec=$(exec_arg "$INSTALL_DIR/run.sh")
Path=${INSTALL_DIR//\\/\\\\}
Icon=$icon
Terminal=false
Categories=Game;
StartupWMClass=rsf_launcher.exe
EOF

say "Done. Start it from the application menu or with $INSTALL_DIR/run.sh (cleanup: $INSTALL_DIR/kill.sh)"
