# XDMoD для кластера tcluster01

Docker-контейнер с Open XDMoD для мониторинга SLURM кластера.

## Quick Start

```bash
# Сборка и запуск контейнера
docker compose down && docker compose build --no-cache && docker compose up -d

# Настройка XDMoD
docker exec -it xdmod-container bash
xdmod-setup
```

**Параметры настройки:**

**1. General Settings:**
- Site Address: `https://10.36.80.9:8443/`
- Email Address: `admin@local`
- Chromium Path: `[Enter]`
- Center Logo Path: `[Enter]`
- Enable Dashboard Tab: `on`
- Overwrite config file: `yes`

**2. Database Setup:**
- DB Hostname: `[localhost]`
- DB Port: `[3306]`
- DB Username: `[xdmod]`
- DB Password: `secure_xdmod_password_123`
- DB Admin Username: `[root]`
- DB Admin Password: `secure_root_password_123`
- Drop and recreate databases: `yes` (для всех баз)

**4. Resources:**
- Resource Name: `tcluster01`
- Formal Name: `testcluster01`
- Resource Type: `[hpc]`
- Resource Allocation Type: `gpu`
- Resource Start Date: `[2025-09-03]`
- CPU nodes: `2`
- Total CPU processors: `512`
- GPU nodes: `2`
- Total GPUs: `16`

**5. Create Admin User:**
- Username: `admin`
- Password: `[ваш пароль]`
- First name: `Admin`
- Last name: `User`
- Email: `admin@localhost`

**Инициализация данных:**
```bash
xdmod-ingestor --bootstrap
acl-config
exit
```

## Быстрый запуск (альтернативный)

```bash
docker compose up -d
```

## Первоначальная настройка

После запуска контейнера нужно выполнить настройку:

```bash
# Зайти в контейнер
docker exec -it xdmod-container bash

# Запустить настройку
xdmod-setup

# Инициализация данных
xdmod-ingestor --bootstrap
acl-config
```

**Параметры для настройки:**
- DB Admin Username: `root`
- DB Admin Password: `secure_root_password_123`
- XDMoD DB Username: `xdmod`
- XDMoD DB Password: `secure_xdmod_password_123`

## Доступ к веб-интерфейсу

- **URL**: https://10.36.80.9:8443/
- **Логин/Пароль**: создаются вручную при настройке

## Автоматический сбор данных

Контейнер автоматически (по рекомендациям XDMoD):
- **Импорт данных**: каждые 15 минут (shredder) + через 5 минут (ingestor)
- **Агрегация**: ежедневно в 2:00
- **Контроль качества**: ежедневно в 2:30
- **Очистка логов**: ежедневно в 3:00 (старше 7 дней)

## Экспорт данных SLURM с хоста

Для экспорта данных с хоста используйте скрипт:

```bash
# Экспорт за последние 24 часа
./export-slurm-for-xdmod.sh

# Экспорт за последний час
./export-slurm-for-xdmod.sh hourly

# Экспорт исторических данных
./export-slurm-for-xdmod.sh historical "2024-01-01T00:00:00" "2024-12-31T23:59:59"
```

## Компоненты

- **XDMoD 11.0.2** - система мониторинга HPC
- **PHP 7.4** - совместимая версия PHP
- **MariaDB** - база данных
- **Apache 2.4** - веб-сервер с SSL

## Конфигурация

- Кластер: `tcluster01`
- Часовой пояс: `Europe/Moscow`
- SSL: самоподписанный сертификат
- Логи: `/var/log/xdmod/`

## Обслуживание

```bash
# Просмотр логов
docker logs xdmod-container
docker exec xdmod-container tail -f /var/log/xdmod/ingestor.log
docker exec xdmod-container tail -f /var/log/slurm-import.log

# Ручной экспорт данных SLURM
docker exec xdmod-container /usr/local/bin/export-slurm-daily.sh

# Ручной полный импорт
docker exec xdmod-container /usr/local/bin/auto-import.sh

# Отдельные команды
docker exec xdmod-container xdmod-shredder -r tcluster01 -f slurm
docker exec xdmod-container xdmod-ingestor
docker exec xdmod-container xdmod-ingestor --aggregate
```

## Автоматический сбор данных

Система автоматически:
- **1:00** - экспортирует данные SLURM за вчерашний день
- **Каждые 15 мин** - обрабатывает новые файлы данных
- **2:00** - агрегирует данные для отчетов

## Перегенерация SSL сертификата

Если нужно изменить IP адрес или перегенерировать сертификат:

```bash
# Удалить старый сертификат
docker exec xdmod-container rm -f /etc/ssl/certs/xdmod-selfsigned.crt /etc/ssl/private/xdmod-selfsigned.key

# Создать конфигурацию с новым IP
docker exec xdmod-container bash -c 'cat > /tmp/ssl.conf << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = RU
ST = Moscow
L = Moscow
O = Company
CN = НОВЫЙ_IP_АДРЕС

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
IP.1 = НОВЫЙ_IP_АДРЕС
DNS.1 = localhost
EOF'

# Сгенерировать новый сертификат
docker exec xdmod-container openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/ssl/private/xdmod-selfsigned.key \
    -out /etc/ssl/certs/xdmod-selfsigned.crt \
    -config /tmp/ssl.conf -extensions v3_req

# Установить права и перезапустить Apache
docker exec xdmod-container chmod 600 /etc/ssl/private/xdmod-selfsigned.key
docker exec xdmod-container service apache2 restart
```

**Замените `НОВЫЙ_IP_АДРЕС` на ваш IP адрес.**

## Исправленные проблемы

В проекте исправлены следующие проблемы:

1. **Неправильные пути к командам XDMoD**
   - `xdmod-slurm-helper` и `xdmod-ingestor` теперь используют полные пути `/usr/share/xdmod/bin/`
   - Cron задания теперь выполняются корректно

2. **Права доступа к логам XDMoD**
   - Директория `/usr/share/xdmod/logs/` создается с правильными правами
   - Файл `exceptions.log` создается автоматически

3. **Права пользователей в Job Viewer**
   - Пользователь `admin` теперь привязан к правильной организации
   - ACL конфигурация обновляется автоматически

4. **Оптимизация производительности**
   - Увеличены лимиты PHP: memory_limit=4G, max_execution_time=60с
   - Включено логирование медленных запросов MySQL

### Изменение IP перед сборкой контейнера

Чтобы изменить IP адрес до сборки контейнера, отредактируйте файл `scripts/entrypoint.sh`:

```bash
# Найти строки с IP адресом
grep -n "10.36.80.9" scripts/entrypoint.sh

# Заменить на новый IP
sed -i 's/10.36.80.9/ВАШ_НОВЫЙ_IP/g' scripts/entrypoint.sh

# Проверить изменения
grep -n "ВАШ_НОВЫЙ_IP" scripts/entrypoint.sh
```

Также обновите в `README.md` и `docker-compose.yml` если нужно.

После этого соберите контейнер:
```bash
docker compose build --no-cache
```