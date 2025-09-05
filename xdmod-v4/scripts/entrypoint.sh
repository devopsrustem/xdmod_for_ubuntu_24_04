#!/bin/bash
set -e

echo "=== Запуск Open XDMoD контейнера (Ubuntu 24.04) ==="

# Установка переменных по умолчанию
MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD:-changeme_root_password}
XDMOD_DB_PASSWORD=${XDMOD_DB_PASSWORD:-changeme_xdmod_password}

# Создание необходимых директорий
mkdir -p /var/log/mysql /run/mysqld
chown -R mysql:mysql /var/log/mysql /run/mysqld

# Инициализация MySQL при первом запуске
if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "Инициализация MySQL..."
    mysqld --initialize-insecure --user=mysql --datadir=/var/lib/mysql

    # Запуск MySQL для настройки
    mysqld --user=mysql --datadir=/var/lib/mysql &
    sleep 15

    # Ожидание готовности MySQL
    echo "Ожидание готовности MySQL..."
    for i in {1..30}; do
        if mysql -e "SELECT 1" &>/dev/null; then
            break
        fi
        echo "Попытка $i/30..."
        sleep 2
    done
    
    # Настройка root пользователя
    echo "Настройка root пользователя MySQL..."
    mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';"
    mysql -e "DELETE FROM mysql.user WHERE User='';"
    mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
    mysql -e "DROP DATABASE IF EXISTS test;"
    mysql -e "FLUSH PRIVILEGES;"
    
    # Создание баз данных для XDMoD
    echo "Создание баз данных XDMoD..."
    mysql -u root -p${MYSQL_ROOT_PASSWORD} -e "CREATE DATABASE IF NOT EXISTS mod_hpcdb;"
    mysql -u root -p${MYSQL_ROOT_PASSWORD} -e "CREATE DATABASE IF NOT EXISTS mod_logger;"
    mysql -u root -p${MYSQL_ROOT_PASSWORD} -e "CREATE DATABASE IF NOT EXISTS mod_shredder;"
    mysql -u root -p${MYSQL_ROOT_PASSWORD} -e "CREATE DATABASE IF NOT EXISTS moddb;"
    mysql -u root -p${MYSQL_ROOT_PASSWORD} -e "CREATE DATABASE IF NOT EXISTS modw;"
    mysql -u root -p${MYSQL_ROOT_PASSWORD} -e "CREATE DATABASE IF NOT EXISTS modw_aggregates;"
    mysql -u root -p${MYSQL_ROOT_PASSWORD} -e "CREATE DATABASE IF NOT EXISTS modw_filters;"
    
    # Создание пользователя XDMoD
    echo "Создание пользователя XDMoD..."
    mysql -u root -p${MYSQL_ROOT_PASSWORD} -e "CREATE USER IF NOT EXISTS 'xdmod'@'localhost' IDENTIFIED BY '${XDMOD_DB_PASSWORD}';"
    mysql -u root -p${MYSQL_ROOT_PASSWORD} -e "GRANT ALL ON mod_hpcdb.* TO 'xdmod'@'localhost';"
    mysql -u root -p${MYSQL_ROOT_PASSWORD} -e "GRANT ALL ON mod_logger.* TO 'xdmod'@'localhost';"
    mysql -u root -p${MYSQL_ROOT_PASSWORD} -e "GRANT ALL ON mod_shredder.* TO 'xdmod'@'localhost';"
    mysql -u root -p${MYSQL_ROOT_PASSWORD} -e "GRANT ALL ON moddb.* TO 'xdmod'@'localhost';"
    mysql -u root -p${MYSQL_ROOT_PASSWORD} -e "GRANT ALL ON modw.* TO 'xdmod'@'localhost';"
    mysql -u root -p${MYSQL_ROOT_PASSWORD} -e "GRANT ALL ON modw_aggregates.* TO 'xdmod'@'localhost';"
    mysql -u root -p${MYSQL_ROOT_PASSWORD} -e "GRANT ALL ON modw_filters.* TO 'xdmod'@'localhost';"
    mysql -u root -p${MYSQL_ROOT_PASSWORD} -e "FLUSH PRIVILEGES;"
    
    # Останов MySQL
    mysqladmin -u root -p${MYSQL_ROOT_PASSWORD} shutdown
    sleep 5
    echo "Инициализация MySQL завершена"
