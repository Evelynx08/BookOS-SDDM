#!/usr/bin/env bash
# BookOS SDDM theme installer
# Usage: ./install.sh [--uninstall]
set -euo pipefail

THEME_NAME="bookos"
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/theme-sddm/${THEME_NAME}"
DEST_DIR="/usr/share/sddm/themes/${THEME_NAME}"
CONF_FILE="/etc/sddm.conf.d/bookos-theme.conf"

C_RESET='\033[0m'; C_BOLD='\033[1m'; C_OK='\033[32m'; C_ERR='\033[31m'; C_WARN='\033[33m'; C_INFO='\033[36m'

ok()   { echo -e "${C_OK}✓${C_RESET} $*"; }
err()  { echo -e "${C_ERR}✗${C_RESET} $*" >&2; }
info() { echo -e "${C_INFO}→${C_RESET} $*"; }
warn() { echo -e "${C_WARN}!${C_RESET} $*"; }

need_root() {
    if [[ $EUID -ne 0 ]]; then
        info "Re-running with sudo..."
        exec sudo -E bash "$0" "$@"
    fi
}

detect_pm() {
    if   command -v pacman  >/dev/null 2>&1; then echo "pacman"
    elif command -v dnf     >/dev/null 2>&1; then echo "dnf"
    elif command -v dnf5    >/dev/null 2>&1; then echo "dnf5"
    elif command -v zypper  >/dev/null 2>&1; then echo "zypper"
    elif command -v apt     >/dev/null 2>&1; then echo "apt"
    elif command -v xbps-install >/dev/null 2>&1; then echo "xbps"
    elif command -v emerge  >/dev/null 2>&1; then echo "emerge"
    else echo "unknown"; fi
}

install_sddm_pkg() {
    local pm; pm="$(detect_pm)"
    info "Installing SDDM via $pm..."
    case "$pm" in
        pacman) pacman -S --needed --noconfirm sddm ;;
        dnf|dnf5) "$pm" install -y sddm ;;
        zypper) zypper --non-interactive install sddm ;;
        apt)    apt-get update && apt-get install -y sddm ;;
        xbps)   xbps-install -Sy sddm ;;
        emerge) emerge --ask=n x11-misc/sddm ;;
        *) err "Unknown package manager. Install sddm manually."; exit 1 ;;
    esac
    ok "SDDM package installed"
}

enable_sddm_service() {
    if command -v systemctl >/dev/null 2>&1; then
        # Disable other DMs first (gdm, lightdm, lxdm) — safe no-op if absent
        for dm in gdm lightdm lxdm gdm3; do
            if systemctl is-enabled "$dm" >/dev/null 2>&1; then
                warn "Disabling $dm.service"
                systemctl disable "$dm" || true
            fi
        done
        info "Enabling sddm.service..."
        systemctl enable sddm.service || warn "Could not enable sddm.service"
        ok "sddm.service enabled (active on next boot)"
    fi
}

check_deps() {
    local need_install=0
    if ! command -v sddm >/dev/null 2>&1 || ! command -v sddm-greeter >/dev/null 2>&1; then
        warn "SDDM not found — installing..."
        need_install=1
    fi
    if (( need_install )); then
        install_sddm_pkg
        enable_sddm_service
    else
        ok "SDDM already installed"
        # Make sure service is enabled anyway
        if command -v systemctl >/dev/null 2>&1 && ! systemctl is-enabled sddm.service >/dev/null 2>&1; then
            enable_sddm_service
        fi
    fi
}

uninstall() {
    need_root "$@"
    info "Removing theme..."
    if [[ -d "$DEST_DIR" ]]; then
        rm -rf "$DEST_DIR"
        ok "Removed $DEST_DIR"
    else
        warn "Theme not installed at $DEST_DIR"
    fi
    if [[ -f "$CONF_FILE" ]]; then
        rm -f "$CONF_FILE"
        ok "Removed $CONF_FILE"
    fi
    echo
    ok "Uninstalled. SDDM will fall back to default theme."
    exit 0
}

install_theme() {
    need_root "$@"
    check_deps

    if [[ ! -d "$SRC_DIR" ]]; then
        err "Source theme not found: $SRC_DIR"
        exit 1
    fi
    if [[ ! -f "$SRC_DIR/Main.qml" ]]; then
        err "Main.qml missing in $SRC_DIR"
        exit 1
    fi

    # Backup existing
    if [[ -d "$DEST_DIR" ]]; then
        local backup="${DEST_DIR}.bak.$(date +%Y%m%d-%H%M%S)"
        warn "Existing theme found, backing up to $backup"
        mv "$DEST_DIR" "$backup"
    fi

    info "Copying theme to $DEST_DIR..."
    mkdir -p "$DEST_DIR"
    cp -r "$SRC_DIR"/. "$DEST_DIR/"
    chown -R root:root "$DEST_DIR"
    chmod -R a+rX "$DEST_DIR"
    ok "Theme files installed"

    # Activate via /etc/sddm.conf.d (no overwrite of /etc/sddm.conf)
    info "Activating theme..."
    mkdir -p /etc/sddm.conf.d
    cat > "$CONF_FILE" <<EOF
[Theme]
Current=${THEME_NAME}
EOF
    ok "Wrote $CONF_FILE"

    # Try test mode to validate
    info "Validating with sddm-greeter --test-mode (5s)..."
    if timeout 5 sddm-greeter --test-mode --theme "$DEST_DIR" >/dev/null 2>&1 &
    then
        local pid=$!
        sleep 5
        kill $pid 2>/dev/null || true
        ok "Theme loads without crashing"
    fi

    echo
    ok "${C_BOLD}BookOS SDDM theme installed${C_RESET}"
    echo
    echo "Next steps:"
    echo "  • Preview now:   sddm-greeter --test-mode --theme $DEST_DIR"
    echo "  • Apply on next boot:  reboot"
    echo "  • Configure from:  BookOS Settings → Pantalla de bloqueo"
    echo "  • Uninstall:  sudo $0 --uninstall"
}

# Main
case "${1:-}" in
    --uninstall|-u|remove) uninstall "$@" ;;
    --help|-h)
        cat <<EOF
BookOS SDDM theme installer

Usage:
  $0              Install theme and activate
  $0 --uninstall  Remove theme and config
  $0 --help       Show this help
EOF
        ;;
    *) install_theme "$@" ;;
esac
