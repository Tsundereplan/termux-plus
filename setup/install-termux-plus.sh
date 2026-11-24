#!/data/data/com.termux/files/usr/bin/bash
#
# ============================================================================
#  Termux Plus — post-install setup script
# ----------------------------------------------------------------------------
#  Run this inside the Termux Plus app (or stock Termux) after installation:
#
#      pkg install -y git
#      git clone https://github.com/Tsundereplan/termux-plus.git
#      cd termux-plus
#      bash setup/install-termux-plus.sh
#
#  What it does:
#    1. Essentials bootstrap — installs the daily-driver package kit
#    2. Installs the ttheme / tfont / start-desktop commands
#    3. Installs 12 color schemes + applies the default (Tokyo Night)
#    4. Installs a Nerd Font (MesloLGS NF — recommended for Powerlevel10k)
#    5. Optional: Zsh + Oh-My-Zsh + Powerlevel10k prompt (replaces the ~$)
#    6. Optional: XFCE desktop environment with Termux:X11 support
#
#  Everything is additive: your existing configs are backed up, never trashed.
# ============================================================================

set -u

# --- tweakables -------------------------------------------------------------
TP_REPO_URL="https://github.com/Tsundereplan/termux-plus"
TP_DEFAULT_THEME="tokyo-night"
TP_DEFAULT_FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Meslo.zip"
TP_FONT_PATTERN="MesloLGSNerdFont-Regular.ttf"
TP_ESSENTIALS="git curl wget zip unzip nano openssh termux-api proot-distro zsh"

# --- pretty output ----------------------------------------------------------
if [ -t 1 ]; then
    RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; CYAN=$'\033[36m'; BOLD=$'\033[1m'; RESET=$'\033[0m'
else
    RED=""; GREEN=""; YELLOW=""; CYAN=""; BOLD=""; RESET=""
fi

info()  { printf '%s\n' "${CYAN}[INFO]${RESET} $*"; }
ok()    { printf '%s\n' "${GREEN}[OK]${RESET}   $*"; }
warn() { printf '%s\n' "${YELLOW}[WARN]${RESET} $*"; }
die()   { printf '%s\n' "${RED}[FAIL]${RESET} $*"; exit 1; }

ask() {  # ask "Question" default(y/n)
    local question="$1" default="$2" answer
    if [ "$default" = "y" ]; then
        read -r -p "$question [Y/n] " answer || answer="y"
        answer="${answer:-y}"
    else
        read -r -p "$question [y/N] " answer || answer="n"
        answer="${answer:-n}"
    fi
    case "$answer" in
        [Yy]|[Yy][Ee][Ss]*) return 0 ;;
        *) return 1 ;;
    esac
}

