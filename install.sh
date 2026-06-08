#!/usr/bin/env bash
# TrustTunnel + WebUI — one-command installer
# Usage: bash <(curl -Ls https://raw.githubusercontent.com/iamnovye/trusttunnel-webui/main/install.sh)

set -euo pipefail

# ─────────────────────────────────────────────
#  Colours
# ─────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'

info()    { echo -e "${CYAN}${BOLD}[·]${NC} $*"; }
success() { echo -e "${GREEN}${BOLD}[✓]${NC} $*"; }
warn()    { echo -e "${YELLOW}${BOLD}[!]${NC} $*"; }
die()     { echo -e "${RED}${BOLD}[✗]${NC} $*" >&2; exit 1; }
ask()     { echo -e "${BOLD}${CYAN}[?]${NC} $*"; }
sep()     { echo -e "${DIM}──────────────────────────────────────────${NC}"; }

# ─────────────────────────────────────────────
#  Defaults / globals
# ─────────────────────────────────────────────
TT_INSTALL_DIR="/opt/trusttunnel"
WEBUI_DIR="/opt/trusttunnel-webui"
WEBUI_REPO="https://github.com/iamnovye/trusttunnel-webui"
TT_GITHUB="https://github.com/TrustTunnel/TrustTunnel"

ARCH=""
TT_VERSION=""
TT_TARBALL_URL=""

PANEL_DOMAIN="_"
PANEL_ADMIN_USER="admin"
PANEL_ADMIN_PASS=""
PANEL_SECRET_KEY=""
SERVER_ADDRESS=""
PANEL_PATH=""
USE_HTTPS="false"
CREDS_FILE=""

# ─────────────────────────────────────────────
#  Preflight checks
# ─────────────────────────────────────────────
check_root() {
    [[ $EUID -eq 0 ]] || die "Run as root: sudo bash <(curl -Ls ...)"
}

check_os() {
    if [[ ! -f /etc/os-release ]]; then
        die "Cannot detect OS. Tested on Ubuntu 20.04+, Debian 11+."
    fi
    . /etc/os-release
    if [[ "$ID" != "ubuntu" && "$ID" != "debian" ]]; then
        warn "OS '$ID' is not officially tested. Continuing anyway..."
    fi
}

detect_arch() {
    local machine
    machine=$(uname -m)
    case $machine in
        x86_64|amd64) ARCH="x86_64" ;;
        aarch64|arm64) ARCH="aarch64" ;;
        *) die "Unsupported architecture: $machine (only x86_64 and aarch64 are supported)" ;;
    esac
    info "Architecture: $ARCH"
}

