#!/bin/bash

# Скрипт для импорта данных SLURM в XDMoD

CLUSTER_NAME=${1:-tcluster01}
START_DATE=${2:-$(date -d "1 day ago" +%Y-%m-%dT00:00:00)}
END_DATE=${3:-$(date +%Y-%m-%dT%H:%M:%S)}

echo "=== Импорт данных SLURM в XDMoD ==="
echo "Кластер: $CLUSTER_NAME"
echo "Период: $START_DATE - $END_DATE"
echo "Время запуска: $(date)"

# Проверяем версию GLIBC
echo "Версия GLIBC в контейнере:"
ldd --version | head -1

# Проверяем доступность sacct
SACCT_PATH="/opt/slurm/bin/sacct"
if [ ! -f "$SACCT_PATH" ]; then
    # Пробуем стандартный путь
    SACCT_PATH="/usr/bin/sacct"
    if [ ! -f "$SACCT_PATH" ]; then
        echo "ОШИБКА: sacct не найден ни в /opt/slurm/bin/, ни в /usr/bin/"
        exit 1
    fi
fi

echo "Используем sacct из: $SACCT_PATH"

# Проверяем совместимость sacct с текущей GLIBC
echo "Проверка зависимостей sacct..."
if ! ldd "$SACCT_PATH" 2>&1 | grep -q "not found"; then
    echo "✓ sacct совместим с текущей системой"
    
    # Попытка прямого вызова sacct
    echo "Извлечение данных из SLURM..."
    TZ=UTC "$SACCT_PATH" --clusters "$CLUSTER_NAME" --allusers \
        --parsable2 --noheader --allocations --duplicates \
        --format jobid,jobidraw,cluster,partition,qos,account,group,gid,user,uid,submit,eligible,start,end,elapsed,exitcode,state,nnodes,ncpus,reqcpus,reqmem,reqtres,alloctres,timelimit,nodelist,jobname \
        --starttime "$START_DATE" --endtime "$END_DATE" > /tmp/slurm_import_$$.log
    
    if [ -s /tmp/slurm_import_$$.log ]; then
        echo "Найдено $(wc -l < /tmp/slurm_import_$$.log) записей"
        
        # Импорт через shredder
        echo "Импортируем данные в XDMoD..."
        if xdmod-shredder -r "$CLUSTER_NAME" -f slurm -i /tmp/slurm_import_$$.log; then
            echo "✓ Данные успешно импортированы в shredder"
            
            # Запуск инжестора
            echo "Обновляем агрегатные таблицы..."
            if xdmod-ingestor -q; then
                echo "✓ Агрегатные таблицы обновлены"
            else
                echo "⚠ Ошибка при обновлении агрегатных таблиц"
            fi
        else
            echo "⚠ Ошибка при импорте данных в shredder"
        fi
        
        # Очистка временного файла
        rm -f /tmp/slurm_import_$$.log
    else
        echo "Нет данных для импорта за указанный период"
    fi
else
    echo "ОШИБКА: sacct несовместим с текущей версией GLIBC"
    echo "Необходимые библиотеки не найдены:"
    ldd "$SACCT_PATH" 2>&1 | grep "not found"
    
    # Альтернативный метод через файлы
    echo "Проверяем наличие экспортированных данных..."
    if [ -d "/opt/xdmod-data/slurm-export" ]; then
        for file in /opt/xdmod-data/slurm-export/*.log; do
            [ -f "$file" ] || continue
            echo "Обрабатываем файл: $(basename $file)"
            xdmod-shredder -r "$CLUSTER_NAME" -f slurm -i "$file"
            # Перемещаем обработанный файл
            mv "$file" "${file}.processed"
        done
        xdmod-ingestor -q
    else
        echo "Директория /opt/xdmod-data/slurm-export не найдена"
        echo "Создайте её и поместите туда экспортированные данные SLURM"
    fi
fi

echo "=== Импорт завершен: $(date) ==="
