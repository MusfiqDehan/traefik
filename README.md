# Traefik Setup

This directory contains the Traefik v3 reverse proxy configuration. It is responsible for:

- Terminating HTTPS with a Cloudflare Origin Certificate, with Let's Encrypt fallback
- Redirecting all HTTP traffic to HTTPS
- Discovering backend and frontend containers through Docker labels
- Applying shared middlewares such as security headers, compression, and rate limiting

## Files

- [docker-compose.traefik.yml](docker-compose.traefik.yml): runs the Traefik container and creates the shared `traefik_proxy` network
- [docker-compose.monitoring.yml](docker-compose.monitoring.yml): Prometheus, Grafana, Loki, Promtail, and exporters
- [traefik.yml](traefik.yml): static Traefik configuration
- [dynamic/middlewares.yml](dynamic/middlewares.yml): reusable HTTP middlewares
- [dynamic/tls.yml](dynamic/tls.yml): TLS certificate configuration
- [monitoring/](monitoring/): Prometheus, Loki, Promtail, and Grafana provisioning configs
- [certs/README.md](certs/README.md): Cloudflare origin certificate instructions

## Architecture

Traefik is used as the public entry point for the application. It listens on ports `80` and `443`, forwards requests to services discovered by Docker, and loads additional configuration from the `dynamic/` directory.

The expected flow is:

1. Browser connects to Traefik on port `80` or `443`
2. Port `80` is redirected to `443`
3. Traefik routes the request to the correct container based on labels
4. Shared middlewares are applied from the file provider
5. TLS is served from the Cloudflare origin certificate in `certs/`, or from Let's Encrypt if the origin certificate is not loaded

## Requirements

- Docker and Docker Compose
- A valid Cloudflare Origin Certificate for `musfiqdehan.com` and `*.musfiqdehan.com`, or a Cloudflare API token so Let's Encrypt can issue one
- Backend and frontend services configured to join the `traefik_proxy` network

## DNS Requirements

Wildcard DNS does **not** cover the apex domain. To serve both the landing page and tenant subdomains, create both records:

1. `musfiqdehan.com` → A/AAAA record pointing to your server
2. `*.musfiqdehan.com` → wildcard record pointing to the same server

If you are using Cloudflare proxying, proxy both records to the same origin. If only the wildcard record exists, `https://musfiqdehan.com` will not resolve to your landing page.

Do **not** leave extra A/AAAA/CNAME records for the same hostnames pointing to Hostinger parking, an old VPS, or any other origin. DNS round-robin across mixed targets will make `musfiqdehan.com` and `*.musfiqdehan.com` intermittently load different sites depending on which record the resolver returns.

## Certificate Setup

Traefik supports two certificate sources in this setup:

1. Cloudflare Origin Certificate from [certs/](certs/)
2. Let's Encrypt fallback through a Cloudflare DNS-01 challenge

When [certs/origin.pem](certs/origin.pem) and [certs/origin.key](certs/origin.key) exist, [dynamic/tls.yml](dynamic/tls.yml) loads them as the default wildcard certificate. The production backend and frontend routers also declare the `letsencrypt` certificate resolver, so if that origin certificate is missing or not loaded, Traefik can request a browser-trusted certificate from Let's Encrypt for `musfiqdehan.com` and `*.musfiqdehan.com`.

### Cloudflare Origin Certificate

Traefik expects the following files in [certs/](certs/):

- `origin.pem` for the certificate
- `origin.key` for the private key

To create the certificate:

1. Open Cloudflare Dashboard
2. Go to **SSL/TLS** → **Origin Server**
3. Create a certificate for `musfiqdehan.com` and `*.musfiqdehan.com`
4. Save the certificate as `origin.pem` and the key as `origin.key`

Do not commit the actual certificate files to git.

### Let's Encrypt Fallback

Wildcard certificates require DNS-01 validation. This setup uses Cloudflare's DNS API, so create a Cloudflare API token that can manage DNS records for the `musfiqdehan.com` zone.

