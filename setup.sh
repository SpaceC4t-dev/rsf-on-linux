#!/usr/bin/env bash
# One-shot setup for the RSF launcher on Linux: Proton-GE, Wine prefix, runtimes,
# run/kill scripts and a menu entry. Safe to re-run: finished steps are skipped.
#   curl -fsSL https://raw.githubusercontent.com/SpaceC4t-dev/rsf-on-linux/main/setup.sh | bash
# Overridable from the environment:
#   GE_VERSION, GE_DIR, WINEPREFIX, RBR_DIR, INSTALL_DIR
set -euo pipefail

GE_VERSION="${GE_VERSION:-GE-Proton11-9}"
GE_ROOT="${GE_ROOT:-$HOME/.local/share/proton-ge}"
GE_DIR="${GE_DIR:-$GE_ROOT/$GE_VERSION-x86_64}"
RBR_DIR="${RBR_DIR:-/mnt/storage-1tb/Richard Burns Rally}"
export WINEPREFIX="${WINEPREFIX:-$HOME/.wine-rbr-ge}"
# The distro winetricks (20260125) has no dotnetdesktop10 verb; use upstream at a pinned commit.
WINETRICKS_COMMIT="f3890f670867b5ffbc3938726db45c0f7d16c8ba"
WINETRICKS_URL="https://raw.githubusercontent.com/Winetricks/winetricks/$WINETRICKS_COMMIT/src/winetricks"
GE_URL="https://github.com/GloriousEggroll/proton-ge-custom/releases/download/$GE_VERSION"
RAW_URL="https://raw.githubusercontent.com/SpaceC4t-dev/rsf-on-linux/main"
VERBS=(corefonts tahoma vcrun2022 d3dx9 dxvk dotnetdesktop10)

say() { printf '\n==> %s\n' "$*"; }
die() { echo "error: $*" >&2; exit 1; }

for cmd in curl sha512sum tar cabextract; do
    command -v "$cmd" >/dev/null || die "missing dependency: $cmd"
done
[ -d "$RBR_DIR/rsf_launcher" ] || die "RSF launcher not found in '$RBR_DIR/rsf_launcher' (set RBR_DIR)"

# 0. run.sh / kill.sh: use the ones next to this script (git clone), else download them
SELF="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
if [ -n "$SELF" ] && [ -f "$SELF/run.sh" ] && [ -f "$SELF/kill.sh" ]; then
    INSTALL_DIR="$SELF"
else
    INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/share/rsf-on-linux}"
    say "Installing run.sh and kill.sh to $INSTALL_DIR"
    mkdir -p "$INSTALL_DIR"
    for f in run.sh kill.sh; do
        curl -fsSL -o "$INSTALL_DIR/$f" "$RAW_URL/$f"
        chmod +x "$INSTALL_DIR/$f"
    done
fi

# 1. Proton-GE (Wine 11.0 Staging), checksum-verified
if [ -x "$GE_DIR/files/bin/wine" ]; then
    say "Proton-GE already installed: $GE_DIR"
else
    say "Downloading $GE_VERSION"
    dl="$GE_ROOT/dl"; mkdir -p "$dl"
    name="$GE_VERSION-x86_64"
    curl -fL -o "$dl/$name.tar.gz" "$GE_URL/$name.tar.gz"
    curl -fL -o "$dl/$name.sha512sum" "$GE_URL/$name.sha512sum"
    (cd "$dl" && sha512sum -c "$name.sha512sum") || die "checksum mismatch, not extracting"
    tar -xzf "$dl/$name.tar.gz" -C "$GE_ROOT"
    [ -x "$GE_DIR/files/bin/wine" ] || die "extracted archive has no $GE_DIR/files/bin/wine"
fi

G="$GE_DIR/files"
export PATH="$G/bin:$PATH" WINEDLLPATH="$G/lib/wine"
export LD_LIBRARY_PATH="$G/lib:$G/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export WINEDEBUG=-all

# 2. Upstream winetricks
WT="$GE_ROOT/winetricks-${WINETRICKS_COMMIT:0:8}"
if [ ! -x "$WT" ]; then
    say "Fetching winetricks @ ${WINETRICKS_COMMIT:0:8}"
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
    mkdir -p "${icon_png%/*}"
    best=$(magick identify -format '%[fx:w*h] %p\n' "$ico" | sort -nr | head -1 | cut -d' ' -f2)
    magick "$ico[$best]" -resize 256x256 "$icon_png" && icon=rsf-launcher
fi
mkdir -p "$HOME/.local/share/applications"
cat > "$HOME/.local/share/applications/rsf-launcher.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=RSF Launcher
Comment=RallySimFans launcher for Richard Burns Rally
Exec="$INSTALL_DIR/run.sh"
Path=$INSTALL_DIR
Icon=$icon
Terminal=false
Categories=Game;
StartupWMClass=rsf_launcher.exe
EOF

say "Done. Start it from the application menu or with $INSTALL_DIR/run.sh (cleanup: $INSTALL_DIR/kill.sh)"
