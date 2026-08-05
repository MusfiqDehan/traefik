---
icon: lucide/route
---

# Routing & ADMS

## How Traefik discovers services

Containers must:

- Join the `traefik_proxy` network
- Set `traefik.enable=true`
- Define router rules (`Host(...)`, `HostRegexp(...)`)
- Point to the correct backend port
- Optionally set `tls.certresolver=letsencrypt` with explicit `tls.domains`

Example labels:

```yaml
labels:
  - traefik.enable=true
  - traefik.http.routers.api.rule=Host(`api.musfiqdehan.com`)
  - traefik.http.routers.api.entrypoints=websecure
  - traefik.http.routers.api.tls=true
  - traefik.http.routers.api.tls.certresolver=letsencrypt
  - traefik.http.services.api.loadbalancer.server.port=8000
  - traefik.http.routers.api.middlewares=security-headers@file,compress@file
```

For UK tenant subdomains, use `HostRegexp` in application compose files, e.g. `^[a-z0-9][a-z0-9-]*\.mrdfit\.uk$`.

For nested shop / fitness tenants (`client1.shop.musfiqdehan.com`, `client1.fitness.musfiqdehan.com`), use a HostRegexp plus explicit Let's Encrypt domains (origin `*.musfiqdehan.com` does not cover two labels):

```yaml
labels:
  - traefik.enable=true
  - traefik.docker.network=traefik_proxy
  # Frontend (example — shop; swap shop→fitness for the fitness stack)
  - traefik.http.routers.shop-frontend.rule=HostRegexp(`^([a-z0-9][a-z0-9-]*\.)?shop\.musfiqdehan\.com$`) && !PathPrefix(`/api`) && !PathPrefix(`/ninja`) && !PathPrefix(`/media`) && !PathPrefix(`/static`) && !PathPrefix(`/ws`) && !PathPrefix(`/iclock`)
  - traefik.http.routers.shop-frontend.entrypoints=websecure
  - traefik.http.routers.shop-frontend.tls=true
  - traefik.http.routers.shop-frontend.tls.certresolver=letsencrypt
  - traefik.http.routers.shop-frontend.tls.domains[0].main=shop.musfiqdehan.com
  - traefik.http.routers.shop-frontend.tls.domains[0].sans=*.shop.musfiqdehan.com
  - traefik.http.routers.shop-frontend.middlewares=security-headers@file,compress@file
  - traefik.http.services.shop-frontend.loadbalancer.server.port=3000
  # Backend API (example)
  - traefik.http.routers.shop-api.rule=HostRegexp(`^([a-z0-9][a-z0-9-]*\.)?shop\.musfiqdehan\.com$`) && (PathPrefix(`/api`) || PathPrefix(`/ninja`) || PathPrefix(`/media`) || PathPrefix(`/static`))
  - traefik.http.routers.shop-api.entrypoints=websecure
  - traefik.http.routers.shop-api.tls=true
  - traefik.http.routers.shop-api.tls.certresolver=letsencrypt
  - traefik.http.routers.shop-api.tls.domains[0].main=shop.musfiqdehan.com
  - traefik.http.routers.shop-api.tls.domains[0].sans=*.shop.musfiqdehan.com
  - traefik.http.routers.shop-api.middlewares=security-headers@file,compress@file,api-ratelimit@file
  - traefik.http.services.shop-api.loadbalancer.server.port=8000
```

Also allow those hosts in the app (`ALLOWED_HOSTS` / Next.js host checks) and join the `traefik_proxy` external network.

## Middlewares

Defined in [dynamic/middlewares.yml](../dynamic/middlewares.yml). Reference as `<name>@file` in labels.

| Middleware | Purpose |
|------------|---------|
| `security-headers@file` | HSTS, XSS protection, `X-Forwarded-Proto: https` |
| `adms-http-headers@file` | Plain HTTP for devices — no HSTS, `X-Forwarded-Proto: http` |
| `compress@file` | Response compression |
| `api-ratelimit@file` | 100 req/s average, burst 50 |
| `ws-headers@file` | WebSocket upgrade passthrough |
| `redirect-to-https@file` | HTTP → HTTPS scheme redirect |
| `monitoring-basic-auth@file` | Basic auth for Grafana edge |

## ADMS device routing (HTTP-only)

ZKTeco iClock biometric devices poll over **plain HTTP on port 80**. Browsers and APIs use **HTTPS on port 443**.

```
Device  → http://{host}/iclock/cdata?SN=...  → Traefik :80 → Daphne :8021
Browser → https://{host}/api/v1/...          → Traefik :443 (rate limited)
```

### Router split (backend labels)

| Router | Entrypoint | Paths | Rate limit |
|--------|------------|-------|------------|
| `backend-api` | websecure (443) | `/api`, `/ninja`, `/media`, `/static` | Yes |
| `backend-ws` | websecure (443) | `/ws` | No |
| `backend-adms` | **web (80)** | `/iclock`, `/cdata`, `/getrequest`, `/devicecmd` | No |
| `backend-custom-*` | same pattern | custom tenant domains | same |

HTTPS ADMS paths are intentionally **not** routed.

### Device URL format

```
http://{tenant}.mrdfit.uk/iclock
http://{tenant}.mrderp.uk/iclock
http://musfiqdehan.com/iclock
http://{custom-domain}/iclock
```

Supported endpoints:

- `/iclock/cdata` or `/cdata` — heartbeat + attendance
- `/iclock/getrequest` or `/getrequest` — command poll
- `/iclock/devicecmd` or `/devicecmd` — command acknowledgement

### Smoke test

```bash
curl -v "http://tenant.mrdfit.uk/iclock/cdata?SN=YOUR_SN"    # must succeed
curl -v "https://tenant.mrdfit.uk/iclock/cdata?SN=YOUR_SN"   # must not reach ADMS
```

### Cloudflare

If domains are proxied, ensure port 80 reaches the origin for device hostnames (grey-cloud device subdomains, or rules allowing HTTP on `/iclock/*`).

## Port 80 selective redirect

[dynamic/redirects.yml](../dynamic/redirects.yml) redirects `/api`, `/ninja`, `/media`, `/static`, and `/ws` to HTTPS on platform hosts while leaving ADMS paths on HTTP.