Token permissions: **Zone → DNS → Edit** and **Zone → Zone → Read**, scoped to `musfiqdehan.com`.

Then provide it to Traefik as `CF_DNS_API_TOKEN`. You can export it in the shell:

```bash
export CF_DNS_API_TOKEN="your-cloudflare-api-token"
```

Or create a local, ignored env file from the example:

```bash
cp .env.example .env
```

Then edit [.env](.env) with the real token and start Traefik with `--env-file .env`.

The ACME account and issued certificates are stored in the Docker volume `traefik_letsencrypt`, mounted at `/letsencrypt` inside the container.

## Start Traefik

Run Traefik from this directory:

```bash
docker compose -f docker-compose.traefik.yml up -d
```

If using [.env](.env) for the Let's Encrypt fallback token:

```bash
docker compose --env-file .env -f docker-compose.traefik.yml up -d
```

Traefik must be started before the backend, frontend, and monitoring stacks so the shared `traefik_proxy` network exists when those services come up.

Then start application stacks from their respective repositories.

## Monitoring stack (Prometheus, Grafana, Loki)

The monitoring compose file provides metrics, dashboards, and centralized Docker container logs for **all containers on the host** (frontends, backends, databases, Traefik, etc.).

| Service | Role |
|---------|------|
| Prometheus | Scrapes host, container, and Traefik metrics (15-day retention) |
| Grafana | Dashboards at `https://grafana.musfiqdehan.com` |
| Loki + Promtail | Collects stdout/stderr logs from every Docker container (14-day retention) |
| node-exporter | Host CPU, RAM, disk, network |
| cAdvisor | Per-container resource usage |

Prometheus, Loki, and cAdvisor are **not** exposed publicly — only Grafana is routed through Traefik.

On a **12 GB RAM** server, this monitoring stack plus Traefik and your apps is reasonable. Skip self-hosted Sentry (use Sentry Cloud instead) to avoid memory pressure.

### Monitoring prerequisites

1. Traefik running (`traefik_proxy` network exists)
2. Copy and create basic-auth credentials for the Grafana edge:

```bash
htpasswd -cb dynamic/.htpasswd admin 'your-strong-password'
```

3. Set `GRAFANA_ADMIN_PASSWORD` in [.env](.env) (copy from [.env.example](.env.example))

### Start monitoring

```bash
docker compose --env-file .env -f docker-compose.monitoring.yml up -d
```

### Grafana access

- URL: `https://grafana.musfiqdehan.com`
- Traefik basic auth: credentials from `dynamic/.htpasswd`
- Grafana login: `GRAFANA_ADMIN_USER` / `GRAFANA_ADMIN_PASSWORD` from `.env`

Prometheus and Loki datasources are provisioned automatically.

### Recommended dashboards (import in Grafana UI)

- **1860** — Node Exporter Full
- **193** — Docker cAdvisor
- **11462** — Traefik 2.x (compatible with Traefik 3 metrics)

### Log queries (Grafana → Explore → Loki)

```logql
{container_name=~".+"}                              # all containers
{compose_service="backend"}                          # filter by compose service
{container_name=~".*postgres.*|.*redis.*"}           # database containers
```

### Verification

```bash
# From any container on traefik_proxy:
docker run --rm --network traefik_proxy curlimages/curl:latest \
  -s http://prometheus:9090/-/healthy

# Traefik metrics target (after Traefik restart with metrics enabled):
docker run --rm --network traefik_proxy curlimages/curl:latest \
  -s http://traefik:8080/metrics | head
```

## Sentry Cloud (error tracking)

Sentry captures **application errors** (exceptions, stack traces). It does not replace Loki for raw container logs.

