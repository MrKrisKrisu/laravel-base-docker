FROM php:8.1.13-apache
WORKDIR /var/www/html

ENV APACHE_DOCUMENT_ROOT=/var/www/html/public
RUN apt update && \
    apt upgrade -y && \
    apt install -y wait-for-it libicu-dev libzip-dev libpng-dev && \
    docker-php-ext-install intl zip gd pdo pdo_mysql && \
    a2enmod rewrite && \
    a2enmod http2 && \
    sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf && \
    sed -ri -e 's!/var/www/!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf && \
    echo 'memory_limit = 512M' >> /usr/local/etc/php/conf.d/docker-php-memlimit.ini