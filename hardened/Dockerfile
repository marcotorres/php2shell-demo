# Servidor PHP endurecido — misma app, configuración segura + guardia tipo-WAF.
# Usa la rama 8.4 más reciente (ya parcheada: >= 8.4.27).
FROM php:8.4-apache

RUN apt-get update && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

COPY php.ini /usr/local/etc/php/conf.d/zz-demo.ini
COPY apache-demo.conf /etc/apache2/conf-enabled/demo.conf
COPY www/ /var/www/html/

EXPOSE 80
