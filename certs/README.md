Place your Cloudflare Origin Certificate files here:

- origin.pem  — Origin Certificate (public)
- origin.key  — Private Key

Generate from: Cloudflare Dashboard → SSL/TLS → Origin Server → Create Certificate

IMPORTANT: Never commit the actual certificate files to git.

If these files are not available, the production Traefik routers can fall back to Let's Encrypt through the `letsencrypt` DNS-01 resolver configured in [../traefik.yml](../traefik.yml). Set `HOSTINGER_API_TOKEN` before starting Traefik so it can create Hostinger DNS validation records.
