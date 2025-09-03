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
docker exec xdmod-container tail -f /var/log/xdmod/shredder.log

# Ручной полный импорт
docker exec xdmod-container /usr/local/bin/auto-import.sh

# Отдельные команды
docker exec xdmod-container xdmod-shredder -r tcluster01 -f slurm
docker exec xdmod-container xdmod-ingestor
docker exec xdmod-container xdmod-ingestor --aggregate
```