---
icon: lucide/shield-check
---

# TLS & Certificates

Traefik supports two certificate sources:

1. **Cloudflare Origin Certificates** (primary) — long-lived, loaded from [certs/](../certs/)
2. **Let's Encrypt** (fallback) — DNS-01 via Cloudflare API, configured in [traefik.yml](../traefik.yml)

## Origin certificates

### musfiqdehan.com

Default cert files:

- `certs/origin.pem` — public certificate
- `certs/origin.key` — private key

Loaded by [dynamic/tls.yml](../dynamic/tls.yml) as the **default** certificate only (fallback for hosts like `blog.musfiqdehan.com`).

SANs are typically `musfiqdehan.com` and `*.musfiqdehan.com`. That wildcard **does** match `fitpulse.musfiqdehan.com` (one label), which conflicts with the public Let's Encrypt cert needed for Cloudflare **Full (strict)** on the proxied apex. Do **not** add `origin.pem` to the `certificates:` list in `tls.yml` — only list exported LE files there. Origin stays under `stores.default.defaultCertificate` for unmatched SNIs.

That origin wildcard **does not** cover nested hosts such as `client1.supermart.musfiqdehan.com` or `hellogym.fitpulse.musfiqdehan.com`. Those use Let's Encrypt DNS-01 wildcards issued by [dynamic/nested-platforms.yml](../dynamic/nested-platforms.yml) (`supermart` / `fitpulse` + `*.supermart` / `*.fitpulse.musfiqdehan.com`).

After issue or renew, export the fitpulse (or supermart) wildcard to disk:

```bash
./scripts/export-nested-le-cert.sh fitpulse.musfiqdehan.com
```

Traefik picks up file changes to `dynamic/tls.yml` automatically; re-export after ACME renewals (cron weekly is enough).

### Cloudflare DNS for FitPulse

| Record | Proxy | Why |
|--------|-------|-----|
| `fitpulse.musfiqdehan.com` | Proxied (orange) | Edge cert + DDoS; origin must present publicly trusted LE (not origin CA). |
| `*.fitpulse.musfiqdehan.com` | DNS only (grey) | Universal SSL does not cover two-level wildcards; browsers terminate TLS on the VPS with the LE `*.fitpulse.musfiqdehan.com` cert. |

### UK platform zones

Create a separate origin certificate per zone in Cloudflare (**SSL/TLS → Origin Server**):

| Zone | Certificate hostnames |
|------|---------------------|
| `mrdfit.uk` | `mrdfit.uk`, `*.mrdfit.uk` |
| `mrderp.uk` | `mrderp.uk`, `*.mrderp.uk` |
| `mrdhrms.uk` | `mrdhrms.uk`, `*.mrdhrms.uk` |
| `mrdlms.uk` | `mrdlms.uk`, `*.mrdlms.uk` |

Save as e.g. `certs/mrdfit.pem` / `certs/mrdfit.key` and add matching blocks in [dynamic/tls.yml](../dynamic/tls.yml).

**Never commit certificate or key files to git.**

### Create an origin certificate

1. Cloudflare Dashboard → **SSL/TLS** → **Origin Server**
2. **Create Certificate** → select hostnames for the zone
3. Save PEM and key into `certs/`

## Let's Encrypt fallback

Wildcard certs require DNS-01. The `letsencrypt` resolver in [traefik.yml](../traefik.yml) uses `provider: cloudflare` and reads `CF_DNS_API_TOKEN`.

Production app routers should declare explicit domains on labels:

```yaml
- traefik.http.routers.api.tls.certresolver=letsencrypt
- traefik.http.routers.api.tls.domains[0].main=mrdfit.uk
- traefik.http.routers.api.tls.domains[0].sans=*.mrdfit.uk
```

For nested supermart / fitpulse tenants (also pre-issued by [dynamic/nested-platforms.yml](../dynamic/nested-platforms.yml)):

```yaml
- traefik.http.routers.api.tls.certresolver=letsencrypt
- traefik.http.routers.api.tls.domains[0].main=supermart.musfiqdehan.com
- traefik.http.routers.api.tls.domains[0].sans=*.supermart.musfiqdehan.com
- traefik.http.routers.api.tls.domains[1].main=fitpulse.musfiqdehan.com
- traefik.http.routers.api.tls.domains[1].sans=*.fitpulse.musfiqdehan.com
```

Traefik cannot infer ACME domains from a regex-only `HostRegexp` rule.

ACME state is stored in the Docker volume `traefik_letsencrypt` at `/letsencrypt` inside the Traefik container.

## Certificate selection flow

```
HTTPS request → LE file cert in tls.yml certificates[] matches SNI?
  Yes → serve LE file cert (fitpulse apex + tenants)
  No  → ACME store cert from nested-platforms router?
          Yes → serve LE from acme.json (e.g. supermart apex)
  No  → defaultCertificate (origin.pem) for other *.musfiqdehan.com
```
