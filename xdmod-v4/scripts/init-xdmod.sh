#!/bin/bash
# Скрипт инициализации XDMoD при первом запуске

echo "=== Инициализация XDMoD ==="

# Создание базовой конфигурации
if [ ! -f "/etc/xdmod/portal_settings.ini" ]; then
    echo "Создание базовой конфигурации XDMoD..."
    
    # Копируем шаблон конфигурации
    cp /usr/share/xdmod/etc/portal_settings.ini /etc/xdmod/
    
    # Обновляем пароли баз данных
    sed -i "s/pass = \"\"/pass = \"${XDMOD_DB_PASSWORD}\"/g" /etc/xdmod/portal_settings.ini
    
    echo "Конфигурация создана"
fi

echo "=== Инициализация завершена ==="