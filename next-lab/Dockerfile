# Un despliegue Next.js de juguete para la escena post-explotación.
# Fijamos Next 14.2.33, ANTERIOR al parche del RCE de sharp/SVG (CVE-2026-96889,
# corregido en 15.5.28 / 16.4.1). O sea: "vulnerable" en el sentido del post.
#
# CONTRASTE con node-lab: aquí SÍ creamos un usuario sin privilegios (`nextjs`,
# uid 1001) y corremos con él, tal y como recomienda la guía oficial de Next.
# El mismo tipo de RCE, en este montaje, NO entrega root.
FROM node:22-slim

# neofetch + procps para que la escena se vea como en los videos.
RUN apt-get update \
    && apt-get install -y --no-install-recommends procps ca-certificates \
    && (apt-get install -y --no-install-recommends neofetch || true) \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Dependencias primero (mejor caché de capas).
COPY package.json ./
RUN npm install --no-audit --no-fund

# La app y su build.
COPY . .
RUN npm run build

# Usuario sin privilegios, como manda la buena práctica de Next.
RUN groupadd -g 1001 nextjs \
    && useradd -u 1001 -g 1001 -m nextjs \
    && chown -R nextjs:nextjs /app
USER nextjs

EXPOSE 3000
CMD ["npm", "start"]
