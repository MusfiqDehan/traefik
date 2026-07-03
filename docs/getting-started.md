# Getting Started

## Prerequisites

- Docker and Docker Compose
- Domains managed in Cloudflare
- Origin certificates and/or a Cloudflare API token for Let's Encrypt DNS-01
- Application stacks (Django, Next.js, etc.) configured to join the `traefik_proxy` network

## Environment variables

Copy the example file and fill in secrets:

```bash
cp .env.example .env
```

| Variable | Used by | Purpose |
|----------|---------|---------|
| `CF_DNS_API_TOKEN` | Traefik | Let's Encrypt DNS-01 for all managed zones |
| `GRAFANA_ADMIN_USER` | Grafana | Admin username (default `admin`) |
| `GRAFANA_ADMIN_PASSWORD` | Grafana | Admin password for Grafana UI |

See [.env.example](../.env.example) for details.

## Grafana edge basic auth

Before starting the monitoring stack:

```bash
htpasswd -cb dynamic/.htpasswd admin 'your-strong-password'
```

This file is gitignored. See [dynamic/.htpasswd.example](../dynamic/.htpasswd.example).

## Startup order

```bash
# 1. Traefik — creates traefik_proxy network
docker compose --env-file .env -f docker-compose.traefik.yml up -d

# 2. Monitoring — metrics and logs
docker compose --env-file .env -f docker-compose.monitoring.yml up -d

# 3. Application stacks (from their respective repositories)
# docker compose -f <app>/docker-compose.prod.yml up -d --build
```

Traefik **must** start first so `traefik_proxy` exists for app and monitoring containers.

## Related guides

- [DNS & Domains](dns-and-domains.md)
- [TLS & Certificates](tls-and-certificates.md)
- [Monitoring](monitoring.md)
