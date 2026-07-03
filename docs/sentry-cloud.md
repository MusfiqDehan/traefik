---
icon: lucide/cloud
---

# Sentry Cloud

**Recommended** for servers with limited RAM (e.g. 12 GB). No containers run on this host for Sentry.

Sentry captures **application errors** (exceptions, stack traces, releases). It does **not** replace Loki for raw container logs — use [Monitoring](monitoring.md) for log aggregation.

## Setup

1. Create an account at [sentry.io](https://sentry.io/signup/)
2. Create an organization
3. Create one project per application (Django API, Next.js frontend, NestJS API, etc.)
4. Copy each project's **DSN** from **Settings → Projects → [project] → Client Keys (DSN)**

No Traefik routes or DNS records are required — apps send events outbound to Sentry's ingest endpoints.

## SDK wiring

| App | Package | Environment variable |
|-----|---------|---------------------|
| Django backend | `sentry-sdk[django]` | `SENTRY_DSN`, `SENTRY_ENVIRONMENT` |
| Next.js frontend | `@sentry/nextjs` | `NEXT_PUBLIC_SENTRY_DSN` |
| NestJS API | `@sentry/nestjs` | `SENTRY_DSN` |

DSN format:

```
https://<key>@o<org-id>.ingest.<region>.sentry.io/<project-id>
```

### Django example

```python
import os
import sentry_sdk

sentry_sdk.init(
    dsn=os.environ["SENTRY_DSN"],
    environment=os.environ.get("SENTRY_ENVIRONMENT", "production"),
    traces_sample_rate=0.1,
)
```

## When to use self-hosted instead

See [Self-Hosted Sentry](sentry-self-hosted.md) if you have **16 GB+ RAM** (24 GB+ with monitoring) and need data residency or air-gapped deployment.