# ─────────────────────────────────────────────
#  Dependencies
# ─────────────────────────────────────────────
install_deps() {
    info "Updating package lists..."
    apt-get update -qq

    local pkgs=()
    command -v curl   &>/dev/null || pkgs+=(curl)
    command -v wget   &>/dev/null || pkgs+=(wget)
    command -v tar    &>/dev/null || pkgs+=(tar)
    command -v jq     &>/dev/null || pkgs+=(jq)
    command -v git    &>/dev/null || pkgs+=(git)
    command -v gettext &>/dev/null || pkgs+=(gettext-base)

    if ! command -v docker &>/dev/null; then
        info "Installing Docker..."
        curl -fsSL https://get.docker.com | sh
        systemctl enable --now docker
        success "Docker installed"
    else
        success "Docker already installed"
    fi

    if [[ ${#pkgs[@]} -gt 0 ]]; then
        info "Installing: ${pkgs[*]}"
        apt-get install -y -qq "${pkgs[@]}"
    fi

    success "Dependencies OK"
}

# ─────────────────────────────────────────────
#  TrustTunnel download
# ─────────────────────────────────────────────
fetch_latest_version() {
    info "Fetching latest TrustTunnel release..."
    TT_VERSION=$(curl -fsSL "https://api.github.com/repos/TrustTunnel/TrustTunnel/releases/latest" \
        | grep '"tag_name"' | head -1 | sed 's/.*"tag_name": *"\(.*\)".*/\1/') || true

    if [[ -z "$TT_VERSION" ]]; then
        TT_VERSION="v1.0.33"
        warn "Could not fetch latest version, using fallback $TT_VERSION"
    fi

    TT_TARBALL_URL="${TT_GITHUB}/releases/download/${TT_VERSION}/trusttunnel-${TT_VERSION}-linux-${ARCH}.tar.gz"
    info "TrustTunnel version: ${BOLD}$TT_VERSION${NC}"
}

download_trusttunnel() {
    if [[ -f "$TT_INSTALL_DIR/trusttunnel_endpoint" ]]; then
        local current_ver=""
        current_ver=$("$TT_INSTALL_DIR/trusttunnel_endpoint" --version 2>/dev/null || echo "unknown")
        warn "TrustTunnel already installed ($current_ver) at $TT_INSTALL_DIR"
        ask "Reinstall/upgrade? [y/N]"
        read -r reinstall
        [[ "$reinstall" =~ ^[Yy]$ ]] || return 0
    fi

    mkdir -p "$TT_INSTALL_DIR"
    info "Downloading TrustTunnel $TT_VERSION..."
    local tmpdir
    tmpdir=$(mktemp -d)
    trap "rm -rf $tmpdir" RETURN

    curl -fsSL --progress-bar "$TT_TARBALL_URL" -o "$tmpdir/trusttunnel.tar.gz" \
        || die "Download failed: $TT_TARBALL_URL"

    info "Extracting..."
    tar -xzf "$tmpdir/trusttunnel.tar.gz" -C "$tmpdir"

    local extract_dir
    extract_dir=$(find "$tmpdir" -mindepth 1 -maxdepth 1 -type d | head -1)
    [[ -z "$extract_dir" ]] && extract_dir="$tmpdir"

    cp -r "$extract_dir"/. "$TT_INSTALL_DIR/"
    chmod +x "$TT_INSTALL_DIR"/trusttunnel_endpoint 2>/dev/null || true
    chmod +x "$TT_INSTALL_DIR"/setup_wizard 2>/dev/null || true

    success "TrustTunnel extracted to $TT_INSTALL_DIR"
}

# ─────────────────────────────────────────────
#  TrustTunnel setup wizard
# ─────────────────────────────────────────────
run_setup_wizard() {
    if [[ -f "$TT_INSTALL_DIR/vpn.toml" ]]; then
        warn "TrustTunnel config already exists (vpn.toml found)"
        ask "Re-run setup wizard? [y/N]"
        read -r redo
        [[ "$redo" =~ ^[Yy]$ ]] || return 0
    fi

    echo ""
    sep
    echo -e "${BOLD}  TrustTunnel Setup Wizard${NC}"
    sep
    echo -e "${DIM}  The wizard will ask about listen address, certificates,"
    echo -e "  credentials file and connection rules.${NC}"
    echo ""

    cd "$TT_INSTALL_DIR"
    ./setup_wizard || die "setup_wizard failed"
    success "TrustTunnel configured"
}

# ─────────────────────────────────────────────
#  Systemd service
# ─────────────────────────────────────────────
install_tt_service() {
    if [[ ! -f "$TT_INSTALL_DIR/trusttunnel.service.template" ]]; then
        warn "trusttunnel.service.template not found — skipping systemd setup"
        return 0
    fi

    cp "$TT_INSTALL_DIR/trusttunnel.service.template" \
       /etc/systemd/system/trusttunnel.service

    systemctl daemon-reload
    systemctl enable --now trusttunnel
    success "TrustTunnel service started (systemctl status trusttunnel)"
}

# ─────────────────────────────────────────────
#  Detect credentials path from vpn.toml
# ─────────────────────────────────────────────
detect_config_paths() {
    CREDS_FILE="$TT_INSTALL_DIR/credentials"
    local vpn_toml="$TT_INSTALL_DIR/vpn.toml"
    [[ ! -f "$vpn_toml" ]] && return 0

    local creds
    creds=$(grep -E '^\s*credentials\s*=' "$vpn_toml" 2>/dev/null \
        | head -1 | sed 's/.*=\s*"\(.*\)".*/\1/' || echo "")
    if [[ -n "$creds" && -f "$creds" ]]; then
        CREDS_FILE="$creds"
        info "Detected credentials file: $CREDS_FILE"
    fi
}

# ─────────────────────────────────────────────
#  Collect WebUI config
# ─────────────────────────────────────────────
collect_webui_config() {
    echo ""
    sep
    echo -e "${BOLD}  Web Panel Configuration${NC}"
    sep
    echo ""

    # ── Server address ──
    local default_ip
    default_ip=$(curl -fsSL --max-time 5 https://api.ipify.org 2>/dev/null \
        || hostname -I | awk '{print $1}')

    ask "Server public IP or domain (used for tt:// links) [${default_ip}]:"
    read -r input
    SERVER_ADDRESS="${input:-$default_ip}"

    # ── Domain ──
    echo ""
    ask "Domain for the web panel (e.g. media.example.com). Leave empty to use IP:"
    read -r input
    if [[ -n "$input" ]]; then
        PANEL_DOMAIN="$input"
    else
        PANEL_DOMAIN="$SERVER_ADDRESS"
    fi

    # ── HTTPS ──
    echo ""
    if [[ "$PANEL_DOMAIN" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || [[ "$PANEL_DOMAIN" == "_" ]]; then
        warn "HTTPS requires a real domain — skipping (using HTTP)"
        USE_HTTPS="false"
    else
        ask "Enable HTTPS with Let's Encrypt for ${PANEL_DOMAIN}? [Y/n]:"
        read -r input
        if [[ ! "$input" =~ ^[Nn]$ ]]; then
            USE_HTTPS="true"
        fi
    fi

    # ── Secret panel path ──
    echo ""
    echo -e "  ${BOLD}Camouflage / decoy setup${NC}"
    echo -e "  ${DIM}Your domain will show a fake video streaming site (StreamVault)."
    echo -e "  The real admin panel is only accessible at a secret path.${NC}"
    echo ""

    local default_path
    default_path=$(openssl rand -hex 6 2>/dev/null || cat /dev/urandom | tr -dc 'a-z0-9' | head -c 12)

    ask "Secret panel path (the part after your domain) [${default_path}]:"
    echo -e "  ${DIM}Panel URL will be: http(s)://${PANEL_DOMAIN}/${default_path}/${NC}"
    read -r input
    PANEL_PATH="${input:-$default_path}"
    # Strip leading/trailing slashes
    PANEL_PATH="${PANEL_PATH#/}"
    PANEL_PATH="${PANEL_PATH%/}"
    [[ -z "$PANEL_PATH" ]] && PANEL_PATH="$default_path"

    # ── Admin credentials ──
    echo ""
    ask "Admin username for web panel [admin]:"
    read -r input
    PANEL_ADMIN_USER="${input:-admin}"

    while true; do
        ask "Admin password for web panel (min 8 chars):"
        read -rs PANEL_ADMIN_PASS
        echo ""
        [[ ${#PANEL_ADMIN_PASS} -ge 8 ]] && break
        warn "Password must be at least 8 characters"
    done

    # ── Secret key ──
    PANEL_SECRET_KEY=$(openssl rand -hex 32 2>/dev/null || \
        tr -dc 'a-f0-9' < /dev/urandom | head -c 64)

    echo ""
    success "Configuration collected"
}

# ─────────────────────────────────────────────
#  Deploy WebUI
# ─────────────────────────────────────────────
deploy_webui() {
    info "Deploying TrustTunnel WebUI..."

    if [[ -d "$WEBUI_DIR/.git" ]]; then
        info "Updating existing WebUI installation..."
        git -C "$WEBUI_DIR" pull --ff-only origin main 2>/dev/null || true
    else
        info "Cloning WebUI repository..."
        git clone --depth=1 "$WEBUI_REPO" "$WEBUI_DIR" \
            || die "Failed to clone WebUI repository"
    fi

    # ── Write .env ──
    cat > "$WEBUI_DIR/.env" <<EOF
ADMIN_USER=${PANEL_ADMIN_USER}
ADMIN_PASS=${PANEL_ADMIN_PASS}
SECRET_KEY=${PANEL_SECRET_KEY}
SERVER_ADDRESS=${SERVER_ADDRESS}
TRUSTTUNNEL_DIR=${TT_INSTALL_DIR}
PANEL_PATH=${PANEL_PATH}
DOMAIN=${PANEL_DOMAIN}
USE_HTTPS=${USE_HTTPS}
EOF
    success ".env written"

    # ── HTTPS: obtain certificate before containers start ──
    if [[ "$USE_HTTPS" == "true" ]]; then
        setup_https
        # Uncomment letsencrypt volume in compose
        sed -i 's|# - /etc/letsencrypt|- /etc/letsencrypt|g' "$WEBUI_DIR/docker-compose.yml"
    fi

    # ── Start containers ──
    info "Building and starting containers..."
    cd "$WEBUI_DIR"
    docker compose pull --quiet 2>/dev/null || true
    docker compose up -d --build

    success "WebUI is running"
}

setup_https() {
    info "Obtaining Let's Encrypt certificate for ${PANEL_DOMAIN}..."

    if ! command -v certbot &>/dev/null; then
        apt-get install -y -qq certbot
    fi

    certbot certonly --standalone \
        --non-interactive \
        --agree-tos \
        --register-unsafely-without-email \
        -d "$PANEL_DOMAIN" \
        || die "certbot failed — check that port 80 is open and DNS points to this server"

    # Auto-renewal cron
    (crontab -l 2>/dev/null; \
     echo "0 3 * * * certbot renew --quiet && docker compose -f $WEBUI_DIR/docker-compose.yml restart frontend") \
        | sort -u | crontab -

    success "Certificate obtained for $PANEL_DOMAIN"
}

# ─────────────────────────────────────────────
#  Summary
# ─────────────────────────────────────────────
print_summary() {
    local proto="http"
    [[ "$USE_HTTPS" == "true" ]] && proto="https"

    local base_url="${proto}://${PANEL_DOMAIN}"
    local panel_url="${base_url}/${PANEL_PATH}/"

    echo ""
    echo -e "${GREEN}${BOLD}"
    echo "  ╔══════════════════════════════════════════════════════╗"
    echo "  ║          Installation complete!                      ║"
    echo "  ╚══════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    sep
    echo -e "  ${BOLD}TrustTunnel endpoint:${NC}"
    echo -e "    Dir     : ${CYAN}$TT_INSTALL_DIR${NC}"
    echo -e "    Service : ${CYAN}systemctl status trusttunnel${NC}"
    echo ""
    echo -e "  ${BOLD}Camouflage site (visible to everyone):${NC}"
    echo -e "    URL     : ${CYAN}${base_url}/${NC}"
    echo -e "    Shows   : StreamVault — fake video streaming site"
    echo ""
    echo -e "  ${BOLD}Admin panel (secret):${NC}"
    echo -e "    URL     : ${GREEN}${BOLD}${panel_url}${NC}"
    echo -e "    Login   : ${CYAN}${PANEL_ADMIN_USER}${NC}"
    echo -e "    Password: ${CYAN}${PANEL_ADMIN_PASS}${NC}"
    echo ""
    echo -e "  ${BOLD}Useful commands:${NC}"
    echo -e "    ${DIM}# View logs${NC}"
    echo -e "    docker compose -f $WEBUI_DIR/docker-compose.yml logs -f"
    echo -e "    ${DIM}# Restart${NC}"
    echo -e "    docker compose -f $WEBUI_DIR/docker-compose.yml restart"
    echo -e "    ${DIM}# TrustTunnel service${NC}"
    echo -e "    systemctl status trusttunnel"
    sep
    echo ""
    echo -e "  ${YELLOW}${BOLD}Keep the panel URL secret — share only the tt:// connection links with users.${NC}"
    echo ""
}

# ─────────────────────────────────────────────
#  Main
# ─────────────────────────────────────────────
main() {
    clear
    echo ""
    echo -e "${CYAN}${BOLD}"
    echo "  ████████╗██████╗ ██╗   ██╗███████╗████████╗"
    echo "     ██╔══╝██╔══██╗██║   ██║██╔════╝╚══██╔══╝"
    echo "     ██║   ██████╔╝██║   ██║███████╗   ██║   "
    echo "     ██║   ██╔══██╗██║   ██║╚════██║   ██║   "
    echo "     ██║   ██║  ██║╚██████╔╝███████║   ██║   "
    echo "     ╚═╝   ╚═╝  ╚═╝ ╚═════╝ ╚══════╝   ╚═╝  "
    echo -e "${NC}"
    echo -e "  ${BOLD}TrustTunnel + WebUI Installer${NC}"
    echo -e "  ${DIM}github.com/iamnovye/trusttunnel-webui${NC}"
    echo ""
    sep
    echo ""

    check_root
    check_os
    detect_arch

    echo ""
    info "This script will:"
    echo "   1. Install Docker and dependencies"
    echo "   2. Download TrustTunnel (latest release)"
    echo "   3. Run the TrustTunnel setup wizard (interactive)"
    echo "   4. Install TrustTunnel as a systemd service"
    echo "   5. Deploy the web admin panel behind a camouflage site"
    echo ""
    ask "Continue? [Y/n]"
    read -r go
    [[ "$go" =~ ^[Nn]$ ]] && exit 0

    sep

    install_deps
    fetch_latest_version
    download_trusttunnel

    sep
    echo ""
    echo -e "  ${BOLD}Step 1/2 — TrustTunnel Setup${NC}"
    echo ""
    run_setup_wizard
    detect_config_paths
    install_tt_service

    sep
    echo ""
    echo -e "  ${BOLD}Step 2/2 — Web Panel + Camouflage Setup${NC}"
    echo ""
    collect_webui_config
    deploy_webui

    print_summary
}

main "$@"
