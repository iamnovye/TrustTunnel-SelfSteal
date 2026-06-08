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
#  i18n — все строки интерфейса
# ─────────────────────────────────────────────
LANG_CHOICE="en"   # set by choose_language()

t() {
    local key="$1"
    if [[ "$LANG_CHOICE" == "ru" ]]; then
        case "$key" in
            lang_select)        echo "Выберите язык / Choose language:" ;;
            lang_en)            echo "  1) English" ;;
            lang_ru)            echo "  2) Русский" ;;
            lang_prompt)        echo "Введите 1 или 2 [1]: " ;;

            intro_title)        echo "  TrustTunnel + WebUI — Установщик" ;;
            intro_sub)          echo "  github.com/iamnovye/trusttunnel-webui" ;;
            intro_will)         echo "Этот скрипт выполнит:" ;;
            intro_1)            echo "   1. Установит Docker и зависимости" ;;
            intro_2)            echo "   2. Загрузит TrustTunnel (последний релиз)" ;;
            intro_3)            echo "   3. Запустит мастер настройки TrustTunnel (интерактивно)" ;;
            intro_4)            echo "   4. Установит TrustTunnel как systemd-сервис" ;;
            intro_5)            echo "   5. Развернёт веб-панель за сайтом-камуфляжем" ;;
            ask_continue)       echo "Продолжить? [Y/n]" ;;

            check_root_err)     echo "Запустите от root: sudo bash <(curl -Ls ...)" ;;
            arch_detected)      echo "Архитектура:" ;;
            arch_unsupported)   echo "Неподдерживаемая архитектура" ;;

            deps_updating)      echo "Обновление списка пакетов..." ;;
            deps_docker)        echo "Установка Docker..." ;;
            deps_docker_ok)     echo "Docker установлен" ;;
            deps_docker_exists) echo "Docker уже установлен" ;;
            deps_installing)    echo "Установка:" ;;
            deps_ok)            echo "Зависимости установлены" ;;

            tt_fetching)        echo "Получение последнего релиза TrustTunnel..." ;;
            tt_version_fallback) echo "Не удалось получить версию, используется" ;;
            tt_version)         echo "Версия TrustTunnel:" ;;
            tt_exists)          echo "TrustTunnel уже установлен" ;;
            ask_reinstall)      echo "Переустановить/обновить? [y/N]" ;;
            tt_downloading)     echo "Загрузка TrustTunnel" ;;
            tt_download_fail)   echo "Ошибка загрузки:" ;;
            tt_extracting)      echo "Распаковка..." ;;
            tt_extracted)       echo "TrustTunnel распакован в" ;;

            wizard_title)       echo "  Мастер настройки TrustTunnel" ;;
            wizard_hint)        echo "  Мастер спросит про адрес прослушивания, сертификаты,\n  файл учётных данных и правила подключений." ;;
            wizard_exists)      echo "Конфиг TrustTunnel уже существует (vpn.toml найден)" ;;
            ask_rerun_wizard)   echo "Перезапустить мастер настройки? [y/N]" ;;
            wizard_fail)        echo "setup_wizard завершился с ошибкой" ;;
            wizard_ok)          echo "TrustTunnel настроен" ;;

            svc_no_template)    echo "trusttunnel.service.template не найден — пропуск настройки systemd" ;;
            svc_started)        echo "Сервис TrustTunnel запущен (systemctl status trusttunnel)" ;;

            creds_detected)     echo "Обнаружен файл учётных данных:" ;;

            panel_title)        echo "  Настройка веб-панели" ;;
            ask_server_addr)    echo "Публичный IP или домен сервера (используется в tt:// ссылках)" ;;
            ask_domain)         echo "Домен для веб-панели (например panel.example.com). Оставьте пустым чтобы использовать IP:" ;;
            https_no_domain)    echo "HTTPS требует настоящий домен — пропуск (используется HTTP)" ;;
            ask_https)          echo "Включить HTTPS через Let's Encrypt для" ;;
            ask_https_suffix)   echo "? [Y/n]:" ;;
            decoy_title)        echo "  Камуфляж / фейковый сайт" ;;
            decoy_hint)         echo "  На вашем домене будет показываться фейковый видеохостинг (StreamVault).\n  Настоящая панель доступна только по секретному пути." ;;
            ask_secret_path)    echo "Секретный путь панели (часть после домена)" ;;
            panel_url_hint)     echo "  URL панели будет:" ;;
            ask_admin_user)     echo "Имя администратора для веб-панели [admin]:" ;;
            ask_admin_pass)     echo "Пароль администратора (минимум 8 символов):" ;;
            pass_too_short)     echo "Пароль должен быть не менее 8 символов" ;;
            config_collected)   echo "Конфигурация собрана" ;;

            deploy_deploying)   echo "Развёртывание TrustTunnel WebUI..." ;;
            deploy_updating)    echo "Обновление существующей установки WebUI..." ;;
            deploy_cloning)     echo "Клонирование репозитория WebUI..." ;;
            deploy_clone_fail)  echo "Не удалось клонировать репозиторий WebUI" ;;
            deploy_env_ok)      echo ".env записан" ;;
            deploy_starting)    echo "Сборка и запуск контейнеров..." ;;
            deploy_ok)          echo "WebUI запущен" ;;

            https_obtaining)    echo "Получение сертификата Let's Encrypt для" ;;
            https_fail)         echo "certbot завершился с ошибкой — проверьте что порт 80 открыт и DNS указывает на этот сервер" ;;
            https_ok)           echo "Сертификат получен для" ;;

            step1)              echo "  Шаг 1/2 — Настройка TrustTunnel" ;;
            step2)              echo "  Шаг 2/2 — Настройка панели и камуфляжа" ;;

            summary_done)       echo "  Установка завершена!" ;;
            summary_tt)         echo "  TrustTunnel endpoint:" ;;
            summary_tt_dir)     echo "    Директория :" ;;
            summary_tt_svc)     echo "    Сервис      :" ;;
            summary_decoy)      echo "  Сайт-камуфляж (виден всем):" ;;
            summary_decoy_url)  echo "    URL         :" ;;
            summary_decoy_shows) echo "    Показывает  : StreamVault — фейковый видеохостинг" ;;
            summary_panel)      echo "  Панель администратора (секретная):" ;;
            summary_panel_url)  echo "    URL         :" ;;
            summary_login)      echo "    Логин       :" ;;
            summary_pass)       echo "    Пароль      :" ;;
            summary_cmds)       echo "  Полезные команды:" ;;
            summary_cmd_logs)   echo "    # Просмотр логов" ;;
            summary_cmd_restart) echo "    # Перезапуск" ;;
            summary_cmd_svc)    echo "    # Сервис TrustTunnel" ;;
            summary_warn)       echo "  Держите URL панели в секрете — пользователям передавайте только tt:// ссылки." ;;
        esac
    else
        case "$key" in
            lang_select)        echo "Choose language / Выберите язык:" ;;
            lang_en)            echo "  1) English" ;;
            lang_ru)            echo "  2) Русский" ;;
            lang_prompt)        echo "Enter 1 or 2 [1]: " ;;

            intro_title)        echo "  TrustTunnel + WebUI — Installer" ;;
            intro_sub)          echo "  github.com/iamnovye/trusttunnel-webui" ;;
            intro_will)         echo "This script will:" ;;
            intro_1)            echo "   1. Install Docker and dependencies" ;;
            intro_2)            echo "   2. Download TrustTunnel (latest release)" ;;
            intro_3)            echo "   3. Run the TrustTunnel setup wizard (interactive)" ;;
            intro_4)            echo "   4. Install TrustTunnel as a systemd service" ;;
            intro_5)            echo "   5. Deploy the web admin panel behind a camouflage site" ;;
            ask_continue)       echo "Continue? [Y/n]" ;;

            check_root_err)     echo "Run as root: sudo bash <(curl -Ls ...)" ;;
            arch_detected)      echo "Architecture:" ;;
            arch_unsupported)   echo "Unsupported architecture" ;;

            deps_updating)      echo "Updating package lists..." ;;
            deps_docker)        echo "Installing Docker..." ;;
            deps_docker_ok)     echo "Docker installed" ;;
            deps_docker_exists) echo "Docker already installed" ;;
            deps_installing)    echo "Installing:" ;;
            deps_ok)            echo "Dependencies OK" ;;

            tt_fetching)        echo "Fetching latest TrustTunnel release..." ;;
            tt_version_fallback) echo "Could not fetch latest version, using fallback" ;;
            tt_version)         echo "TrustTunnel version:" ;;
            tt_exists)          echo "TrustTunnel already installed" ;;
            ask_reinstall)      echo "Reinstall/upgrade? [y/N]" ;;
            tt_downloading)     echo "Downloading TrustTunnel" ;;
            tt_download_fail)   echo "Download failed:" ;;
            tt_extracting)      echo "Extracting..." ;;
            tt_extracted)       echo "TrustTunnel extracted to" ;;

            wizard_title)       echo "  TrustTunnel Setup Wizard" ;;
            wizard_hint)        echo "  The wizard will ask about listen address, certificates,\n  credentials file and connection rules." ;;
            wizard_exists)      echo "TrustTunnel config already exists (vpn.toml found)" ;;
            ask_rerun_wizard)   echo "Re-run setup wizard? [y/N]" ;;
            wizard_fail)        echo "setup_wizard failed" ;;
            wizard_ok)          echo "TrustTunnel configured" ;;

            svc_no_template)    echo "trusttunnel.service.template not found — skipping systemd setup" ;;
            svc_started)        echo "TrustTunnel service started (systemctl status trusttunnel)" ;;

            creds_detected)     echo "Detected credentials file:" ;;

            panel_title)        echo "  Web Panel Configuration" ;;
            ask_server_addr)    echo "Server public IP or domain (used for tt:// links)" ;;
            ask_domain)         echo "Domain for the web panel (e.g. media.example.com). Leave empty to use IP:" ;;
            https_no_domain)    echo "HTTPS requires a real domain — skipping (using HTTP)" ;;
            ask_https)          echo "Enable HTTPS with Let's Encrypt for" ;;
            ask_https_suffix)   echo "? [Y/n]:" ;;
            decoy_title)        echo "  Camouflage / decoy setup" ;;
            decoy_hint)         echo "  Your domain will show a fake video streaming site (StreamVault).\n  The real admin panel is only accessible at a secret path." ;;
            ask_secret_path)    echo "Secret panel path (the part after your domain)" ;;
            panel_url_hint)     echo "  Panel URL will be:" ;;
            ask_admin_user)     echo "Admin username for web panel [admin]:" ;;
            ask_admin_pass)     echo "Admin password (min 8 chars):" ;;
            pass_too_short)     echo "Password must be at least 8 characters" ;;
            config_collected)   echo "Configuration collected" ;;

            deploy_deploying)   echo "Deploying TrustTunnel WebUI..." ;;
            deploy_updating)    echo "Updating existing WebUI installation..." ;;
            deploy_cloning)     echo "Cloning WebUI repository..." ;;
            deploy_clone_fail)  echo "Failed to clone WebUI repository" ;;
            deploy_env_ok)      echo ".env written" ;;
            deploy_starting)    echo "Building and starting containers..." ;;
            deploy_ok)          echo "WebUI is running" ;;

            https_obtaining)    echo "Obtaining Let's Encrypt certificate for" ;;
            https_fail)         echo "certbot failed — check that port 80 is open and DNS points to this server" ;;
            https_ok)           echo "Certificate obtained for" ;;

            step1)              echo "  Step 1/2 — TrustTunnel Setup" ;;
            step2)              echo "  Step 2/2 — Web Panel + Camouflage Setup" ;;

            summary_done)       echo "  Installation complete!" ;;
            summary_tt)         echo "  TrustTunnel endpoint:" ;;
            summary_tt_dir)     echo "    Dir     :" ;;
            summary_tt_svc)     echo "    Service :" ;;
            summary_decoy)      echo "  Camouflage site (visible to everyone):" ;;
            summary_decoy_url)  echo "    URL     :" ;;
            summary_decoy_shows) echo "    Shows   : StreamVault — fake video streaming site" ;;
            summary_panel)      echo "  Admin panel (secret):" ;;
            summary_panel_url)  echo "    URL     :" ;;
            summary_login)      echo "    Login   :" ;;
            summary_pass)       echo "    Password:" ;;
            summary_cmds)       echo "  Useful commands:" ;;
            summary_cmd_logs)   echo "    # View logs" ;;
            summary_cmd_restart) echo "    # Restart" ;;
            summary_cmd_svc)    echo "    # TrustTunnel service" ;;
            summary_warn)       echo "  Keep the panel URL secret — share only tt:// connection links with users." ;;
        esac
    fi
}