fi

# Генерация SSL сертификата
if [ ! -f "/etc/ssl/certs/xdmod-selfsigned.crt" ]; then
    echo "Генерация SSL сертификата..."
    mkdir -p /etc/ssl/{certs,private}
    
    # Создаем конфигурацию с SAN для IP
    cat > /tmp/ssl.conf << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = RU
ST = Moscow
L = Moscow
O = Company
CN = 10.36.80.9

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
IP.1 = 10.36.80.9
DNS.1 = localhost
EOF
    
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/ssl/private/xdmod-selfsigned.key \
        -out /etc/ssl/certs/xdmod-selfsigned.crt \
        -config /tmp/ssl.conf -extensions v3_req
    
    chmod 600 /etc/ssl/private/xdmod-selfsigned.key
    rm -f /tmp/ssl.conf
    echo "SSL сертификат создан с поддержкой IP адреса"
fi

# Запуск MySQL
echo "Запуск MySQL..."
service mariadb start
sleep 10

# Проверка доступности MySQL
echo "Проверка доступности MySQL..."
if mysql -u root -p${MYSQL_ROOT_PASSWORD} -e "SELECT 1" &>/dev/null; then
    echo "MySQL работает нормально"
else
    echo "ОШИБКА: MySQL не отвечает"
    exit 1
fi

# Проверка версии GLIBC
echo "Проверка версии GLIBC..."
ldd --version | head -1

# Настройка пути к SLURM sacct
if [ -f "/opt/slurm/bin/sacct" ]; then
    echo "Настройка пути к sacct в XDMoD..."
    
    # Создаем секцию [slurm] если её нет
    if ! grep -q "\[slurm\]" /usr/share/xdmod/etc/portal_settings.ini; then
        echo -e "\n[slurm]" >> /usr/share/xdmod/etc/portal_settings.ini
    fi
    
    # Обновляем путь к sacct
    if grep -q "sacct =" /usr/share/xdmod/etc/portal_settings.ini; then
        sed -i 's|sacct = ".*"|sacct = "/opt/slurm/bin/sacct"|g' /usr/share/xdmod/etc/portal_settings.ini
    else
        sed -i '/\[slurm\]/a sacct = "/opt/slurm/bin/sacct"' /usr/share/xdmod/etc/portal_settings.ini
    fi
    
    echo "Путь к sacct настроен: /opt/slurm/bin/sacct"
else
    echo "ВНИМАНИЕ: sacct не найден в /opt/slurm/bin/"
    echo "Проверьте монтирование директории SLURM"
fi

# Проверка доступности SLURM логов
if [ -d "/var/log/slurm" ]; then
    echo "SLURM логи доступны в /var/log/slurm"
    ls -la /var/log/slurm/ | head -5
else
    echo "ВНИМАНИЕ: SLURM логи не обнаружены"
    mkdir -p /var/log/slurm
fi

# Запуск PHP-FPM
echo "Запуск PHP-FPM..."
service php7.4-fpm start

# Запуск cron
echo "Запуск cron..."
service cron start

# Настройка cron для XDMoD
if [ ! -f "/etc/cron.d/xdmod" ]; then
    echo "Создание cron заданий для XDMoD..."
    cat > /etc/cron.d/xdmod << 'EOF'
# Импорт данных SLURM каждые 5 минут (xdmod-slurm-helper + xdmod-ingestor)
*/5 * * * * root /usr/local/bin/export-slurm-daily.sh

# Агрегация данных раз в сутки в 2:00
0 2 * * * root /usr/share/xdmod/bin/xdmod-ingestor --aggregate >> /var/log/xdmod/aggregate.log 2>&1

# Контроль качества в 2:30
30 2 * * * root /usr/share/xdmod/bin/xdmod-build-filter-lists >> /var/log/xdmod/qc.log 2>&1

# Очистка старых логов
0 3 * * * root find /var/log/xdmod -name "*.log" -mtime +7 -delete
EOF
fi

echo "=== Open XDMoD контейнер готов ==="
echo "URL: https://10.36.80.9:8443"
echo "Для настройки XDMoD выполните: docker exec -it xdmod-container xdmod-setup"

# Запуск Apache
exec "$@"