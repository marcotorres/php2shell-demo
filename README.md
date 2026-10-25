# php2shell-demo

Un laboratorio pequeño para **entender con los ojos** —no con la imaginación— la semana de
octubre de 2026 en que crujió medio stack web: tres RCE críticos seguidos, uno por capa.

El protagonista es **PHP2Shell**: dos vulnerabilidades críticas (CVSS 9.2) de ejecución
remota de código **sin autenticar** en PHP 5.4 → 8.5 —**CVE-2026-109618** y
**CVE-2026-109619**—. Mucha gente leyó el titular; poca llegó a *ver* por qué un servidor es
un blanco y otro, con la misma versión, no lo es. Y como esa misma semana cayeron sus dos
"primas" —**Node.js** (fallo de Brotli, CVE-2026-111497) y **Next.js** (fallo de `sharp`
al procesar SVG, CVE-2026-96889)—, el laboratorio las trae también, porque juntas cuentan una
lección que por separado se pierde.

> ### ⚠️ Léelo antes de clonar
> Aquí **no vas a encontrar un exploit**. Ni payloads de RCE, ni web shells, ni nada que
> apunte a servidores ajenos. Lo que hace es levantar contenedores en *tu* máquina y
> **enseñarte la superficie** que buscan los escáneres y el **radio de daño** de un
> compromiso —para que aprendas a cerrar la una y a reducir el otro—. Es una herramienta para
> **defender**, no para atacar. Úsala solo sobre lo tuyo.

📖 Es el laboratorio del artículo: **https://marcotorres.pe/blog/php2shell-vulnerabilidad-php-rce**

---

## La idea en una frase

Las tres vulnerabilidades son el mismo tipo de bicho —un fallo de memoria en código nativo,
por debajo de *tu* código— y comparten la misma cura: **actualizar**. Pero lo que de verdad
enseña este laboratorio es el **matiz defensivo** que casi nadie cuenta:

- **que seas vulnerable no es lo mismo que seas explotable** (PHP): hace falta que tu
  servidor regale varias precondiciones a la vez; y
- **cuánto duele un compromiso lo decides tú**, con el usuario que corre el proceso (Node vs. Next).

## Qué hay en la caja

### 1) El lab de PHP — "¿soy un blanco?"

Dos servidores PHP gemelos salvo en una cosa: la configuración. Un auditor los mira y te los
pone lado a lado.

| Servicio     | Qué papel hace                                            | Puerto |
|--------------|----------------------------------------------------------|--------|
| `vulnerable` | PHP 8.4.1 dejado a su suerte (versión sin parchear)       | 8091   |
| `hardened`   | PHP 8.4 al día + configuración seria + guardia tipo-WAF   | 8092   |
| `triage`     | El auditor: mira a los dos y te los pone lado a lado      | —      |

El `vulnerable` reúne a propósito todo lo que un escáner reza por encontrar:
`display_errors=On`, `expose_php=On`, `session.upload_progress.enabled=1`,
`session.use_strict_mode=0` y un `memory_limit` de juguete. El `hardened` cierra todo eso y,
de regalo, lleva una guardia (que en el mundo real vive en tu WAF) que corta la sonda antes
de que haga nada.

### 2) Las escenas — "¿cuánto duele si entran?"

Tres recreaciones del *plano* que se ve en los videos —la shell después de un compromiso—,
una por stack. La gracia no es la shell: es **el usuario con el que corre cada proceso**.

| Escena                 | Stack   | CVE              | Corre como…               | Lección                         |
|------------------------|---------|------------------|---------------------------|---------------------------------|
| `demo-shell.sh`        | PHP     | 2026-109618/619  | `www-data`                | el usuario de Apache/PHP        |
| `demo-shell-node.sh`   | Node.js | 2026-111497      | `root` 😱                 | el descuido más común y el peor |
| `demo-shell-next.sh`   | Next.js | 2026-96889       | `nextjs` (sin privilegios)| la buena práctica: daño acotado |

> **Importante:** ninguna escena explota nada. Las líneas del "lanzamiento del exploit" son
> **teatro** (texto en pantalla, no código que corra). La shell *sí es real*, pero se abre con
> `docker exec` sobre tu propio contenedor —sin exploit de por medio—. Es la misma vista que
> tendría un atacante tras un compromiso, mostrada sin repartir ningún arma.

## Lo que necesitas

- **Docker con Compose v2** (el comando es `docker compose`, con espacio, no `docker-compose`).
- Linux, macOS o Windows con WSL2. Cualquiera sirve.

## Arranque rápido

```bash
git clone https://github.com/marcotorres/php2shell-demo.git
cd php2shell-demo
chmod +x run.sh
./run.sh
```

Y ya. `run.sh` construye las imágenes de PHP, espera a que respondan, lanza la auditoría y
**recoge todo al terminar**. Verás una comparación a dos colores: el servidor flojo en rojo,
el blindado en verde. Esa pantalla es, básicamente, el artículo resumido.

¿Prefieres ir a mano, o cambiar los puertos si los tienes ocupados?

```bash
docker compose up -d --build vulnerable hardened
docker compose run --rm triage               # la auditoría
docker compose down
# o con otros puertos:
VULN_PORT=9001 HARD_PORT=9002 ./run.sh
```

Y si te pica la curiosidad, ábrelos en el navegador: el flojo en http://localhost:8091 y el
blindado en http://localhost:8092.

## Las escenas (opcional, pero son lo más vistoso)

Córrelas en este orden para que la lección se arme sola:

```bash
chmod +x demo-shell.sh demo-shell-node.sh demo-shell-next.sh
./demo-shell.sh        # PHP  → shell como www-data
./demo-shell-node.sh   # Node → shell como ROOT (se lo lleva todo)
./demo-shell-next.sh   # Next → shell como nextjs (daño acotado)
```

Mira el `uid=` del primer comando de cada una: `www-data`, luego `root`, luego `nextjs`.
Ahí está el post entero. ¿Las quieres sin las pausas dramáticas? Ponles `SPEED=0` delante.

---

## 🛡️ Cómo usar esto para proteger tu sitio

El laboratorio no es un adorno: es un guion. Cada escena te muestra un problema; aquí tienes
el paso a paso para cerrarlo en tu propia infraestructura, **primero PHP, luego Node, luego
Next**.

### Paso 1 · PHP — cierra la superficie y aplica la cura

1. **Mira lo que ve un escáner.** Corre `./run.sh` y fíjate en qué delata al servidor flojo
   (errores visibles, `phpinfo`, versión expuesta, la sonda reflejada). Eso es exactamente lo
   que un atacante busca en el tuyo.
2. **Comprueba tu versión — y entiende el número.** `php -v`. El parche salió **una vez por
   cada rama con soporte**; sube al que te toca (o superior dentro de esa misma rama):
   - PHP **8.5.x → 8.5.12** · **8.4.x → 8.4.27** · **8.3.x → 8.3.36** · **8.2.x → 8.2.35**
   - ¿En **8.1 o anterior**? Está en fin de vida: no hay parche, toca **migrar**.
3. **Endurece tu `php.ini`** (reduce la superficie que delata tu servidor):
   ```ini
   display_errors = Off                  ; nunca filtres errores al cliente
   log_errors = On                       ; pero sí a tus logs
   expose_php = Off                      ; sin X-Powered-By delatando la versión
   session.use_strict_mode = 1           ; rechaza PHPSESSID que tú no emitiste
   session.upload_progress.enabled = 0   ; apaga la vía confirmada del CVE
   file_uploads = Off                    ; si no subes archivos, ciérralo
   post_max_size = 1M                    ; y limita el multipart al mínimo
   upload_max_filesize = 1M
   ```
   Compara tu resultado con el servidor `hardened` del laboratorio.
4. **Pon un WAF al frente** mientras parcheas toda tu flota. Es contención, no cura: el parche
   del paso 2 es lo único que cierra el agujero.
5. **Vigila los logs**: errores de memoria (OOM), ráfagas de 500, `multipart` enormes, o el
   marcador `PHP_SESSION_UPLOAD_PROGRESS`.

### Paso 2 · Node.js — parchea y **no corras como root**

1. **Mira el daño.** Corre `./demo-shell-node.sh` y fíjate en el `uid=0(root)`. Un fallo del
   runtime, en un contenedor que corre como root, entrega las llaves de todo.
2. **Actualiza Node** a una versión parcheada: **22.23.4 / 24.22.1 / 26.12.1** (o superior).
   Node 20.x y anteriores están en fin de vida.
3. **Deja de correr como root.** Añade un usuario sin privilegios a tu imagen —es una línea—:
   ```dockerfile
   # ...tu build...
   USER node        # la imagen oficial de Node ya trae el usuario 'node'
   CMD ["node", "server.js"]
   ```
4. **Desconfía de lo que descomprimes.** El fallo entra por datos **Brotli** de fuera
   (`Content-Encoding: br`, respuestas de `fetch`, frames de WebSocket): trátalos como no
   confiables.

### Paso 3 · Next.js — parchea (y mira por qué ya ibas bien)

1. **Mira el contraste.** Corre `./demo-shell-next.sh`: `uid=1001(nextjs)` y no puede escribir
   ni en `/etc`. El mismo tipo de fallo que en Node, pero el daño queda **acotado** solo por
   el usuario.
2. **Actualiza Next** a una versión parcheada: **15.5.28 / 16.4.1** (o superior). Tapa el RCE
   de `sharp` al procesar SVG, un segundo RCE en `use cache` y un DoS en Server Actions.
3. **Mantén la buena práctica** que ya hace el `next-lab`: despliega con un usuario sin
   privilegios (`USER nextjs`). Es gratis y te ahorra el peor día.
4. **Cuida la optimización de imágenes.** Si generas imágenes a partir de entrada que no
   controlas (p. ej. `next/og` con datos externos), valídala; ahí vivía el fallo de `sharp`.

### El patrón que se repite

Parchea lo que heredas, corre cada servicio con **el mínimo privilegio**, y desconfía de todo
lo que **descomprimes o transformas** (Brotli, SVG, `multipart`). Esas tres costumbres te
cubren las tres grietas —y las de la próxima semana.

---

## Cómo trabaja el auditor

1. **Versión y firma.** Lee la cabecera `X-Powered-By` y compara con el parche oficial.
2. **Precondiciones.** Consulta un endpoint de instrumentación del laboratorio (`/triage.php`,
   que un servidor de verdad *no* tendría) para enseñarte la configuración de cada uno.
3. **Reconocimiento.** Manda una sonda `multipart` inofensiva con un marcador
   `PHP_SESSION_UPLOAD_PROGRESS=MARKER_xxxx`. El flojo lo refleja (y filtra un Fatal error por
   OOM); el blindado responde `403` sin soltar una pista.

## Para dejarlo todo limpio

```bash
docker compose --profile tools --profile scenes down --rmi local --remove-orphans
```

---

## Uso responsable

Esto es material educativo, pensado para administradores y desarrolladores que quieren
**proteger** sus propios sitios. Úsalo para aprender y para defender. No lo apuntes a sistemas
que no sean tuyos —ni se te ocurra—.
