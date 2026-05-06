# Cloudflare Origin Certificates

Place your Cloudflare Origin Certificate files here:

- `origin.pem` — Origin Certificate (public)
- `origin.key` — Private Key

## How to generate

1. Go to Cloudflare Dashboard → your domain → **SSL/TLS** → **Origin Server**
2. Click **Create Certificate**
3. Choose wildcard `*.musfiqdehan.com` + root `musfiqdehan.com`
4. Select validity (up to 15 years)
5. Copy the certificate into `origin.pem` and the key into `origin.key`

## Security

**Never commit the actual certificate files to git.**
Both `origin.pem` and `origin.key` are listed in `.gitignore`.

Copy them from each sub-repo's `certs/` folder (backend/frontend) or re-download from Cloudflare.
