// Servidor Node mínimo para el laboratorio. Representa "una API Node cualquiera"
// que, como casi todas, acepta cuerpos comprimidos con Brotli (Content-Encoding: br).
//
// IMPORTANTE: aquí NO hay exploit del fallo Brotli (CVE-2026-111497) ni nada que
// se le parezca. Este server solo existe para que el contenedor esté "vivo" y la
// escena pueda entrar con `docker exec`, igual que haríamos en el de PHP.
const http = require('node:http');

const server = http.createServer((req, res) => {
  if (req.url === '/healthz') {
    res.writeHead(200, { 'Content-Type': 'text/plain' });
    res.end('ok');
    return;
  }
  res.writeHead(200, { 'Content-Type': 'text/plain; charset=utf-8' });
  res.end('API Node de demo · acepta Content-Encoding: br · laboratorio php2shell-demo\n');
});

server.listen(3000, () => {
  console.log('node-lab escuchando en :3000 (demo, sin exploit)');
});