# ─────────────────────────────────────────────
#  Language selection
# ─────────────────────────────────────────────
choose_language() {
    echo ""
    echo -e "${BOLD}$(t lang_select)${NC}"
    echo "$(t lang_en)"
    echo "$(t lang_ru)"
    echo ""
    printf "${BOLD}${CYAN}[?]${NC} $(t lang_prompt)"
    read -r lang_input
    case "${lang_input:-1}" in
        2|ru|RU|Ru) LANG_CHOICE="ru" ;;
        *)           LANG_CHOICE="en" ;;
    esac
}

# ─────────────────────────────────────────────
#  Defaults / globals
# ─────────────────────────────────────────────
TT_INSTALL_DIR="/opt/trusttunnel"
WEBUI_DIR="/opt/trusttunnel-webui"
WEBUI_REPO="https://github.com/iamnovye/trusttunnel-webui"
WEBUI_BRANCH="claude/eager-newton-t257ev"
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
    [[ $EUID -eq 0 ]] || die "$(t check_root_err)"
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
        *) die "$(t arch_unsupported): $machine" ;;
    esac
    info "$(t arch_detected) $ARCH"
}

# ─────────────────────────────────────────────
#  Dependencies
# ─────────────────────────────────────────────
install_deps() {
    info "$(t deps_updating)"
    apt-get update -qq

    local pkgs=()
    command -v curl    &>/dev/null || pkgs+=(curl)
    command -v wget    &>/dev/null || pkgs+=(wget)
    command -v tar     &>/dev/null || pkgs+=(tar)
    command -v jq      &>/dev/null || pkgs+=(jq)
    command -v git     &>/dev/null || pkgs+=(git)
    command -v gettext &>/dev/null || pkgs+=(gettext-base)

    if ! command -v docker &>/dev/null; then
        info "$(t deps_docker)"
        curl -fsSL https://get.docker.com | sh
        systemctl enable --now docker
        success "$(t deps_docker_ok)"
    else
        success "$(t deps_docker_exists)"
    fi

    if [[ ${#pkgs[@]} -gt 0 ]]; then
        info "$(t deps_installing) ${pkgs[*]}"
        apt-get install -y -qq "${pkgs[@]}"
    fi

    success "$(t deps_ok)"
}

# ─────────────────────────────────────────────
#  TrustTunnel download
# ─────────────────────────────────────────────
fetch_latest_version() {
    info "$(t tt_fetching)"
    TT_VERSION=$(curl -fsSL "https://api.github.com/repos/TrustTunnel/TrustTunnel/releases/latest" \
        | grep '"tag_name"' | head -1 | sed 's/.*"tag_name": *"\(.*\)".*/\1/') || true

    if [[ -z "$TT_VERSION" ]]; then
        TT_VERSION="v1.0.33"
        warn "$(t tt_version_fallback) $TT_VERSION"
    fi

    TT_TARBALL_URL="${TT_GITHUB}/releases/download/${TT_VERSION}/trusttunnel-${TT_VERSION}-linux-${ARCH}.tar.gz"
    info "$(t tt_version) ${BOLD}$TT_VERSION${NC}"
}

download_trusttunnel() {
    if [[ -f "$TT_INSTALL_DIR/trusttunnel_endpoint" ]]; then
        local current_ver=""
        current_ver=$("$TT_INSTALL_DIR/trusttunnel_endpoint" --version 2>/dev/null || echo "unknown")
        warn "$(t tt_exists) ($current_ver) at $TT_INSTALL_DIR"
        ask "$(t ask_reinstall)"
        read -r reinstall
        [[ "$reinstall" =~ ^[Yy]$ ]] || return 0
    fi

    mkdir -p "$TT_INSTALL_DIR"
    info "$(t tt_downloading) $TT_VERSION..."
    local tmpdir
    tmpdir=$(mktemp -d)
    trap "rm -rf $tmpdir" RETURN

    curl -fsSL --progress-bar "$TT_TARBALL_URL" -o "$tmpdir/trusttunnel.tar.gz" \
        || die "$(t tt_download_fail) $TT_TARBALL_URL"

    info "$(t tt_extracting)"
    tar -xzf "$tmpdir/trusttunnel.tar.gz" -C "$tmpdir"

    local extract_dir
    extract_dir=$(find "$tmpdir" -mindepth 1 -maxdepth 1 -type d | head -1)
    [[ -z "$extract_dir" ]] && extract_dir="$tmpdir"

    cp -r "$extract_dir"/. "$TT_INSTALL_DIR/"
    chmod +x "$TT_INSTALL_DIR"/trusttunnel_endpoint 2>/dev/null || true
    chmod +x "$TT_INSTALL_DIR"/setup_wizard 2>/dev/null || true

    success "$(t tt_extracted) $TT_INSTALL_DIR"
}

# ─────────────────────────────────────────────
#  TrustTunnel setup wizard
# ─────────────────────────────────────────────
run_setup_wizard() {
    if [[ -f "$TT_INSTALL_DIR/vpn.toml" ]]; then
        warn "$(t wizard_exists)"
        ask "$(t ask_rerun_wizard)"
        read -r redo
        [[ "$redo" =~ ^[Yy]$ ]] || return 0
    fi

    echo ""
    sep
    echo -e "${BOLD}$(t wizard_title)${NC}"
    sep
    echo -e "${DIM}$(t wizard_hint)${NC}"
    echo ""

    # Print cheat-sheet so Russian users know what each wizard prompt means
    if [[ "$LANG_CHOICE" == "ru" ]]; then
        echo ""
        echo -e "${YELLOW}${BOLD}  Шпаргалка — что спросит мастер настройки:${NC}"
        sep
        echo -e "  ${BOLD}Listen address${NC} — адрес и порт, на котором слушает VPN"
        echo -e "    ${DIM}Рекомендуется: 0.0.0.0:443${NC}"
        echo ""
        echo -e "  ${BOLD}Credentials file path${NC} — путь к файлу с логинами пользователей"
        echo -e "    ${DIM}Рекомендуется: оставить по умолчанию (Enter)${NC}"
        echo ""
        echo -e "  ${BOLD}Username / Password${NC} — логин и пароль первого VPN-пользователя"
        echo -e "    ${DIM}Можно добавить несколько, ответив 'y' на 'Add one more user?'${NC}"
        echo ""
        echo -e "  ${BOLD}Rules file path${NC} — файл правил фильтрации подключений"
        echo -e "    ${DIM}Рекомендуется: оставить по умолчанию (Enter)${NC}"
        echo ""
        echo -e "  ${BOLD}Certificate${NC} — сертификат TLS для VPN-трафика"
        echo -e "    ${DIM}1 = Let's Encrypt (нужен домен), 2 = самоподписанный, 3 = свой файл${NC}"
        echo ""
        echo -e "  ${BOLD}Settings / Hosts file path${NC} — пути конфиг-файлов"
        echo -e "    ${DIM}Рекомендуется: оставить по умолчанию (Enter)${NC}"
        sep
        echo ""
        echo -e "  ${DIM}Мастер настройки запускается на английском — это нормально.${NC}"
        echo -e "  ${DIM}Используйте шпаргалку выше чтобы понимать каждый вопрос.${NC}"
        echo ""
        ask "Нажмите Enter чтобы запустить мастер настройки..."
        read -r _
    fi

    cd "$TT_INSTALL_DIR"
    ./setup_wizard || die "$(t wizard_fail)"

    # Fix relative paths in vpn.toml and hosts.toml to absolute paths.
    # The Docker backend mounts TT_INSTALL_DIR as /trusttunnel, so paths must
    # be absolute and use /trusttunnel/ prefix to work both in systemd and Docker.
    ln -sfn "$TT_INSTALL_DIR" /trusttunnel

    local vpn_toml="$TT_INSTALL_DIR/vpn.toml"
    local hosts_toml="$TT_INSTALL_DIR/hosts.toml"

    if [[ -f "$vpn_toml" ]]; then
        sed -i "s|credentials_file = \"credentials.toml\"|credentials_file = \"/trusttunnel/credentials.toml\"|" "$vpn_toml"
        sed -i "s|rules_file = \"rules.toml\"|rules_file = \"/trusttunnel/rules.toml\"|" "$vpn_toml"
    fi

    if [[ -f "$hosts_toml" ]]; then
        sed -i "s|cert_chain_path = \"certs/cert.pem\"|cert_chain_path = \"/trusttunnel/certs/cert.pem\"|" "$hosts_toml"
        sed -i "s|private_key_path = \"certs/key.pem\"|private_key_path = \"/trusttunnel/certs/key.pem\"|" "$hosts_toml"
    fi

    success "$(t wizard_ok)"

}

# ─────────────────────────────────────────────
#  Systemd service
# ─────────────────────────────────────────────
install_tt_service() {
    if [[ ! -f "$TT_INSTALL_DIR/trusttunnel.service.template" ]]; then
        warn "$(t svc_no_template)"
        return 0
    fi

    cp "$TT_INSTALL_DIR/trusttunnel.service.template" \
       /etc/systemd/system/trusttunnel.service

    systemctl daemon-reload
    systemctl enable --now trusttunnel
    success "$(t svc_started)"
}

# ─────────────────────────────────────────────
#  Detect credentials path
# ─────────────────────────────────────────────
detect_config_paths() {
    CREDS_FILE="$TT_INSTALL_DIR/credentials.toml"
    local vpn_toml="$TT_INSTALL_DIR/vpn.toml"
    [[ ! -f "$vpn_toml" ]] && return 0

    local creds
    creds=$(grep -E '^\s*credentials_file\s*=' "$vpn_toml" 2>/dev/null \
        | head -1 | sed 's/.*=\s*"\(.*\)".*/\1/' || echo "")
    if [[ -n "$creds" ]]; then
        # Make absolute if relative
        [[ "$creds" != /* ]] && creds="$TT_INSTALL_DIR/$creds"
        CREDS_FILE="$creds"
    fi
    info "$(t creds_detected) $CREDS_FILE"
}

# ─────────────────────────────────────────────
#  Collect WebUI config
# ─────────────────────────────────────────────
collect_webui_config() {
    echo ""
    sep
    echo -e "${BOLD}$(t panel_title)${NC}"
    sep
    echo ""

    # ── Server address / domain ──
    local default_ip
    default_ip=$(curl -fsSL --max-time 5 https://api.ipify.org 2>/dev/null \
        || hostname -I | awk '{print $1}')

    ask "$(t ask_server_addr) [${default_ip}]:"
    read -r input
    SERVER_ADDRESS="${input:-$default_ip}"

    # ── Secret panel path ──
    echo ""
    echo -e "  ${BOLD}$(t decoy_title)${NC}"
    echo -e "  ${DIM}$(t decoy_hint)${NC}"
    echo ""

    local default_path
    default_path=$(openssl rand -hex 6 2>/dev/null || tr -dc 'a-z0-9' < /dev/urandom | head -c 12)

    ask "$(t ask_secret_path) [${default_path}]:"
    echo -e "  ${DIM}$(t panel_url_hint) http://${SERVER_ADDRESS}/${default_path}/${NC}"
    read -r input
    PANEL_PATH="${input:-$default_path}"
    PANEL_PATH="${PANEL_PATH#/}"; PANEL_PATH="${PANEL_PATH%/}"
    [[ -z "$PANEL_PATH" ]] && PANEL_PATH="$default_path"

    # ── Admin credentials ──
    echo ""
    ask "$(t ask_admin_user)"
    read -r input
    PANEL_ADMIN_USER="${input:-admin}"

    while true; do
        ask "$(t ask_admin_pass)"
        read -rs PANEL_ADMIN_PASS
        echo ""
        [[ ${#PANEL_ADMIN_PASS} -ge 8 ]] && break
        warn "$(t pass_too_short)"
    done

    PANEL_SECRET_KEY=$(openssl rand -hex 32 2>/dev/null || tr -dc 'a-f0-9' < /dev/urandom | head -c 64)

    echo ""
    success "$(t config_collected)"
}

# ─────────────────────────────────────────────
#  Deploy WebUI
# ─────────────────────────────────────────────
deploy_webui() {
    info "$(t deploy_deploying)"

    # Always cd to a safe dir before removing WEBUI_DIR
    # (running rm -rf from inside the target dir breaks the shell)
    cd /root

    if [[ -d "$WEBUI_DIR/.git" ]]; then
        # Check if existing clone is on the right branch; if not, reclone
        local current_branch
        current_branch=$(git -C "$WEBUI_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
        if [[ "$current_branch" != "$WEBUI_BRANCH" ]]; then
            warn "Existing clone is on '$current_branch', need '$WEBUI_BRANCH' — recloning..."
            rm -rf "$WEBUI_DIR"
        else
            info "$(t deploy_updating)"
            git -C "$WEBUI_DIR" pull --ff-only origin "$WEBUI_BRANCH" 2>/dev/null || true
        fi
    fi

    if [[ ! -d "$WEBUI_DIR/.git" ]]; then
        info "$(t deploy_cloning)"
        git clone --depth=1 --branch "$WEBUI_BRANCH" "$WEBUI_REPO" "$WEBUI_DIR" \
            || die "$(t deploy_clone_fail)"
    fi

    cat > "$WEBUI_DIR/.env" <<EOF
ADMIN_USER=${PANEL_ADMIN_USER}
ADMIN_PASS=${PANEL_ADMIN_PASS}
SECRET_KEY=${PANEL_SECRET_KEY}
SERVER_ADDRESS=${SERVER_ADDRESS}
TRUSTTUNNEL_DIR=${TT_INSTALL_DIR}
PANEL_PATH=${PANEL_PATH}
CREDENTIALS_FILE=${CREDS_FILE}
EOF
    success "$(t deploy_env_ok)"

    info "$(t deploy_starting)"
    cd "$WEBUI_DIR"
    docker compose up -d --build

    success "$(t deploy_ok)"
}

# ─────────────────────────────────────────────
#  Summary
# ─────────────────────────────────────────────
print_summary() {
    # nginx serves on port 80 (plain HTTP); TrustTunnel handles TLS on port 443 for VPN only
    local base_url="http://${SERVER_ADDRESS}"
    local panel_url="${base_url}/${PANEL_PATH}/"

    echo ""
    echo -e "${GREEN}${BOLD}"
    echo "  ╔══════════════════════════════════════════════════════╗"
    echo "  ║   $(t summary_done)                    ║"
    echo "  ╚══════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    sep
    echo -e "  ${BOLD}$(t summary_tt)${NC}"
    echo -e "$(t summary_tt_dir) ${CYAN}$TT_INSTALL_DIR${NC}"
    echo -e "$(t summary_tt_svc) ${CYAN}systemctl status trusttunnel${NC}"
    echo ""
    echo -e "  ${BOLD}$(t summary_decoy)${NC}"
    echo -e "$(t summary_decoy_url) ${CYAN}${base_url}/${NC}"
    echo -e "$(t summary_decoy_shows)"
    echo ""
    echo -e "  ${BOLD}$(t summary_panel)${NC}"
    echo -e "$(t summary_panel_url) ${GREEN}${BOLD}${panel_url}${NC}"
    echo -e "$(t summary_login) ${CYAN}${PANEL_ADMIN_USER}${NC}"
    echo -e "$(t summary_pass) ${CYAN}${PANEL_ADMIN_PASS}${NC}"
    echo ""
    echo -e "  ${BOLD}$(t summary_cmds)${NC}"
    echo -e "    ${DIM}$(t summary_cmd_logs)${NC}"
    echo -e "    docker compose -f $WEBUI_DIR/docker-compose.yml logs -f"
    echo -e "    ${DIM}$(t summary_cmd_restart)${NC}"
    echo -e "    docker compose -f $WEBUI_DIR/docker-compose.yml restart"
    echo -e "    ${DIM}$(t summary_cmd_svc)${NC}"
    echo -e "    systemctl status trusttunnel"
    sep
    echo ""
    echo -e "  ${YELLOW}${BOLD}$(t summary_warn)${NC}"
    echo ""
}

# ─────────────────────────────────────────────
#  Main
# ─────────────────────────────────────────────
main() {
    # When run via bash <(curl ...), stdin is the pipe with the script itself.
    # Redirect stdin to the terminal so read commands work interactively.
    exec < /dev/tty

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

    choose_language

    echo ""
    echo -e "  ${BOLD}$(t intro_title)${NC}"
    echo -e "  ${DIM}$(t intro_sub)${NC}"
    echo ""
    sep
    echo ""

    check_root
    check_os
    detect_arch

    echo ""
    info "$(t intro_will)"
    echo "$(t intro_1)"
    echo "$(t intro_2)"
    echo "$(t intro_3)"
    echo "$(t intro_4)"
    echo "$(t intro_5)"
    echo ""
    ask "$(t ask_continue)"
    read -r go
    [[ "$go" =~ ^[Nn]$ ]] && exit 0

    sep

    install_deps
    fetch_latest_version
    download_trusttunnel

    sep
    echo ""
    echo -e "${BOLD}$(t step1)${NC}"
    echo ""
    run_setup_wizard
    detect_config_paths
    install_tt_service

    sep
    echo ""
    echo -e "${BOLD}$(t step2)${NC}"
    echo ""
    collect_webui_config
    deploy_webui

    print_summary
}

main "$@"
