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

PANEL_DOMAIN=""
PANEL_ADMIN_USER="admin"
PANEL_ADMIN_PASS=""
PANEL_SECRET_KEY=""
SERVER_ADDRESS=""
PANEL_PORT="8080"
USE_HTTPS="n"

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
    command -v curl  &>/dev/null || pkgs+=(curl)
    command -v wget  &>/dev/null || pkgs+=(wget)
    command -v tar   &>/dev/null || pkgs+=(tar)
    command -v jq    &>/dev/null || pkgs+=(jq)
    command -v git   &>/dev/null || pkgs+=(git)

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
        | grep '"tag_name"' | head -1 | sed 's/.*"tag_name": *"\(.*\)".*/\1/')

    if [[ -z "$TT_VERSION" ]]; then
        # Fallback if GitHub API rate-limited
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

    # Find the extracted dir (may vary between releases)
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
    # Run the upstream interactive setup wizard
    ./setup_wizard || die "setup_wizard failed"
    success "TrustTunnel configured"
}

# ─────────────────────────────────────────────
#  Systemd service for TrustTunnel endpoint
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
#  Detect config file paths from vpn.toml
# ─────────────────────────────────────────────
detect_config_paths() {
    local vpn_toml="$TT_INSTALL_DIR/vpn.toml"
    if [[ ! -f "$vpn_toml" ]]; then
        warn "vpn.toml not found — using default config paths"
        return 0
    fi

    # Extract credentials path if present
    local creds
    creds=$(grep -E '^\s*credentials\s*=' "$vpn_toml" 2>/dev/null \
        | head -1 | sed 's/.*=\s*"\(.*\)".*/\1/' || echo "")
    if [[ -n "$creds" && -f "$creds" ]]; then
        info "Detected credentials file: $creds"
        CREDS_FILE="$creds"
    else
        CREDS_FILE="$TT_INSTALL_DIR/credentials"
    fi
}

CREDS_FILE="$TT_INSTALL_DIR/credentials"

