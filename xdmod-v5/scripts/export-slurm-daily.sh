#!/bin/bash

# Импорт данных SLURM через xdmod-slurm-helper (по документации)

CLUSTER_NAME="tcluster01"
LOG_FILE="/var/log/slurm-import.log"

echo "$(date): Импорт данных SLURM через xdmod-slurm-helper" >> $LOG_FILE

# Импорт данных через официальный helper (без параметров времени)
TZ=UTC /usr/share/xdmod/bin/xdmod-slurm-helper -r $CLUSTER_NAME >> $LOG_FILE 2>&1

if [ $? -eq 0 ]; then
    echo "$(date): Данные SLURM успешно импортированы через xdmod-slurm-helper" >> $LOG_FILE
    
    # Запуск ingestor для обработки данных (по документации)
    /usr/share/xdmod/bin/xdmod-ingestor >> $LOG_FILE 2>&1
    
    if [ $? -eq 0 ]; then
        echo "$(date): Данные успешно обработаны ingestor" >> $LOG_FILE
    else
        echo "$(date): ОШИБКА при обработке данных ingestor" >> $LOG_FILE
    fi
else
    echo "$(date): ОШИБКА при импорте данных через xdmod-slurm-helper" >> $LOG_FILE
fi