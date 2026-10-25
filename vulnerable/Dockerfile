# Servidor PHP mal configurado — ilustra la SUPERFICIE de reconocimiento.
# Se fija una versión ANTERIOR al parche (8.4.27) a propósito, para el triaje.
FROM php:8.4.1-apache

# curl para el healthcheck; procps/neofetch para la escena de post-explotación.
# neofetch puede no estar en algunas bases (Debian trixie lo retiró): no rompemos
# el build si falta — el script de la escena tiene un fallback.
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl procps ca-certificates \
    && (apt-get install -y --no-install-recommends neofetch || true) \
    && rm -rf /var/lib/apt/lists/*

COPY php.ini /usr/local/etc/php/conf.d/zz-demo.ini
COPY apache-demo.conf /etc/apache2/conf-enabled/demo.conf
COPY www/ /var/www/html/

EXPOSE 80
