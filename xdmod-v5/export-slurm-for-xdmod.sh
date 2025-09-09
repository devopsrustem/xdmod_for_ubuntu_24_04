#!/bin/bash

# Этот скрипт запускается на ХОСТЕ (не в контейнере)
# Он экспортирует данные SLURM для последующего импорта в XDMoD

EXPORT_DIR="/opt/xdmod-data/slurm-export"
CLUSTER_NAME="tcluster01"
SACCT_BIN="/opt/slurm/bin/sacct"

# Создаем директорию для экспорта если её нет
mkdir -p "$EXPORT_DIR"

# Определяем временной диапазон
if [ "$1" == "hourly" ]; then
    # Для ежечасного запуска через cron
    START_TIME=$(date -d "1 hour ago" +%Y-%m-%dT%H:00:00)
    END_TIME=$(date +%Y-%m-%dT%H:00:00)
    OUTPUT_FILE="$EXPORT_DIR/slurm_$(date +%Y%m%d_%H).log"
elif [ "$1" == "daily" ]; then
    # Для ежедневного запуска
    START_TIME=$(date -d "yesterday" +%Y-%m-%dT00:00:00)
    END_TIME=$(date -d "today" +%Y-%m-%dT00:00:00)
    OUTPUT_FILE="$EXPORT_DIR/slurm_$(date -d "yesterday" +%Y%m%d).log"
elif [ "$1" == "historical" ]; then
    # Для исторических данных
    START_TIME=${2:-"2024-01-01T00:00:00"}
    END_TIME=${3:-$(date +%Y-%m-%dT%H:%M:%S)}
    OUTPUT_FILE="$EXPORT_DIR/slurm_historical_$(date +%Y%m%d_%H%M%S).log"
else
    # По умолчанию - последние 24 часа
    START_TIME=$(date -d "24 hours ago" +%Y-%m-%dT%H:%M:%S)
    END_TIME=$(date +%Y-%m-%dT%H:%M:%S)
    OUTPUT_FILE="$EXPORT_DIR/slurm_latest.log"
fi

echo "Экспорт данных SLURM"
echo "Период: $START_TIME - $END_TIME"
echo "Выходной файл: $OUTPUT_FILE"

# Экспортируем данные
TZ=UTC "$SACCT_BIN" --clusters "$CLUSTER_NAME" \
    --allusers --parsable2 --noheader \
    --allocations --duplicates \
    --format jobid,jobidraw,cluster,partition,qos,account,group,gid,user,uid,submit,eligible,start,end,elapsed,exitcode,state,nnodes,ncpus,reqcpus,reqmem,reqtres,alloctres,timelimit,nodelist,jobname \
    --starttime "$START_TIME" --endtime "$END_TIME" > "$OUTPUT_FILE"

# Проверяем результат
if [ -s "$OUTPUT_FILE" ]; then
    LINES=$(wc -l < "$OUTPUT_FILE")
    echo "Успешно экспортировано $LINES записей"
    
    # Устанавливаем права для чтения из контейнера
    chmod 644 "$OUTPUT_FILE"
    
    # Опционально: запускаем импорт в контейнере
    if [ "$4" == "auto-import" ]; then
        echo "Запускаем импорт в контейнере XDMoD..."
        docker exec xdmod-container /usr/local/bin/import-slurm-data.sh
    fi
else
    echo "Нет данных для экспорта за указанный период"
    rm -f "$OUTPUT_FILE"
fi
