FROM php:8.2-apache
RUN docker-php-ext-install mysqli && docker-php-ext-enable mysqli
# Copiar todos los archivos PHP al directorio de Apache
COPY . /var/www/html/
EXPOSE 80
