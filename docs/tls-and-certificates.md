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

Loaded by [dynamic/tls.yml](../dynamic/tls.yml) as the default certificate.

SANs are typically `musfiqdehan.com` and `*.musfiqdehan.com`. That **does not** cover nested hosts such as `client1.ecamp.musfiqdehan.com`. Those use the Let's Encrypt DNS-01 wildcard issued by [dynamic/ecamp.yml](../dynamic/ecamp.yml) (`ecamp.musfiqdehan.com` + `*.ecamp.musfiqdehan.com`).

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

For nested ecamp tenants (also pre-issued by [dynamic/ecamp.yml](../dynamic/ecamp.yml)):

```yaml
- traefik.http.routers.api.tls.certresolver=letsencrypt
- traefik.http.routers.api.tls.domains[0].main=ecamp.musfiqdehan.com
- traefik.http.routers.api.tls.domains[0].sans=*.ecamp.musfiqdehan.com
```

Traefik cannot infer ACME domains from a regex-only `HostRegexp` rule.

ACME state is stored in the Docker volume `traefik_letsencrypt` at `/letsencrypt` inside the Traefik container.

## Certificate selection flow

```
HTTPS request → origin cert in tls.yml matches SNI?
  Yes → serve origin cert
  No  → router has certresolver=letsencrypt?
          Yes → request/use LE cert for tls.domains
          No  → default cert or TLS error
```
