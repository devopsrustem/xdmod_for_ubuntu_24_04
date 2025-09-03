FROM ubuntu:24.04

# Избегаем интерактивных запросов при установке пакетов
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/Moscow
ENV PATH="/usr/share/xdmod/bin:$PATH"

# Использование российских зеркал Ubuntu
RUN sed -i 's|http://archive.ubuntu.com/ubuntu|http://mirror.yandex.ru/ubuntu|g' /etc/apt/sources.list.d/ubuntu.sources

# Обновление системы с повторными попытками
RUN for i in 1 2 3; do apt-get update && break || sleep 5; done && \
    apt-get upgrade -y && \
    apt-get install -y software-properties-common && \
    apt-get clean

# Установка PHP 7.4 (совместимый с XDMoD)
RUN add-apt-repository ppa:ondrej/php && \
    for i in 1 2 3; do apt-get update && break || sleep 10; done && \
    apt-get install -y \
    php7.4 php7.4-cli php7.4-fpm php7.4-mysql php7.4-gd \
    php7.4-xml php7.4-mbstring php7.4-curl php7.4-opcache \
    php7.4-intl php7.4-bcmath php7.4-zip

# Установка Node.js 20 (стандартный в Ubuntu 24.04)
RUN apt-get install -y nodejs npm

# Установка основных зависимостей
RUN apt-get install -y \
    apache2 \
    libapache2-mod-php7.4 \
    mariadb-server mariadb-client \
    cron logrotate postfix \
    wget curl tar gzip unzip \
    sudo vim nano jq \
    openssl ssl-cert \
    git make gcc g++ \
    python3 python3-pip

# Установка SLURM клиента (важно: версия должна соответствовать вашему кластеру)
RUN apt-get install -y slurm-client

# Установка Open XDMoD из рабочей версии
RUN cd /tmp && \
    wget https://github.com/ubccr/xdmod/releases/download/v11.0.2-3/xdmod-11.0.2.tar.gz && \
    tar -xzf xdmod-11.0.2.tar.gz && \
    cd xdmod-11.0.2 && \
    ./install --prefix=/usr/share/xdmod && \
    cd .. && rm -rf xdmod-11.0.2*

# Создание пользователя xdmod
RUN groupadd -r xdmod || true && \
    useradd -r -M -c "Open XDMoD" -g xdmod \
    -d /etc/xdmod -s /sbin/nologin xdmod || true

# Настройка PHP для Open XDMoD
RUN echo "date.timezone = Europe/Moscow" >> /etc/php/7.4/apache2/php.ini && \
    echo "memory_limit = 2G" >> /etc/php/7.4/apache2/php.ini && \
    echo "max_execution_time = 300" >> /etc/php/7.4/apache2/php.ini && \
    echo "date.timezone = Europe/Moscow" >> /etc/php/7.4/cli/php.ini && \
    echo "memory_limit = 2G" >> /etc/php/7.4/cli/php.ini

# Включение необходимых модулей Apache
RUN a2enmod rewrite ssl headers php7.4 proxy proxy_fcgi

# Создание директорий
RUN mkdir -p /var/log/xdmod /var/lib/mysql /opt/xdmod-data && \
    chown -R mysql:mysql /var/lib/mysql && \
    chown -R www-data:xdmod /var/log/xdmod && \
    ln -sf /usr/share/xdmod/share/html /usr/share/xdmod/html

# Копирование конфигурационных файлов
COPY config/mysql/my.cnf /etc/mysql/my.cnf
COPY config/apache/xdmod.conf /etc/apache2/sites-available/xdmod.conf
COPY config/xdmod/slurm-helper.conf /etc/xdmod/slurm-helper.conf
COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY scripts/setup-xdmod.sh /usr/local/bin/setup-xdmod.sh
COPY scripts/import-slurm-data.sh /usr/local/bin/import-slurm-data.sh
COPY scripts/init-xdmod.sh /usr/local/bin/init-xdmod.sh
COPY scripts/auto-import.sh /usr/local/bin/auto-import.sh

# Права на выполнение
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/setup-xdmod.sh \
    /usr/local/bin/import-slurm-data.sh /usr/local/bin/init-xdmod.sh \
    /usr/local/bin/auto-import.sh

# Включение сайта XDMoD
RUN a2ensite xdmod && a2dissite 000-default

# Проброс портов
EXPOSE 80 443 3306

# Монтируемые директории
VOLUME ["/var/lib/mysql", "/var/log/slurm", "/var/spool/slurm", "/opt/xdmod-data"]

# Точка входа
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["apache2ctl", "-D", "FOREGROUND"]