# ─────────────────────────────────────────────
#  Collect WebUI config from user
# ─────────────────────────────────────────────
collect_webui_config() {
    echo ""
    sep
    echo -e "${BOLD}  TrustTunnel WebUI Configuration${NC}"
    sep
    echo ""

    # Server address
    local default_ip
    default_ip=$(curl -fsSL --max-time 5 https://api.ipify.org 2>/dev/null || hostname -I | awk '{print $1}')

    ask "Server public IP or domain (used for tt:// links) [${default_ip}]:"
    read -r input
    SERVER_ADDRESS="${input:-$default_ip}"

    # Panel port
    ask "Web panel HTTP port [8080]:"
    read -r input
    PANEL_PORT="${input:-8080}"

    # Admin credentials
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

    # HTTPS
    ask "Enable HTTPS with Let's Encrypt? Requires a real domain pointing to this server. [y/N]:"
    read -r input
    USE_HTTPS="${input:-n}"

    if [[ "$USE_HTTPS" =~ ^[Yy]$ ]]; then
        ask "Domain name for the web panel (e.g. panel.example.com):"
        read -r PANEL_DOMAIN
        [[ -z "$PANEL_DOMAIN" ]] && die "Domain cannot be empty when HTTPS is enabled"
    fi

    # Generate secret key
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

    # Write .env
    cat > "$WEBUI_DIR/.env" <<EOF
ADMIN_USER=${PANEL_ADMIN_USER}
ADMIN_PASS=${PANEL_ADMIN_PASS}
SECRET_KEY=${PANEL_SECRET_KEY}
SERVER_ADDRESS=${SERVER_ADDRESS}
TRUSTTUNNEL_DIR=${TT_INSTALL_DIR}
EOF

    success ".env written"

    # Patch nginx to use correct port (if custom)
    local nginx_conf="$WEBUI_DIR/nginx/nginx.conf"
    if [[ "$PANEL_PORT" != "80" ]]; then
        sed -i "s/listen 80;/listen ${PANEL_PORT};/" "$nginx_conf"
    fi

    # HTTPS setup
    if [[ "$USE_HTTPS" =~ ^[Yy]$ ]]; then
        setup_https
    fi

    # Patch docker-compose ports
    sed -i "s/\"80:80\"/\"${PANEL_PORT}:${PANEL_PORT}\"/" "$WEBUI_DIR/docker-compose.yml"

    # Build and start
    info "Starting containers..."
    cd "$WEBUI_DIR"
    docker compose pull --quiet 2>/dev/null || true
    docker compose up -d --build

    success "WebUI is running"
}

setup_https() {
    info "Setting up Let's Encrypt for ${PANEL_DOMAIN}..."

    if ! command -v certbot &>/dev/null; then
        apt-get install -y -qq certbot
    fi

    # Temporary plain HTTP on port 80 for ACME challenge
    # (if main panel is on different port, port 80 should be free)
    certbot certonly --standalone \
        --non-interactive \
        --agree-tos \
        --register-unsafely-without-email \
        -d "$PANEL_DOMAIN" \
        || die "certbot failed — make sure port 80 is open and DNS points to this server"

    # Patch nginx.conf to enable HTTPS
    local nginx_conf="$WEBUI_DIR/nginx/nginx.conf"
    # Replace server block with full HTTPS config
    cat > "$nginx_conf" <<NGINXEOF
server {
    listen 80;
    server_name ${PANEL_DOMAIN};
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name ${PANEL_DOMAIN};

    ssl_certificate     /etc/letsencrypt/live/${PANEL_DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${PANEL_DOMAIN}/privkey.pem;
    ssl_protocols       TLSv1.2 TLSv1.3;
    ssl_ciphers         HIGH:!aNULL:!MD5;

    root /usr/share/nginx/html;
    index index.html;

    location /api/ {
        proxy_pass http://backend:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 30s;
    }

    location / {
        try_files \$uri \$uri/ /index.html;
    }
}
NGINXEOF

    # Mount letsencrypt in docker-compose
    sed -i '/# - \/etc\/letsencrypt/s/# //' "$WEBUI_DIR/docker-compose.yml"

    # Patch ports in compose for 80+443
    sed -i 's/"443:443"/"443:443"/' "$WEBUI_DIR/docker-compose.yml" # already there
    # Ensure port 80 is also exposed (redirect)
    # The compose already has 80 and 443 exposed by default

    # Cron for renewal
    (crontab -l 2>/dev/null; echo "0 3 * * * certbot renew --quiet && docker compose -f $WEBUI_DIR/docker-compose.yml restart frontend") \
        | crontab -

    success "HTTPS configured for $PANEL_DOMAIN"
}

# ─────────────────────────────────────────────
#  Summary
# ─────────────────────────────────────────────
print_summary() {
    local url
    if [[ "$USE_HTTPS" =~ ^[Yy]$ ]]; then
        url="https://${PANEL_DOMAIN}"
    else
        local ip="${SERVER_ADDRESS}"
        if [[ "$PANEL_PORT" == "80" ]]; then
            url="http://${ip}"
        else
            url="http://${ip}:${PANEL_PORT}"
        fi
    fi

    echo ""
    echo -e "${GREEN}${BOLD}"
    echo "  ╔══════════════════════════════════════════╗"
    echo "  ║       Installation complete! 🎉          ║"
    echo "  ╚══════════════════════════════════════════╝"
    echo -e "${NC}"
    sep
    echo -e "  ${BOLD}TrustTunnel endpoint:${NC}"
    echo -e "    Directory : ${CYAN}$TT_INSTALL_DIR${NC}"
    echo -e "    Service   : ${CYAN}systemctl status trusttunnel${NC}"
    echo ""
    echo -e "  ${BOLD}Web Panel:${NC}"
    echo -e "    URL       : ${CYAN}${url}${NC}"
    echo -e "    Login     : ${CYAN}${PANEL_ADMIN_USER}${NC}"
    echo -e "    Password  : ${CYAN}${PANEL_ADMIN_PASS}${NC}"
    echo ""
    echo -e "  ${BOLD}Useful commands:${NC}"
    echo -e "    ${DIM}# View logs${NC}"
    echo -e "    docker compose -f $WEBUI_DIR/docker-compose.yml logs -f"
    echo -e "    ${DIM}# Restart panel${NC}"
    echo -e "    docker compose -f $WEBUI_DIR/docker-compose.yml restart"
    echo -e "    ${DIM}# TrustTunnel service${NC}"
    echo -e "    systemctl status trusttunnel"
    sep
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
    echo "   3. Run the TrustTunnel setup wizard"
    echo "   4. Install TrustTunnel as a systemd service"
    echo "   5. Deploy the web admin panel"
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
    echo -e "  ${BOLD}Step 2/2 — Web Panel Setup${NC}"
    echo ""
    collect_webui_config
    deploy_webui

    print_summary
}

main "$@"
