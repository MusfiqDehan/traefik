---
icon: lucide/server
---

# Self-Hosted Sentry

Run Sentry on your own infrastructure using the [official self-hosted installer](https://github.com/getsentry/self-hosted).

> **Resource requirements:** 16 GB RAM minimum for Sentry alone; **24 GB+** recommended if Prometheus/Grafana/Loki run on the same host. On a 12 GB VPS, use [Sentry Cloud](sentry-cloud.md) instead.

Sentry is **not** a single Docker image — the installer deploys Postgres, Redis, Kafka, ClickHouse, Snuba, Relay, web, workers, cron, and more.

## Install

```bash
# Sibling directory to this repo, e.g. ~/DevOps/sentry-self-hosted
git clone https://github.com/getsentry/self-hosted.git
cd self-hosted
./install.sh
```

Follow the interactive installer to create an admin user and generate `docker-compose.yml`.

Keep Sentry in its **own directory** — do not merge into [docker-compose.monitoring.yml](../docker-compose.monitoring.yml). Upgrades use Sentry's `./install.sh`.

## Expose via Traefik

After installation, configure the public URL and attach to the existing proxy network.

### 1. Set URL prefix

Edit `sentry/config.yml`:

```yaml
system.url-prefix: 'https://sentry.musfiqdehan.com'
```

### 2. Attach web service to traefik_proxy

In Sentry's `docker-compose.yml`, on the `web` service:

```yaml
services:
  web:
    networks:
      - default
      - traefik_proxy
    labels:
      - traefik.enable=true
      - traefik.http.routers.sentry.rule=Host(`sentry.musfiqdehan.com`)
      - traefik.http.routers.sentry.entrypoints=websecure
      - traefik.http.routers.sentry.tls=true
      - traefik.http.services.sentry.loadbalancer.server.port=9000

networks:
  traefik_proxy:
    external: true
```

Ensure Traefik is running and `sentry.musfiqdehan.com` DNS points to the server.

### 3. Create admin user

During `./install.sh` or afterward:

```bash
docker compose exec web sentry createuser
```

Disable public signup in Sentry admin after setup.

## Application SDK wiring

Create one Sentry project per app in the self-hosted UI. DSN format:

```
https://<key>@sentry.musfiqdehan.com/<project-id>
```

| App | Package | Env var |
|-----|---------|---------|
| Django backend | `sentry-sdk[django]` | `SENTRY_DSN` |
| Next.js frontend | `@sentry/nextjs` | `NEXT_PUBLIC_SENTRY_DSN` |
| NestJS API | `@sentry/nestjs` | `SENTRY_DSN` |

## Startup order (with Traefik + monitoring)

```bash
# 1. Traefik
docker compose --env-file .env -f docker-compose.traefik.yml up -d

# 2. Monitoring
docker compose --env-file .env -f docker-compose.monitoring.yml up -d

# 3. Sentry (from sentry-self-hosted directory)
docker compose up -d
```

## Upgrades

Follow the [official upgrade guide](https://develop.sentry.dev/self-hosted/releases/). Always run `./install.sh` from the self-hosted repo after pulling a new release tag.

## Troubleshooting

| Issue | Check |
|-------|-------|
| Web UI 502 | `docker compose ps` — wait for Kafka/ClickHouse health |
| Events not ingested | Relay and worker containers running; DSN matches `system.url-prefix` |
| OOM kills | `dmesg` / `docker stats` — add RAM or move Sentry to a dedicated host |
| CSRF errors | `system.url-prefix` must match the browser URL exactly (https, no trailing slash) |
