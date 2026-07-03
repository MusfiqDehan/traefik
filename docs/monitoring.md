# Monitoring Stack

Docker-based observability: **Prometheus** (metrics), **Grafana** (dashboards), **Loki + Promtail** (container logs).

## Components

| Service | Image role | Exposure |
|---------|------------|----------|
| Prometheus | Metrics store (15-day retention) | Internal only |
| Grafana | UI at `https://grafana.musfiqdehan.com` | Via Traefik + basic auth |
| Loki | Log store (14-day retention) | Internal only |
| Promtail | Ships all Docker json-file logs to Loki | Internal only |
| node-exporter | Host CPU, RAM, disk, network | Internal only |
| cAdvisor | Per-container resource usage | Internal only |

Config lives under [monitoring/](../monitoring/). Compose file: [docker-compose.monitoring.yml](../docker-compose.monitoring.yml).

On a **12 GB RAM** server, this stack plus Traefik and application containers is reasonable.

## Prerequisites

1. Traefik running (`traefik_proxy` network exists)
2. `dynamic/.htpasswd` created — see [Getting Started](getting-started.md)
3. `GRAFANA_ADMIN_PASSWORD` set in `.env`

## Start

```bash
docker compose --env-file .env -f docker-compose.monitoring.yml up -d
```

## Grafana access

| Layer | Credentials |
|-------|-------------|
| Traefik edge | `dynamic/.htpasswd` (htpasswd user/password) |
| Grafana app | `GRAFANA_ADMIN_USER` / `GRAFANA_ADMIN_PASSWORD` from `.env` |

URL: `https://grafana.musfiqdehan.com`

Prometheus and Loki datasources are auto-provisioned from [monitoring/grafana/provisioning/](../monitoring/grafana/provisioning/).

## Recommended dashboards

Import by ID in Grafana → Dashboards → Import:

| ID | Name |
|----|------|
| 1860 | Node Exporter Full |
| 193 | Docker cAdvisor |
| 11462 | Traefik 2.x (compatible with Traefik 3 metrics) |

## Log queries (Explore → Loki)

```logql
{container_name=~".+"}
{compose_service="backend"}
{container_name=~".*postgres.*|.*redis.*"}
```

Promtail reads `/var/lib/docker/containers` and the Docker socket — **all containers on the host** that use the default `json-file` log driver are included.

## Verification

```bash
docker run --rm --network traefik_proxy curlimages/curl:latest \
  -s http://prometheus:9090/-/healthy

docker run --rm --network traefik_proxy curlimages/curl:latest \
  -s http://traefik:8080/metrics | head
```

Traefik exposes Prometheus metrics on internal entrypoint `:8080` — see [traefik.yml](../traefik.yml).

## Security

- Do **not** publish Prometheus, Loki, or cAdvisor ports on the host
- Do **not** add Traefik labels to internal monitoring services except Grafana
