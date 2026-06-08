# TrustTunnel | Self-steal

Веб-панель администратора для [TrustTunnel VPN](https://github.com/TrustTunnel/TrustTunnel) с сайтом-камуфляжем.

## Установка

Одна команда — полная установка на чистый Ubuntu/Debian сервер:

```bash
bash <(curl -Ls https://raw.githubusercontent.com/iamnovye/trusttunnel-webui/main/install.sh)
```

Скрипт выполнит:
1. Установит Docker и зависимости
2. Скачает TrustTunnel (последний релиз)
3. Запустит мастер настройки TrustTunnel (порт 443, сертификат, пользователи)
4. Установит TrustTunnel как systemd-сервис
5. Развернёт веб-панель за сайтом-камуфляжем StreamVault

Поддерживает **русский и английский** языки (выбор в начале установки).

## Что получится

| Адрес | Что показывает |
|---|---|
| `http://ваш-домен/` | Фейковый видеохостинг StreamVault (виден всем) |
| `http://ваш-домен/<секретный-путь>/` | Панель администратора (только вы) |
| Порт 443 | TrustTunnel VPN |

## Панель администратора

- Добавление/удаление VPN-пользователей
- Генерация `tt://` ссылок и QR-кодов для подключения клиентам
- Логин и пароль задаются при установке

## Управление после установки

```bash
# Логи
docker compose -f /opt/trusttunnel-webui/docker-compose.yml logs -f

# Перезапуск панели
docker compose -f /opt/trusttunnel-webui/docker-compose.yml restart

# Статус TrustTunnel
systemctl status trusttunnel
```

## Структура репозитория

```
backend/   — Flask API (управление пользователями, генерация ссылок)
frontend/  — Статика (панель + сайт-камуфляж StreamVault)
nginx/     — nginx конфиг (HTTP на порту 80)
install.sh — Установщик с выбором языка
```
