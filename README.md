# TrustTunnel WebUI

Веб-панель для управления пользователями TrustTunnel VPN.

## Возможности

- Вход по логину/паролю
- Добавление пользователей (вызывает `trusttunnel_endpoint` и возвращает `tt://` ссылку)
- Удаление пользователей
- Копирование ссылки подключения + QR-код

## Установка на сервере

### 1. Клонируйте репозиторий

```bash
git clone https://github.com/iamnovye/trusttunnel-webui.git /opt/trusttunnel-webui
cd /opt/trusttunnel-webui
```

### 2. Создайте `.env`

```bash
cp .env.example .env
nano .env
```

Заполните:
- `ADMIN_USER` / `ADMIN_PASS` — ваши учётные данные для входа в панель
- `SECRET_KEY` — длинная случайная строка (`openssl rand -hex 32`)
- `SERVER_ADDRESS` — публичный IP или домен сервера (например `vpn.example.com`)
- `TRUSTTUNNEL_DIR` — путь где установлен TrustTunnel на хосте (по умолчанию `/opt/trusttunnel`)

### 3. Запустите

```bash
docker compose up -d
```

Панель откроется на `http://your-server-ip`.

### 4. HTTPS (опционально, но рекомендуется)

```bash
apt install certbot python3-certbot-nginx
certbot certonly --nginx -d yourdomain.com

# Раскомментируйте HTTPS блок в nginx/nginx.conf
# и HTTP redirect, затем:
docker compose restart frontend
```

## Структура файлов TrustTunnel

Ожидается что в `TRUSTTUNNEL_DIR` находятся:

```
/opt/trusttunnel/
  trusttunnel_endpoint   # бинарный файл
  vpn.toml               # конфиг endpoint
  hosts.toml             # TLS hosts конфиг
  credentials            # файл с пользователями (user:pass)
```

## Переменные окружения backend

| Переменная | По умолчанию | Описание |
|---|---|---|
| `ADMIN_USER` | `admin` | Логин для панели |
| `ADMIN_PASS` | `changeme` | Пароль для панели |
| `SECRET_KEY` | случайный | Flask session secret |
| `SERVER_ADDRESS` | — | IP/домен для генерации ссылок |
| `TRUSTTUNNEL_DIR` | `/opt/trusttunnel` | Папка TrustTunnel на хосте |
| `VPN_TOML` | `/trusttunnel/vpn.toml` | Путь внутри контейнера |
| `HOSTS_TOML` | `/trusttunnel/hosts.toml` | Путь внутри контейнера |
| `CREDENTIALS_FILE` | `/trusttunnel/credentials` | Путь внутри контейнера |
| `TT_BINARY` | `/trusttunnel/trusttunnel_endpoint` | Путь бинарника |