**Use [Sentry Cloud](https://sentry.io)** (not self-hosted) on this server. Self-hosted Sentry needs 16 GB+ RAM; with 12 GB, run only Traefik + Prometheus/Grafana/Loki here and send errors to Sentry's hosted service.

No containers or Traefik routes are required for Sentry Cloud — apps send events outbound via the SDK.

### Setup

1. Create an account at [sentry.io](https://sentry.io/signup/)
2. Create an organization and one project per app (Django API, Next.js frontend, NestJS makeover-api)
3. Copy each project's **DSN** from **Settings → Projects → [project] → Client Keys (DSN)**

### Application SDK wiring

Set DSNs in each application's environment (or secrets manager):

| App | Package | Env var |
|-----|---------|---------|
| Django backend | `sentry-sdk[django]` | `SENTRY_DSN`, `SENTRY_ENVIRONMENT=production` |
| Next.js frontend | `@sentry/nextjs` | `NEXT_PUBLIC_SENTRY_DSN` |
| NestJS makeover-api | `@sentry/nestjs` | `SENTRY_DSN` |

DSN format (hosted): `https://<key>@o<org-id>.ingest.<region>.sentry.io/<project-id>`

Example Django settings:

```python
import sentry_sdk

sentry_sdk.init(
    dsn=os.environ["SENTRY_DSN"],
    environment=os.environ.get("SENTRY_ENVIRONMENT", "production"),
    traces_sample_rate=0.1,
)
```

### Startup order (this server)

```bash
# 1. Traefik
docker compose --env-file .env -f docker-compose.traefik.yml up -d

# 2. Monitoring (metrics + logs)
docker compose --env-file .env -f docker-compose.monitoring.yml up -d
```

Sentry Cloud is configured in application repos only — no third compose stack on this host.

## How Routing Works

Traefik uses Docker labels to discover services. Containers must:

- Join the `traefik_proxy` network
- Set `traefik.enable=true`
- Define router rules such as `Host(...)` or `HostRegexp(...)`
- Point the router to the correct service port
- Set `traefik.http.routers.<name>.tls.certresolver=letsencrypt` when Let's Encrypt fallback should be available

Example label set:

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

## Middlewares

The reusable middlewares defined in [dynamic/middlewares.yml](dynamic/middlewares.yml) are:

- `security-headers@file` — HTTPS API/browser traffic
- `adms-http-headers@file` — plain-HTTP ADMS device traffic (no HSTS, `X-Forwarded-Proto: http`)
- `compress@file`
- `api-ratelimit@file`
- `ws-headers@file`
- `redirect-to-https@file`
- `monitoring-basic-auth@file` — Traefik basic auth for Grafana (`dynamic/.htpasswd`)

## ADMS device routing (HTTP-only)

Biometric devices (ZKTeco iClock) poll over **plain HTTP on port 80**. Browsers and API clients use **HTTPS on port 443**.

```
Device → http://{host}/iclock/cdata?SN=...  → Traefik :80 (backend-adms router)
       → Daphne :8021 → django-tenants → IclockCdataAPIView

Browser → https://{host}/api/v1/...         → Traefik :443 (backend-api router, rate limited)
```

### Router split (backend docker-compose.prod.yml labels)

| Router | Entrypoint | Paths | Rate limit |
|--------|------------|-------|------------|
| `backend-api` | websecure (443) | `/api`, `/admin`, `/media`, `/static` | Yes |
| `backend-ws` | websecure (443) | `/ws` | No |
| `backend-adms` | **web (80)** | `/iclock`, `/cdata`, `/getrequest`, `/devicecmd` | No |
| `backend-custom-*` | same pattern | custom tenant domains | same |

HTTPS ADMS paths are **not routed** — reconfigure devices to use `http://` URLs.

### Device URL format

Configure device firmware or `AccessDeviceEndpoint.base_url`:

```
http://{tenant}.musfiqdehan.com/iclock
http://{custom-domain}/iclock
http://musfiqdehan.com/iclock
```

Supported endpoints (with or without trailing slash):

- `/iclock/cdata` or `/cdata` — heartbeat + attendance push
- `/iclock/getrequest` or `/getrequest` — command poll
- `/iclock/devicecmd` or `/devicecmd` — command ack

### Smoke test

```bash
# Must succeed (HTTP)
curl -v "http://tenant.musfiqdehan.com/iclock/cdata?SN=YOUR_SN"

# Must NOT reach ADMS handlers after migration (HTTPS)
curl -v "https://tenant.musfiqdehan.com/iclock/cdata?SN=YOUR_SN"
```

### Cloudflare note

If Cloudflare proxies your domain, ensure port 80 is allowed for ADMS paths (DNS-only / grey cloud for device hostnames, or a Page Rule allowing HTTP on `/iclock/*`).

### Security Headers

`security-headers@file` adds response hardening headers and forces HTTPS-related metadata for downstream apps such as Django.

### Compression

`compress@file` enables response compression for supported content types.

### Rate Limiting

`api-ratelimit@file` applies a simple request limit intended for API protection. The current values are:

- Average: `100`
- Burst: `50`
- Period: `1s`

## Static Configuration

The [traefik.yml](traefik.yml) file configures:

- Logging in common format
- HTTP to HTTPS redirection
- Trusted Cloudflare proxy IP ranges on the `websecure` entry point
- Docker provider discovery with `exposedByDefault: false`
- File provider watching the `dynamic/` directory
- Let's Encrypt ACME resolver using Cloudflare DNS-01 challenge
- Prometheus metrics on internal entrypoint `:8080` (scraped by monitoring stack)

The trusted Cloudflare IP ranges are important because they allow Traefik to preserve the correct forwarded headers when the site is behind Cloudflare.

## TLS Configuration

[dynamic/tls.yml](dynamic/tls.yml) loads the Cloudflare Origin Certificate from [certs/](certs/) as the default wildcard certificate.

This ensures that:

- HTTPS routes have a valid certificate immediately on startup
- Wildcard host rules work correctly for subdomains

The `letsencrypt` ACME resolver in [traefik.yml](traefik.yml) is attached to the backend and frontend production routers. Their `tls.domains` labels explicitly request `musfiqdehan.com` and `*.musfiqdehan.com`, which is required because Traefik cannot infer ACME domains from a regex-only host rule.

## Troubleshooting

- If the browser shows a certificate warning, confirm `origin.pem` and `origin.key` exist in [certs/](certs/) and match the Cloudflare Origin Certificate, or confirm `CF_DNS_API_TOKEN` is set so the Let's Encrypt fallback can issue a certificate
- If `https://musfiqdehan.com` does not open but subdomains do, add an apex DNS record for `musfiqdehan.com`; the wildcard record does not match the root domain
- If `musfiqdehan.com` or a tenant subdomain sometimes shows a Hostinger parked page, remove every stale A/AAAA/CNAME for that hostname that does not point to the Traefik server. Mixed records can silently round-robin between your app and Hostinger's parking edge.
- If Let's Encrypt fails, check Traefik logs for ACME errors and confirm the Cloudflare token can manage DNS records for the `musfiqdehan.com` zone
- If a service is not reachable, verify it is attached to the `traefik_proxy` network
- If Traefik cannot find a container, confirm the container has `traefik.enable=true`
- If forwarded headers look wrong in the backend, confirm requests are passing through the trusted Cloudflare IP ranges in [traefik.yml](traefik.yml)
- If Grafana returns 401 at the edge, confirm `dynamic/.htpasswd` exists and matches your Traefik basic-auth credentials
- If Loki shows no logs, confirm Promtail can read `/var/lib/docker/containers` and the Docker socket
- If Prometheus shows Traefik target down, restart Traefik after enabling `metrics.prometheus` in [traefik.yml](traefik.yml)

## Notes

- The Traefik dashboard is disabled in production via `api.dashboard: false`
- Docker socket access is mounted read-only
- `web` redirects browser/frontend traffic to `websecure`; ADMS device paths on port 80 are excluded from redirect
