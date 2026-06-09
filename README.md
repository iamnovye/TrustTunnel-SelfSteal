# TrustTunnel | Self-steal

Веб-панель администратора для [TrustTunnel VPN](https://github.com/TrustTunnel/TrustTunnel) с сайтом-камуфляжем.

**Автор:** [@iamnovye](https://t.me/iamnovye) · [Instagram](https://www.instagram.com/iamnovye)

## Установка

Одна команда — полная установка на чистый Ubuntu/Debian сервер:

```bash
bash <(curl -Ls https://raw.githubusercontent.com/iamnovye/trusttunnel-webui/main/install.sh)
```

Скрипт выполнит:
1. Установит Docker и зависимости
2. Скачает TrustTunnel (последний релиз)
3. Запустит мастер настройки TrustTunnel — нужно будет ответить на вопросы (см. раздел ниже)
4. Установит TrustTunnel как systemd-сервис
5. Развернёт веб-панель за сайтом-камуфляжем StreamVault

Поддерживает **русский и английский** языки.

## Вопросы мастера настройки

Мастер настройки TrustTunnel задаёт вопросы на **английском языке**. Ниже — все вопросы по порядку:

| Вопрос | Рекомендуемый ответ |
|---|---|
| `The address to listen on` | `0.0.0.0:443` → Enter |
| `Path to the credentials file` | Enter (по умолчанию) |
| `Username` | имя первого VPN-пользователя |
| `Password` | пароль первого VPN-пользователя |
| `Add one more user?` | `yes` или `no` |
| `Path to the rules file` | Enter (по умолчанию) |
| `Do you want to configure connection filtering rules?` | `no` → Enter |
| `Path to a file to store the library settings` | Enter (по умолчанию) |
| `How would you like to create a certificate?` | Let's Encrypt (нужен домен) или самоподписанный |
| `Enter your domain name` | ваш домен |
| `Enter your email address` | ваш email (для уведомлений LE) |
| `Select challenge method` | HTTP-01 → Enter |
| `Use Let's Encrypt staging environment for testing?` | `no` → Enter |
| `Do you want to configure alternative SNIs?` | `no` → Enter |
| `Path to a file to store the TLS hosts settings` | Enter (по умолчанию) |

После мастера скрипт автоматически задаст несколько вопросов для настройки веб-панели (адрес сервера, секретный путь, логин и пароль).

## Что получится

| Адрес | Что показывает |
|---|---|
| `http://домен/` | Фейковый видеохостинг StreamVault (виден всем) |
| `https://домен:8443/<секретный-путь>/` | Панель администратора по HTTPS (если выбран Let's Encrypt) |
| `http://домен/<секретный-путь>/` | Панель администратора по HTTP |
| Порт 443 | TrustTunnel VPN |

> **Важно:** панель работает по `http://` (или `https://:8443`). Если браузер принудительно открывает HTTPS — очистите HSTS: в Chrome откройте `chrome://net-internals/#hsts`, введите домен и нажмите Delete.

## Панель администратора

- Добавление/удаление VPN-пользователей
- Генерация `tt://` ссылок и QR-кодов для подключения
- Логин и пароль задаются при установке
- Имена пользователей: только буквы, цифры, `_`, `-`, `.` (не email-формат)

## Управление

```bash
# Логи
docker compose -f /opt/trusttunnel-webui/docker-compose.yml logs -f

# Перезапуск панели
docker compose -f /opt/trusttunnel-webui/docker-compose.yml restart

# Статус TrustTunnel
systemctl status trusttunnel
```

## Полное удаление

```bash
systemctl stop trusttunnel
systemctl disable trusttunnel
rm -f /etc/systemd/system/trusttunnel.service
systemctl daemon-reload
docker compose -f /opt/trusttunnel-webui/docker-compose.yml down 2>/dev/null || true
rm -rf /opt/trusttunnel /opt/trusttunnel-webui /trusttunnel
```

## Структура репозитория

```
backend/   — Flask API (управление пользователями, генерация ссылок)
frontend/  — Статика (панель + сайт-камуфляж StreamVault)
nginx/     — nginx конфиг (HTTP 80 + HTTPS 8443)
install.sh — Установщик с выбором языка EN/RU
```
