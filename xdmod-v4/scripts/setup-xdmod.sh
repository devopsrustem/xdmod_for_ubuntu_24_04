#!/bin/bash
# Скрипт автоматической настройки XDMoD

echo "=== Автоматическая настройка XDMoD ==="

# Ожидание готовности MySQL
echo "Ожидание готовности MySQL..."
for i in {1..30}; do
    if mysql -u root -p${MYSQL_ROOT_PASSWORD} -e "SELECT 1" &>/dev/null; then
        break
    fi
    echo "Попытка $i/30..."
    sleep 2
done

# Инициализация схем баз данных
echo "Инициализация схем баз данных XDMoD..."
xdmod-setup --batch

echo "=== Настройка XDMoD завершена ==="