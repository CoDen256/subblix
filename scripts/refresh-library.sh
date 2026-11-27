#!/usr/bin/env bash
# Ask Jellyfin to rescan, but only when the subtitle jobs actually produced
# something. Avoids pointless library scans every 15 minutes.
set -euo pipefail

STATE_DIR="${STATE_DIR:-/var/lib/subtitle-extract}"
FLAG="$STATE_DIR/needs-refresh"
BASE="http://127.0.0.1:${JELLYFIN_PORT:-8096}"
KEY_FILE="${JELLYFIN_API_KEY_FILE:-/var/lib/secrets/jellyfin-api-key}"

[ -f "$FLAG" ] || exit 0

if [ ! -r "$KEY_FILE" ]; then
  echo "[refresh-library] No API key at $KEY_FILE - skipping automatic refresh."
  echo "[refresh-library] Create one in Jellyfin: Dashboard > API Keys, then save it there."
  exit 0
fi

KEY="$(tr -d '\n' < "$KEY_FILE")"
if curl -fsS -o /dev/null -X POST "$BASE/Library/Refresh" -H "Authorization: MediaBrowser Token=\"$KEY\""; then
  echo "[refresh-library] Library refresh requested."
  rm -f "$FLAG"
else
  echo "[refresh-library] Refresh failed; will retry next time."
fi
