# Un servidor Node.js de juguete para la escena post-explotación.
# Fijamos una versión ANTERIOR al parche del fallo Brotli (CVE-2026-111497),
# que se corrigió en 24.22.1. Aquí usamos 24.5 a propósito.
#
# OJO, y es el punto de la escena: NO ponemos `USER`. El proceso corre como
# ROOT, que es el descuido más habitual en imágenes Node del mundo real. Por
# eso el RCE de Brotli, en un montaje así, entrega una shell de root.
FROM node:24.5-slim

# neofetch + procps para que la escena se vea como en los videos.
RUN apt-get update \
    && apt-get install -y --no-install-recommends procps ca-certificates \
    && (apt-get install -y --no-install-recommends neofetch || true) \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY server.js package.json ./

EXPOSE 3000
CMD ["node", "server.js"]
