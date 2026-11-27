#!/usr/bin/env bash
# Configure a fresh Jellyfin over its REST API so a reinstall needs no clicking.
#
# Idempotent: if the startup wizard is already done, this exits immediately.
# Every call used here was verified against Jellyfin 10.11.11.
set -euo pipefail

BASE="http://127.0.0.1:${JELLYFIN_PORT:-8096}"
MOVIES_DIR="${MOVIES_DIR:?MOVIES_DIR not set}"
ADMIN_USER="${ADMIN_USER:-admin}"
PASSWORD_FILE="${ADMIN_PASSWORD_FILE:-/var/lib/secrets/jellyfin-admin-password}"
LANG_PREF="${METADATA_LANGUAGE:-en}"
COUNTRY="${METADATA_COUNTRY:-NO}"

log() { echo "[provision-jellyfin] $*"; }

# --- wait for the server to answer ------------------------------------------
for i in $(seq 1 60); do
  if curl -fsS -o /dev/null "$BASE/System/Info/Public" 2>/dev/null; then break; fi
  [ "$i" = 60 ] && { log "Jellyfin never came up; giving up."; exit 1; }
  sleep 2
done

wizard_done() {
  curl -fsS "$BASE/System/Info/Public" | grep -q '"StartupWizardCompleted":true'
}

if wizard_done; then
  log "Already provisioned; nothing to do."
  exit 0
fi

if [ ! -r "$PASSWORD_FILE" ]; then
  log "ERROR: no admin password at $PASSWORD_FILE"
  log "Create it once with:  sudo install -m600 /dev/null $PASSWORD_FILE && sudo nano $PASSWORD_FILE"
  exit 1
fi
ADMIN_PASS="$(tr -d '\n' < "$PASSWORD_FILE")"

JSON='Content-Type: application/json'

log "Setting locale/metadata preferences..."
curl -fsS -o /dev/null -X POST "$BASE/Startup/Configuration" -H "$JSON" \
  -d "{\"UICulture\":\"en-US\",\"MetadataCountryCode\":\"$COUNTRY\",\"PreferredMetadataLanguage\":\"$LANG_PREF\"}"

# Must be fetched before the user can be set; Jellyfin seeds a default name.
curl -fsS -o /dev/null "$BASE/Startup/User"

log "Creating administrator '$ADMIN_USER'..."
curl -fsS -o /dev/null -X POST "$BASE/Startup/User" -H "$JSON" \
  -d "$(printf '{"Name":%s,"Password":%s}' \
        "$(printf '%s' "$ADMIN_USER" | jq -Rs .)" \
        "$(printf '%s' "$ADMIN_PASS"  | jq -Rs .)")"

log "Setting LAN-only remote access..."
curl -fsS -o /dev/null -X POST "$BASE/Startup/RemoteAccess" -H "$JSON" \
  -d '{"EnableRemoteAccess":true,"EnableAutomaticPortMapping":false}'

log "Completing startup wizard..."
curl -fsS -o /dev/null -X POST "$BASE/Startup/Complete" -H "$JSON"

# --- authenticate so we can create the library ------------------------------
AUTH_HDR='MediaBrowser Client="provision", Device="nixos", DeviceId="nixos-provision", Version="1.0"'
RESP="$(curl -fsS -X POST "$BASE/Users/AuthenticateByName" -H "$JSON" -H "Authorization: $AUTH_HDR" \
  -d "$(printf '{"Username":%s,"Pw":%s}' \
        "$(printf '%s' "$ADMIN_USER" | jq -Rs .)" \
        "$(printf '%s' "$ADMIN_PASS"  | jq -Rs .)")")"
TOKEN="$(printf '%s' "$RESP" | jq -r '.AccessToken')"
[ -n "$TOKEN" ] && [ "$TOKEN" != "null" ] || { log "ERROR: could not authenticate"; exit 1; }
TOKEN_HDR="Authorization: MediaBrowser Token=\"$TOKEN\""

log "Creating the Movies library at $MOVIES_DIR ..."
curl -fsS -o /dev/null -X POST \
  "$BASE/Library/VirtualFolders?collectionType=movies&refreshLibrary=true&name=Movies" \
  -H "$JSON" -H "$TOKEN_HDR" \
  -d "{\"LibraryOptions\":{\"PathInfos\":[{\"Path\":\"$MOVIES_DIR\"}],\"EnableRealtimeMonitor\":true}}"

log "Enabling VAAPI hardware acceleration..."
# Haswell: H.264 encode/decode in hardware; HEVC decode is NOT supported, so it
# is deliberately absent from HardwareDecodingCodecs.
curl -fsS -o /dev/null -X POST "$BASE/System/Configuration/encoding" \
  -H "$JSON" -H "$TOKEN_HDR" -d '{
    "HardwareAccelerationType": "vaapi",
    "VaapiDevice": "/dev/dri/renderD128",
    "EnableHardwareEncoding": true,
    "HardwareDecodingCodecs": ["h264","mpeg2video","vc1"],
    "EnableTonemapping": false,
    "AllowHevcEncoding": false,
    "EnableThrottling": true
  }' || log "WARNING: could not set encoding config (set it in the UI if transcoding is slow)"

log "Done. Jellyfin is provisioned."
