#!/bin/bash

# Ручной импорт данных SLURM в XDMoD
# Используется для разового импорта

CLUSTER_NAME="tcluster01"
LOG_FILE="/var/log/xdmod/manual-import.log"

echo "$(date): Ручной импорт данных" >> $LOG_FILE

# Импорт данных
/usr/local/bin/import-slurm-data.sh $CLUSTER_NAME >> $LOG_FILE 2>&1

# Агрегация
echo "$(date): Агрегация данных" >> $LOG_FILE
/usr/share/xdmod/bin/xdmod-ingestor --aggregate >> $LOG_FILE 2>&1

echo "$(date): Импорт завершен" >> $LOG_FILE