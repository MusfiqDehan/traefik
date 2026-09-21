---
icon: lucide/globe
---

# DNS & Domains

All zones are expected to be proxied through Cloudflare with **SSL/TLS mode: Full (strict)**.

## musfiqdehan.com

Apex + explicit single-label hosts (e.g. `grafana.musfiqdehan.com`). A Cloudflare `*.musfiqdehan.com` record covers **one** label only — it does **not** resolve `client1.supermart.musfiqdehan.com`.

| Record | Target |
|--------|--------|
| `musfiqdehan.com` | Server IP (A/AAAA) |
| `supermart.musfiqdehan.com` | Server IP (A/AAAA) — supermart product apex |
| `*.supermart.musfiqdehan.com` | Server IP (A/AAAA) — nested supermart tenants |
| `fitpulse.musfiqdehan.com` | Server IP (A/AAAA) — FitPulse product apex |
| `*.fitpulse.musfiqdehan.com` | Server IP (A/AAAA) — nested FitPulse tenants |
| `wufud.musfiqdehan.com` | Server IP (A/AAAA) — Wufud product apex |
| `*.wufud.musfiqdehan.com` | Server IP (A/AAAA) — nested Wufud tenants |
| `staging.wufud.musfiqdehan.com` | Server IP (A/AAAA) — Wufud staging apex |
| `*.staging.wufud.musfiqdehan.com` | Server IP (A/AAAA) — nested Wufud staging tenants |

Proxy (orange cloud) is fine for browser traffic. Nested TLS uses Let's Encrypt DNS-01 on the origin (see [TLS & Certificates](tls-and-certificates.md)); keep `CF_DNS_API_TOKEN` valid for this zone.

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

- **Platform hosts:** `musfiqdehan.com` (apex), `supermart` / `fitpulse` + nested `*.supermart` / `*.fitpulse`, plus apex + `*.` for each UK zone above
- **Custom domains:** all other hostnames (tenant-owned domains)

ADMS device paths (`/iclock`, `/cdata`, etc.) stay on plain HTTP — see [Routing & ADMS](routing-and-adms.md).

## Cloudflare API token

For Let's Encrypt DNS-01, create a token with **Zone → DNS → Edit** and **Zone → Zone → Read** scoped to every zone:

`musfiqdehan.com` (including nested `*.supermart` / `*.fitpulse.musfiqdehan.com`), `mrdfit.uk`, `mrderp.uk`, `mrdhrms.uk`, `mrdlms.uk`

Set as `CF_DNS_API_TOKEN` in [.env](../.env).
