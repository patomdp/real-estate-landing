# Guía paso a paso — Landing Page + GitHub + Vercel

Documentación del proceso completo para crear, versionar y desplegar esta landing page, más instrucciones para activar el **deploy automático** y un **plan B con Netlify**.

---

## 1. Creación de la landing page

Sitio estático puro: un solo `index.html` con CSS embebido. Sin frameworks, sin `package.json`, sin build step.

```
real-estate-landing/
├── index.html      # Landing completa (HTML + CSS)
├── README.md
├── .gitignore      # Ignora .vercel, node_modules, .DS_Store
└── GUIA-DEPLOY.md  # Esta guía
```

**Ventaja**: al no haber build, cualquier plataforma (Vercel, Netlify, GitHub Pages, Cloudflare Pages) lo sirve tal cual, sin configuración.

## 2. Inicializar el repositorio git

```bash
cd real-estate-landing
git init -b main
git add -A
git commit -m "Landing page para empresa de real estate"
```

## 3. Crear el repositorio en GitHub y subir el código

Opción usada aquí (API REST con token almacenado por git credential manager):

```bash
# Crear el repo remoto
curl -X POST "https://api.github.com/user/repos" \
  -H "Authorization: token <TU_TOKEN>" \
  -H "Accept: application/vnd.github+json" \
  -d '{"name":"real-estate-landing","description":"Landing page real estate","private":false}'

# Conectar y subir
git remote add origin https://github.com/patomdp/real-estate-landing.git
git push -u origin main
```

Alternativa más simple si tienes GitHub CLI instalado:

```bash
gh repo create real-estate-landing --public --source=. --push
```

## 4. Deploy a Vercel (CLI)

```bash
# Requiere estar logueado: npx vercel login
npx vercel deploy --prod --yes
```

El flag `--yes` acepta la configuración por defecto y vincula la carpeta al proyecto de Vercel (crea la carpeta `.vercel/`, que está en el `.gitignore`).

Para verificar el estado y las URLs:

```bash
npx vercel ls                    # Lista los deployments
npx vercel inspect <url-deploy>  # Muestra aliases y detalles
```

## 5. Resultado

| Recurso | URL |
|---|---|
| Repositorio GitHub | https://github.com/patomdp/real-estate-landing |
| **Sitio en producción** | **https://real-estate-landing-sable.vercel.app** |
| Alias del equipo | https://real-estate-landing-patricio-marianos-projects.vercel.app |
| Cuenta Vercel | `malawebsoficial-9333` (scope: patricio-marianos-projects) |

Estado verificado: HTTP 200, deployment `● Ready` en Production.

---

## 6. Deploy automático de GitHub a Vercel ✅ ACTIVADO

> **ESTADO ACTUAL**: El deploy automático **ya está activo** en este proyecto. Se activó con `npx vercel git connect --yes` (Vercel de hecho ya había vinculado el repo automáticamente al detectar el remote de git durante el primer deploy con CLI). Verificado vía API: `link.type = github`, repo `patomdp/real-estate-landing`, rama de producción `main`.
>
> Cada `git push` a `main` despliega automáticamente a producción. No hace falta volver a ejecutar `vercel deploy`.

Las siguientes instrucciones quedan como referencia por si hay que reconectarlo o repetirlo en otro proyecto:

### Opción A — Desde el CLI (rápida)

```bash
# Ejecutar dentro de la carpeta del proyecto (ya vinculada a Vercel)
npx vercel git connect
```

Esto conecta el repo `patomdp/real-estate-landing` al proyecto de Vercel. Puede pedir instalar la GitHub App de Vercel la primera vez (autorizar en el navegador).

### Opción B — Desde el dashboard de Vercel

1. Entrar a https://vercel.com y abrir el proyecto **real-estate-landing**.
2. Ir a **Settings → Git**.
3. Clic en **Connect Git Repository** → elegir **GitHub** → seleccionar `patomdp/real-estate-landing`.
4. Si es la primera vez, autorizar la **Vercel GitHub App** con acceso al repo.

### Comportamiento una vez conectado

- **Push a `main`** → deploy automático a **Producción** (la URL estable se actualiza sola).
- **Push a cualquier otra rama / Pull Request** → deploy de **Preview** con URL propia (ideal para revisar cambios antes de mergear).
- Vercel comenta en cada PR con el link del preview.

### Verificar que funciona