banner() {
    printf '%s' "$CYAN$BOLD"
    cat <<'EOF'
  _____                   __  __                 __  __
 |_   _| __ __ _  ___ ___|  \/  | ___  ___ _ __ |  \/  | __ _ _ __
   | || '__/ _` |/ __/ __| |\/| |/ _ \/ _ \ '_ \| |\/| |/ _` | '_ \
   | || | | (_| | (_| (__| |  | |  __/  __/ | | | |  | | (_| | | | |
   |_||_|  \__,_|\___/\___|_|  |_|\___|\___|_| |_|_|  |_|\__,_|_| |_|
EOF
    printf '%s\n' "$RESET"
    echo "  Post-install setup  •  themes • fonts • prompt • XFCE desktop"
    echo ""
}

# ============================================================================
#  Pre-flight
# ============================================================================
banner

[ -n "${TERMUX_VERSION:-}" ] || die "This script must run inside Termux (Termux Plus), not a regular Linux shell."
[ -d "/data/data/com.termux/files/usr" ] || die "\$PREFIX not found. Are you really in Termux?"

ARCH="$(dpkg --print-architecture 2>/dev/null || echo unknown)"
info "Detected Termux ${TERMUX_VERSION} on ${ARCH}."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THEMES_SRC="$SCRIPT_DIR/themes"
if [ ! -d "$THEMES_SRC" ] || [ -z "$(ls "$THEMES_SRC"/*.properties 2>/dev/null)" ]; then
    warn "The 'themes' folder was not found next to this script."
    info  "Fetching a fresh copy of the Termux Plus repository..."
    git clone --depth 1 "$TP_REPO_URL" "$HOME/termux-plus" || die "Could not clone $TP_REPO_URL"
    SCRIPT_DIR="$HOME/termux-plus/setup"
    THEMES_SRC="$SCRIPT_DIR/themes"
fi

# ============================================================================
#  Step 1 — Essentials bootstrap (the "custom bootstrap" package set)
# ============================================================================
echo ""
info "${BOLD}Step 1/6: Essentials bootstrap${RESET}"
info "Packages: $TP_ESSENTIALS"
if ask "Update packages and install the essentials kit now?" y; then
    pkg update -y || pkg update -y || warn "'pkg update' reported issues — continuing anyway."
    pkg install -y $TP_ESSENTIALS || die "Failed to install essentials. Check your mirrors (termux-change-repo)."
    ok "Essentials installed."
else
    warn "Skipped. You can install them later with: pkg install $TP_ESSENTIALS"
fi

# ============================================================================
#  Step 2 — Install ttheme / tfont / start-desktop commands
# ============================================================================
echo ""
info "${BOLD}Step 2/6: Installing Termux Plus commands${RESET}"
for cmd in ttheme tfont start-desktop; do
    if [ -f "$SCRIPT_DIR/$cmd" ]; then
        install -m 0755 "$SCRIPT_DIR/$cmd" "$PREFIX/bin/$cmd"
        ok "Installed: $cmd"
    else
        warn "Missing $SCRIPT_DIR/$cmd — skipped."
    fi
done

# ============================================================================
#  Step 3 — Color schemes + default theme
# ============================================================================
echo ""
info "${BOLD}Step 3/6: Color schemes${RESET}"
TP_THEMES_DIR="$HOME/.termux/termux-plus/themes"
mkdir -p "$TP_THEMES_DIR"
cp -f "$THEMES_SRC"/*.properties "$TP_THEMES_DIR/"
THEME_COUNT=$(ls -1 "$TP_THEMES_DIR"/*.properties 2>/dev/null | wc -l | tr -d ' ')
ok "Installed ${THEME_COUNT} color schemes into ~/.termux/termux-plus/themes/"

if [ ! -f "$HOME/.termux/colors.properties" ]; then
    ttheme "$TP_DEFAULT_THEME" 2>/dev/null || cp -f "$THEMES_SRC/$TP_DEFAULT_THEME.properties" "$HOME/.termux/colors.properties"
    ok "Default theme applied: $TP_DEFAULT_THEME"
else
    info "You already have a colors.properties — keeping it."
    info "Switch themes anytime with: ttheme <name>   (list: ttheme -l)"
fi

# ============================================================================
#  Step 4 — Nerd Font
# ============================================================================
echo ""
info "${BOLD}Step 4/6: Nerd Font${RESET}"
if [ -f "$HOME/.termux/font.ttf" ]; then
    info "A custom font is already installed (~/.termux/font.ttf) — keeping it."
    info "Switch fonts anytime with: tfont <name>   (list: tfont -l)"
else
    if ask "Download and install MesloLGS Nerd Font (icons + powerline glyphs)?" y; then
        info "Downloading from nerd-fonts releases..."
        rm -rf "${TMPDIR:-/data/data/com.termux/files/usr/tmp}/tp-font" 
        FONT_TMP="${TMPDIR:-/data/data/com.termux/files/usr/tmp}/tp-font"
        mkdir -p "$FONT_TMP"
        if curl -fL --retry 3 -o "$FONT_TMP/font.zip" "$TP_DEFAULT_FONT_URL"; then
            unzip -o -q "$FONT_TMP/font.zip" -d "$FONT_TMP/extracted"
            FONT_FILE="$(cd "$FONT_TMP/extracted" && ls "$TP_FONT_PATTERN" 2>/dev/null | head -n 1)"
            [ -z "$FONT_FILE" ] && FONT_FILE="$(cd "$FONT_TMP/extracted" && ls Meslo*Regular*.ttf 2>/dev/null | head -n 1)"
            [ -z "$FONT_FILE" ] && FONT_FILE="$(cd "$FONT_TMP/extracted" && ls *Regular*.ttf 2>/dev/null | head -n 1)"
            if [ -n "$FONT_FILE" ]; then
                mkdir -p "$HOME/.termux"
                cp -f "$FONT_TMP/extracted/$FONT_FILE" "$HOME/.termux/font.ttf"
                ok "Font installed: $FONT_FILE -> ~/.termux/font.ttf"
            else
                warn "Could not find a .ttf inside the downloaded zip — skipping."
            fi
            rm -rf "$FONT_TMP"
        else
            warn "Font download failed — skipping (no internet?). Try 'tfont meslo' later."
        fi
    else
        warn "Skipped. Run 'tfont meslo' anytime to install it later."
    fi
fi

# ============================================================================
#  Step 5 — Zsh + Oh-My-Zsh + Powerlevel10k (the ~$ prompt upgrade)
# ============================================================================
echo ""
info "${BOLD}Step 5/6: Prompt upgrade (Zsh + Oh-My-Zsh + Powerlevel10k)${RESET}"
if ask "Install Zsh + Oh-My-Zsh + Powerlevel10k? (replaces the plain '~$' prompt)" y; then
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        info "Installing Oh-My-Zsh (unattended)..."
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended --keep-zshrc \
            || die "Oh-My-Zsh install failed. Check your internet connection."
    else
        info "Oh-My-Zsh already present — reusing it."
    fi

    info "Installing Powerlevel10k theme..."
    ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
    mkdir -p "$ZSH_CUSTOM/themes"
    rm -rf "$ZSH_CUSTOM/themes/powerlevel10k"
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$ZSH_CUSTOM/themes/powerlevel10k" \
        || die "Failed to clone powerlevel10k."

    ZSHRC="$HOME/.zshrc"
    if [ -f "$ZSHRC" ]; then
        cp -f "$ZSHRC" "$ZSHRC.termux-plus-backup"
        info "Backup saved: ~/.zshrc.termux-plus-backup"
        if grep -q '^ZSH_THEME=' "$ZSHRC"; then
            sed -i 's#^ZSH_THEME=.*#ZSH_THEME="powerlevel10k/powerlevel10k"#' "$ZSHRC"
        else
            printf '\nZSH_THEME="powerlevel10k/powerlevel10k"\n' >> "$ZSHRC"
        fi
    else
        cat > "$ZSHRC" <<'EOF'
# --- Termux Plus zsh config -----------------------------------------------
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"
plugins=(git)
source "$ZSH/oh-my-zsh.sh"

# Termux Plus styling commands:
#   ttheme            list & switch terminal color schemes
#   tfont             list & switch Nerd Fonts
#   start-desktop     launch the XFCE desktop via Termux:X11
# Run 'p10k configure' anytime to re-customize the prompt.
EOF
    fi
    ok "Powerlevel10k configured in ~/.zshrc"

    if command -v chsh >/dev/null 2>&1; then
        if ask "Make Zsh the default shell (chsh -s zsh)?" y; then
            chsh -s zsh && ok "Default shell set to zsh."
        fi
    fi
    info "TIP: the first time you open zsh, the Powerlevel10k wizard will ask"
    info "     a few questions and build your dream prompt. Re-run it anytime"
    info "     with: p10k configure"
else
    warn "Skipped prompt upgrade."
fi

# ============================================================================
#  Step 6 — XFCE desktop via Termux:X11
# ============================================================================
echo ""
info "${BOLD}Step 6/6: XFCE desktop (Termux:X11)${RESET}"
if ask "Install the XFCE desktop environment + Termux:X11 support?" y; then
    info "Enabling the x11 repository (pkg install x11-repo)..."
    pkg install -y x11-repo || warn "x11-repo install reported issues."
    pkg update -y || true

    info "Installing XFCE4 (this downloads a few hundred MB, be patient)..."
    if pkg install -y xfce4; then
        ok "XFCE4 installed."
    else
        warn "XFCE4 install failed — you can retry later with: pkg install xfce4"
    fi

    info "Installing the termux-x11 launcher package..."
    if pkg install -y termux-x11-nightly; then
        ok "termux-x11-nightly installed."
    else
        warn "termux-x11-nightly not found in your mirrors."
        warn "Check https://github.com/termux/termux-x11 for current install docs."
    fi

    # The companion display app must be installed as a normal Android APK.
    if [ -x /system/bin/pm ] && /system/bin/pm list packages 2>/dev/null | grep -q 'com.termux.x11'; then
        ok "Termux:X11 companion app detected."
    else
        echo ""
        warn "The Termux:X11 companion ANDROID APP is not installed yet."
        info "  Option A — F-Droid:  https://f-droid.org/en/packages/com.termux.x11/"
        info "  Option B — GitHub:    https://github.com/termux/termux-x11/releases"
        if command -v termux-open-url >/dev/null 2>&1; then
            if ask "Open the releases page in your browser now?" y; then
                termux-open-url "https://github.com/termux/termux-x11/releases" || true
            fi
        fi
    fi

    echo ""
    info "Launching the desktop later is one command:"
    info "    ${BOLD}start-desktop${RESET}   (starts XFCE through Termux:X11)"
    info "TIP: audio inside the desktop needs PulseAudio:"
    info "     pkg install pulseaudio && pulseaudio --start --exit-idle-time=-1"
else
    warn "Skipped desktop install. 'start-desktop' is installed but XFCE is missing."
fi

# ============================================================================
#  Finish
# ============================================================================
echo ""
termux-reload-settings 2>/dev/null || true

printf '%s' "$GREEN$BOLD"
cat <<'EOF'
============================================================================
 Termux Plus setup complete!
============================================================================
EOF
printf '%s' "$RESET"
echo ""
echo " Here's your new toolbox:"
echo "   ${BOLD}ttheme${RESET}            interactive color scheme picker (with live swatches)"
echo "   ${BOLD}ttheme <name>${RESET}      apply a scheme instantly   (ttheme -l to list)"
echo "   ${BOLD}tfont${RESET}              switch Nerd Fonts           (tfont -l to list)"
echo "   ${BOLD}start-desktop${RESET}      boot the XFCE desktop via Termux:X11"
echo "   ${BOLD}p10k configure${RESET}     re-run the prompt wizard (in zsh)"
echo ""
echo " Settings -> Termux -> 'Termux Plus' also has the color scheme picker."
echo ""
echo " Restart the app for everything to take effect. Enjoy! "
