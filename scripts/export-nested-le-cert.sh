#!/usr/bin/env bash
# Export a nested-platform Let's Encrypt cert from Traefik acme.json to ./certs/
# for use in dynamic/tls.yml (file provider). Run on the VPS after first issue
# or when renewing fitpulse / supermart wildcards.
#
# Usage:
#   ./scripts/export-nested-le-cert.sh fitpulse.musfiqdehan.com
#   ./scripts/export-nested-le-cert.sh supermart.musfiqdehan.com
#
# Requires: python3, acme.json at /letsencrypt/acme.json (Traefik volume mount)

set -euo pipefail

MAIN="${1:?Usage: $0 <main-domain e.g. fitpulse.musfiqdehan.com>}"
SLUG="${MAIN%%.*}" # fitpulse from fitpulse.musfiqdehan.com

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ACME="${ACME_JSON:-/letsencrypt/acme.json}"
OUT_PEM="${REPO_ROOT}/certs/${SLUG}-le.pem"
OUT_KEY="${REPO_ROOT}/certs/${SLUG}-le.key"

if [[ ! -f "$ACME" ]]; then
  # Host path when run outside the container
  MOUNT="$(docker volume inspect traefik_traefik_letsencrypt -f '{{.Mountpoint}}' 2>/dev/null || true)"
  if [[ -n "$MOUNT" && -f "${MOUNT}/acme.json" ]]; then
    ACME="${MOUNT}/acme.json"
  else
    echo "acme.json not found (set ACME_JSON or run on Traefik host)" >&2
    exit 1
  fi
fi

python3 - "$MAIN" "$OUT_PEM" "$OUT_KEY" "$ACME" <<'PY'
import json, sys
from pathlib import Path

main, out_pem, out_key, acme_path = sys.argv[1:5]
data = json.loads(Path(acme_path).read_text())
certs = data.get("letsencrypt", {}).get("Certificates", [])
match = None
for c in certs:
    d = c.get("domain", {})
    if d.get("main") == main:
        match = c
        break
if not match:
    sys.stderr.write(f"No LE certificate for main={main!r} in {acme_path}\n")
    sys.stderr.write("Known mains: " + ", ".join(
        c.get("domain", {}).get("main", "?") for c in certs
    ) + "\n")
    sys.exit(1)

Path(out_pem).write_text(match["certificate"])
Path(out_key).write_text(match["key"])
Path(out_key).chmod(0o600)
print(f"Wrote {out_pem} and {out_key}")
PY