```bash
# Hacer un cambio trivial y push
git commit --allow-empty -m "test: verificar deploy automático"
git push
# Luego revisar: npx vercel ls  → debe aparecer un deployment nuevo con origen "github"
```

### Verificar la conexión por API (avanzado)

```bash
# El token del CLI está en el auth.json de com.vercel.cli (ruta según SO)
curl -s "https://api.vercel.com/v9/projects/<PROJECT_ID>?teamId=<TEAM_ID>" \
  -H "Authorization: Bearer <TOKEN>"
# El campo "link" debe mostrar: {"type": "github", "org": "patomdp", "repo": "real-estate-landing", ...}
```

- **Project ID de este proyecto**: `prj_msszlJVywKLCDdfFd32zJAFGtV0l`

---

## 7. Plan B — Deploy en Netlify (si Vercel da problemas)

Al ser un sitio estático sin build, migrar es trivial:

### Netlify por CLI

```bash
npx netlify-cli login                 # Autenticarse (abre navegador)
npx netlify-cli deploy --prod --dir . # Deploy de la carpeta actual
```

### Netlify con deploy automático desde GitHub

1. Entrar a https://app.netlify.com → **Add new site → Import an existing project**.
2. Conectar GitHub y elegir `patomdp/real-estate-landing`.
3. Configuración de build: dejar **Build command vacío** y **Publish directory = `.`** (raíz).
4. Cada push a `main` desplegará automáticamente.

### Otras alternativas igual de válidas

| Plataforma | Cómo |
|---|---|
| **GitHub Pages** | Settings → Pages → Deploy from branch `main` / root. Gratis, sin cuenta extra. |
| **Cloudflare Pages** | dash.cloudflare.com → Pages → conectar el repo. CDN muy rápido. |

Cualquiera de estas sirve el mismo `index.html` sin cambios en el código.

---

## 8. Dominio personalizado: subdominio de Cloudflare → Vercel

Caso: apuntar `realestate.malawebs.com` (DNS en Cloudflare) al proyecto de Vercel.

### Proceso manual (lo que se hizo la primera vez)

1. **En Vercel**: proyecto → Settings → Domains → Add → `realestate.malawebs.com`. Vercel muestra el registro requerido, por ejemplo:
   - Tipo: `CNAME` | Nombre: `realestate` | Valor: `868e145319363805.vercel-dns-017.com.`
2. **En Cloudflare**: dash → zona `malawebs.com` → DNS → Add record → crear ese CNAME.
   - ⚠️ **Proxy: Disabled (DNS only, nube gris)** — con el proxy naranja activado la verificación de Vercel falla o el SSL da problemas.
3. Volver a Vercel y clic en **Refresh** hasta que pase de "Invalid Configuration" a verificado.
4. Esperar la emisión del certificado SSL (1–10 minutos típicamente).

### Proceso automatizado (script incluido en el repo)

El script [`scripts/setup-domain.sh`](scripts/setup-domain.sh) hace los 4 pasos por API, de punta a punta e idempotente (se puede re-ejecutar sin romper nada):

```bash
CLOUDFLARE_API_TOKEN=<token> ./scripts/setup-domain.sh realestate.malawebs.com
# Con otro proyecto: agregar el project-id como segundo argumento
```

Qué hace por dentro:

1. `POST https://api.vercel.com/v10/projects/{id}/domains` → agrega el dominio al proyecto.
2. `GET https://api.vercel.com/v6/domains/{domain}/config` → obtiene el CNAME recomendado (no hay que copiarlo a mano del dashboard).
3. `GET /zones?name={apex}` + `POST /zones/{zone}/dns_records` en la API de Cloudflare → crea el CNAME con `"proxied": false`.
4. Polling hasta que el dominio queda `verified: true` y responde HTTP 200 con SSL.

### Credenciales necesarias

| Credencial | De dónde sale | Permisos |
|---|---|---|
| Token Vercel | Lo lee automáticamente del `auth.json` del CLI (`vercel login`) | — |
| `CLOUDFLARE_API_TOKEN` | dash.cloudflare.com → My Profile → API Tokens → Create Token → plantilla **"Edit zone DNS"** | `Zone.DNS:Edit` limitado a la zona `malawebs.com` |

> **Nota para el futuro skill**: con estas dos credenciales disponibles, todo el flujo (crear repo → push → deploy Vercel → conectar Git → subdominio Cloudflare) queda 100% automatizable por API/CLI, sin tocar ningún dashboard. Este script es la pieza que faltaba; el resto ya está documentado en las secciones 2–6.
