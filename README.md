# Traefik Setup

This directory contains the Traefik v3 reverse proxy configuration. It is responsible for:

- Terminating HTTPS with a Cloudflare Origin Certificate
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
5. TLS is served from the Cloudflare origin certificate in `certs/`

## Requirements

- Docker and Docker Compose
- A valid Cloudflare Origin Certificate for `musfiqdehan.com` and `*.musfiqdehan.com`
- Backend and frontend services configured to join the `traefik_proxy` network

## Certificate Setup

Traefik expects the following files in [certs/](certs/):

- `origin.pem` for the certificate
- `origin.key` for the private key

To create the certificate:

1. Open Cloudflare Dashboard
2. Go to **SSL/TLS** → **Origin Server**
3. Create a certificate for `musfiqdehan.com` and `*.musfiqdehan.com`
4. Save the certificate as `origin.pem` and the key as `origin.key`

Do not commit the actual certificate files to git.

## Start Traefik

Run Traefik from the repository root:

```bash
docker compose -f traefik/docker-compose.traefik.yml up -d
```

Traefik must be started before the backend and frontend stacks so the shared `traefik_proxy` network exists when those services come up.

## How Routing Works

Traefik uses Docker labels to discover services. Containers must:

- Join the `traefik_proxy` network
- Set `traefik.enable=true`
- Define router rules such as `Host(...)`
- Point the router to the correct service port

Example label set:

```yaml
labels:
	- traefik.enable=true
	- traefik.http.routers.api.rule=Host(`api.musfiqdehan.com`)
	- traefik.http.routers.api.entrypoints=websecure
	- traefik.http.routers.api.tls=true
	- traefik.http.services.api.loadbalancer.server.port=8000
	- traefik.http.routers.api.middlewares=security-headers@file,compress@file
```

## Middlewares

The reusable middlewares defined in [dynamic/middlewares.yml](dynamic/middlewares.yml) are:

- `security-headers@file`
- `compress@file`
- `api-ratelimit@file`

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

The trusted Cloudflare IP ranges are important because they allow Traefik to preserve the correct forwarded headers when the site is behind Cloudflare.

## TLS Configuration

[dynamic/tls.yml](dynamic/tls.yml) registers the Cloudflare Origin Certificate as the default certificate store and also as an explicit wildcard certificate.

This ensures that:

- HTTPS routes have a valid certificate immediately on startup
- Wildcard host rules work correctly for subdomains

## Troubleshooting

- If the browser shows a certificate warning, confirm `origin.pem` and `origin.key` exist in [certs/](certs/) and match the Cloudflare Origin Certificate
- If a service is not reachable, verify it is attached to the `traefik_proxy` network
- If Traefik cannot find a container, confirm the container has `traefik.enable=true`
- If forwarded headers look wrong in the backend, confirm requests are passing through the trusted Cloudflare IP ranges in [traefik.yml](traefik.yml)

## Notes

- The Traefik dashboard is disabled in production via `api.dashboard: false`
- Docker socket access is mounted read-only
- `web` redirects permanently to `websecure`
