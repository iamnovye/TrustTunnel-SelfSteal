# TrustTunnel | Self-steal

**Admin web panel for [TrustTunnel](https://github.com/TrustTunnel/TrustTunnel) with a camouflage decoy site.**

**Author:** [@iamnovye](https://t.me/iamnovye) · [Instagram](https://www.instagram.com/iamnovye)

🇷🇺 [Читать на русском](README.ru.md)

---

## Installation

One command — full installation on a clean Ubuntu/Debian server:

```bash
bash <(curl -Ls https://raw.githubusercontent.com/iamnovye/trusttunnel-webui/main/install.sh)
```

The script will:
1. Install Docker and dependencies
2. Download TrustTunnel (latest release)
3. Run the TrustTunnel setup wizard (see question guide below)
4. Install TrustTunnel as a systemd service
5. Deploy the web admin panel behind the StreamVault camouflage site

Supports **English and Russian** languages.

## Setup Wizard Questions

The TrustTunnel setup wizard runs in **English**. All questions in order:

| Question | Recommended answer |
|---|---|
| `The address to listen on` | `0.0.0.0:443` → Enter |
| `Path to the credentials file` | Enter (default) |
| `Username` | first VPN user's name |
| `Password` | first VPN user's password |
| `Add one more user?` | `yes` or `no` |
| `Path to the rules file` | Enter (default) |
| `Do you want to configure connection filtering rules?` | `no` → Enter |
| `Path to a file to store the library settings` | Enter (default) |
| `How would you like to create a certificate?` | Let's Encrypt (requires domain) or self-signed |
| `Enter your domain name` | your domain |
| `Enter your email address` | your email (for LE notifications) |
| `Select challenge method` | HTTP-01 → Enter |
| `Use Let's Encrypt staging environment for testing?` | `no` → Enter |
| `Do you want to configure alternative SNIs?` | `no` → Enter |
| `Path to a file to store the TLS hosts settings` | Enter (default) |

After the wizard, the installer will ask a few questions to configure the web panel (server address, secret path, admin login and password).

## What You Get

| Address | What it shows |
|---|---|
| `http://domain/` | Fake StreamVault video hosting (visible to everyone) |
| `https://domain:8443/<secret-path>/` | Admin panel over HTTPS (if Let's Encrypt was chosen) |
| `http://domain/<secret-path>/` | Admin panel over HTTP |
| Port 443 | TrustTunnel VPN |

> **Note:** The panel runs on `http://` (or `https://:8443`). If the browser forces HTTPS — clear HSTS: in Chrome open `chrome://net-internals/#hsts`, enter the domain and click Delete.

## Admin Panel Features

- Add / remove VPN users
- Generate `tt://` links and QR codes for connecting
- Login and password set during installation
- Usernames: letters, digits, `_`, `-`, `.` only (not email format)

## Management

```bash
# Logs
docker compose -f /opt/trusttunnel-webui/docker-compose.yml logs -f

# Restart panel
docker compose -f /opt/trusttunnel-webui/docker-compose.yml restart

# TrustTunnel status
systemctl status trusttunnel
```

## Full Uninstall

```bash
systemctl stop trusttunnel
systemctl disable trusttunnel
rm -f /etc/systemd/system/trusttunnel.service
systemctl daemon-reload
docker compose -f /opt/trusttunnel-webui/docker-compose.yml down 2>/dev/null || true
rm -rf /opt/trusttunnel /opt/trusttunnel-webui /trusttunnel
```

## Repository Structure

```
backend/   — Flask API (user management, link generation)
frontend/  — Static files (panel + StreamVault decoy site)
nginx/     — nginx config (HTTP 80 + HTTPS 8443)
install.sh — Installer with EN/RU language selection
```
