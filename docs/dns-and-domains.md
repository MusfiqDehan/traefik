---
icon: lucide/globe
---

# DNS & Domains

All zones are expected to be proxied through Cloudflare with **SSL/TLS mode: Full (strict)**.

## musfiqdehan.com

Apex only — **no** `*.musfiqdehan.com` tenant wildcard.

| Record | Target |
|--------|--------|
| `musfiqdehan.com` | Server IP (A/AAAA) |

Add explicit hostnames as needed (e.g. `grafana.musfiqdehan.com`).

## Tenant platform domains (wildcard)

Wildcard DNS does **not** cover the apex. For each UK zone, create **both** apex and wildcard records:

| Zone | Apex | Wildcard |
|------|------|----------|
| `mrdfit.uk` | `mrdfit.uk` → server | `*.mrdfit.uk` → server |
| `mrderp.uk` | `mrderp.uk` → server | `*.mrderp.uk` → server |
| `mrdhrms.uk` | `mrdhrms.uk` → server | `*.mrdhrms.uk` → server |
| `mrdlms.uk` | `mrdlms.uk` → server | `*.mrdlms.uk` → server |

Proxy both records (orange cloud) to the same origin.

## Stale records

Remove any old A/AAAA/CNAME records pointing to Hostinger parking, a previous VPS, or another host. Mixed records cause intermittent routing to the wrong origin.

## HTTP redirect rules

Port-80 → HTTPS redirects for `/api`, `/ninja`, `/media`, `/static`, and `/ws` are defined in [dynamic/redirects.yml](../dynamic/redirects.yml):

- **Platform hosts:** `musfiqdehan.com` (apex), plus apex + `*.` for each UK zone above
- **Custom domains:** all other hostnames (tenant-owned domains)

ADMS device paths (`/iclock`, `/cdata`, etc.) stay on plain HTTP — see [Routing & ADMS](routing-and-adms.md).

## Cloudflare API token

For Let's Encrypt DNS-01, create a token with **Zone → DNS → Edit** and **Zone → Zone → Read** scoped to every zone:

`musfiqdehan.com`, `mrdfit.uk`, `mrderp.uk`, `mrdhrms.uk`, `mrdlms.uk`

Set as `CF_DNS_API_TOKEN` in [.env](../.env).
