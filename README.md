# Traefik Setup

This directory contains the Traefik v3 reverse proxy configuration. It is responsible for:

- Terminating HTTPS with a Cloudflare Origin Certificate, with Let's Encrypt fallback
- Redirecting all HTTP traffic to HTTPS
- Discovering backend and frontend containers through Docker labels
- Applying shared middlewares such as security headers, compression, and rate limiting

## Files

- [docker-compose.traefik.yml](docker-compose.traefik.yml): runs the Traefik container and creates the shared `traefik_proxy` network
- [traefik.yml](traefik.yml): static Traefik configuration
- [dynamic/middlewares.yml](dynamic/middlewares.yml): reusable HTTP middlewares
- [dynamic/tls.yml](dynamic/tls.yml): TLS certificate configuration
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
- A valid Cloudflare Origin Certificate for `fitssort.com` and `*.fitssort.com`, or a Hostinger API token so Let's Encrypt can issue one
- Backend and frontend services configured to join the `traefik_proxy` network

## DNS Requirements

Wildcard DNS does **not** cover the apex domain. To serve both the landing page and tenant subdomains, create both records:

1. `fitssort.com` → A/AAAA record pointing to your server
2. `*.fitssort.com` → wildcard record pointing to the same server

If you are using Cloudflare proxying, proxy both records to the same origin. If only the wildcard record exists, `https://fitssort.com` will not resolve to your landing page.

Do **not** leave extra A/AAAA/CNAME records for the same hostnames pointing to Hostinger parking, an old VPS, or any other origin. DNS round-robin across mixed targets will make `fitssort.com` and `*.fitssort.com` intermittently load different sites depending on which record the resolver returns.

## Certificate Setup

Traefik supports two certificate sources in this setup:

1. Cloudflare Origin Certificate from [certs/](certs/)
2. Let's Encrypt fallback through a Hostinger DNS-01 challenge

When [certs/origin.pem](certs/origin.pem) and [certs/origin.key](certs/origin.key) exist **and the certificate blocks in** [dynamic/tls.yml](dynamic/tls.yml) **are uncommented**, Traefik loads them as the default wildcard certificate. The production backend and frontend routers also declare the `letsencrypt` certificate resolver, so if that origin certificate is missing or not loaded, Traefik can request a browser-trusted certificate from Let's Encrypt for `fitssort.com` and `*.fitssort.com`.

### Cloudflare Origin Certificate

Traefik expects the following files in [certs/](certs/):

- `origin.pem` for the certificate
- `origin.key` for the private key

To create the certificate:

1. Open Cloudflare Dashboard
2. Go to **SSL/TLS** → **Origin Server**
3. Create a certificate for `fitssort.com` and `*.fitssort.com`
4. Save the certificate as `origin.pem` and the key as `origin.key`

Do not commit the actual certificate files to git.

### Let's Encrypt Fallback

Wildcard certificates require DNS-01 validation. This setup uses Hostinger's DNS API, so create a Hostinger API token that can manage DNS records for the `fitssort.com` zone.

Then provide it to Traefik as `HOSTINGER_API_TOKEN`. You can export it in the shell:

```bash
export HOSTINGER_API_TOKEN="your-hostinger-token"
```

Or create a local, ignored env file from the example:

```bash
cp shared/traefik/.env.example shared/traefik/.env
```

Then edit [shared/traefik/.env](.env) with the real token and start Traefik with `--env-file shared/traefik/.env`.

The ACME account and issued certificates are stored in the Docker volume `traefik_letsencrypt`, mounted at `/letsencrypt` inside the container.

## Start Traefik

Run Traefik from the repository root:

```bash
docker compose -f shared/traefik/docker-compose.traefik.yml up -d
```

If using [shared/traefik/.env](.env) for the Let's Encrypt fallback token, run:

```bash
docker compose --env-file shared/traefik/.env -f shared/traefik/docker-compose.traefik.yml up -d
```

Traefik must be started before the backend and frontend stacks so the shared `traefik_proxy` network exists when those services come up.

Then start the application stacks:

```bash
docker compose -f apps/gym_app_new_backend/docker-compose.prod.yml up -d --build
docker compose -f apps/gym_app_new_frontend/docker-compose.prod.yml up -d --build
```

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
	- traefik.http.routers.api.rule=Host(`api.fitssort.com`)
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
http://{tenant}.fitssort.com/iclock
http://{custom-domain}/iclock
http://fitssort.com/iclock
```

Supported endpoints (with or without trailing slash):

- `/iclock/cdata` or `/cdata` — heartbeat + attendance push
- `/iclock/getrequest` or `/getrequest` — command poll
- `/iclock/devicecmd` or `/devicecmd` — command ack

### Smoke test

```bash
# Must succeed (HTTP)
curl -v "http://tenant.fitssort.com/iclock/cdata?SN=YOUR_SN"

# Must NOT reach ADMS handlers after migration (HTTPS)
curl -v "https://tenant.fitssort.com/iclock/cdata?SN=YOUR_SN"
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
- Let's Encrypt ACME resolver using Hostinger DNS-01 challenge

The trusted Cloudflare IP ranges are important because they allow Traefik to preserve the correct forwarded headers when the site is behind Cloudflare.

## TLS Configuration

[dynamic/tls.yml](dynamic/tls.yml) contains the Cloudflare Origin Certificate template. Uncomment it after placing `origin.pem` and `origin.key` in [certs/](certs/) if you want Traefik to load the origin certificate directly.

This ensures that:

- HTTPS routes have a valid certificate immediately on startup
- Wildcard host rules work correctly for subdomains

The `letsencrypt` ACME resolver in [traefik.yml](traefik.yml) is attached to the backend and frontend production routers. Their `tls.domains` labels explicitly request `fitssort.com` and `*.fitssort.com`, which is required because Traefik cannot infer ACME domains from a regex-only host rule.

## Troubleshooting

- If the browser shows a certificate warning, confirm `origin.pem` and `origin.key` exist in [certs/](certs/) and match the Cloudflare Origin Certificate, or confirm `HOSTINGER_API_TOKEN` is set so the Let's Encrypt fallback can issue a certificate
- If `https://fitssort.com` does not open but subdomains do, add an apex DNS record for `fitssort.com`; the wildcard record does not match the root domain
- If `fitssort.com` or a tenant subdomain sometimes shows a Hostinger parked page, remove every stale A/AAAA/CNAME for that hostname that does not point to the Traefik server. Mixed records can silently round-robin between your app and Hostinger's parking edge.
- If Let's Encrypt fails, check Traefik logs for ACME errors and confirm the Hostinger token can manage DNS records for the `fitssort.com` zone
- If a service is not reachable, verify it is attached to the `traefik_proxy` network
- If Traefik cannot find a container, confirm the container has `traefik.enable=true`
- If forwarded headers look wrong in the backend, confirm requests are passing through the trusted Cloudflare IP ranges in [traefik.yml](traefik.yml)

## Notes

- The Traefik dashboard is disabled in production via `api.dashboard: false`
- Docker socket access is mounted read-only
- `web` redirects browser/frontend traffic to `websecure`; ADMS device paths on port 80 are excluded from redirect
