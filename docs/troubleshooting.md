# Troubleshooting

## TLS & certificates

| Symptom | Fix |
|---------|-----|
| Browser certificate warning | Confirm `certs/origin.pem` and `origin.key` exist and match Cloudflare; or set `CF_DNS_API_TOKEN` for LE fallback |
| UK apex works, subdomains don't | Add wildcard DNS `*.zone.uk` — wildcard does not cover apex and vice versa |
| Let's Encrypt fails | Check Traefik logs for ACME errors; verify Cloudflare token has DNS Edit on the zone |
| Wrong cert served | Add per-zone cert block in [dynamic/tls.yml](../dynamic/tls.yml) or explicit `tls.domains` on router |

## Routing

| Symptom | Fix |
|---------|-----|
| Service unreachable | Container on `traefik_proxy`? `traefik.enable=true`? |
| 404 from Traefik | Router rule / host mismatch; check labels |
| Wrong scheme in Django | Requests must pass Cloudflare → Traefik; trusted IPs in [traefik.yml](../traefik.yml) |
| Stale Hostinger page | Remove conflicting DNS records for the hostname |

## Monitoring

| Symptom | Fix |
|---------|-----|
| Grafana 401 at edge | Create `dynamic/.htpasswd` via `htpasswd` |
| No logs in Loki | Promtail needs `/var/lib/docker/containers` + docker.sock mounts |
| Traefik target DOWN in Prometheus | Restart Traefik after enabling `metrics.prometheus`; scrape `traefik:8080` |

## ADMS devices

| Symptom | Fix |
|---------|-----|
| Device cannot connect | Use `http://` not `https://`; port 80 open through Cloudflare |
| 404 on `/iclock` | `backend-adms` router must use `web` entrypoint (port 80) |

## Useful commands

```bash
# Traefik logs
docker logs traefik --tail 100

# Reload dynamic config (file provider watches automatically)
docker exec traefik ls /etc/traefik/dynamic/

# List routers (if dashboard enabled temporarily)
docker logs traefik 2>&1 | grep -i error
```
