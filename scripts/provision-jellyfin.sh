#!/usr/bin/env bash
# Bring a Jellyfin instance up to the state this repo expects.
#
# Idempotent PER STEP, not all-or-nothing. An earlier version bailed out
# entirely if the startup wizard was already complete -- so if you'd clicked
# through the wizard in a browser first, the Movies library was never created
# and Jellyfin sat there empty forever. Each step below checks for its own
# result and skips only that.
set -euo pipefail

BASE="http://127.0.0.1:${JELLYFIN_PORT:-8096}"
MOVIES_DIR="${MOVIES_DIR:?MOVIES_DIR not set}"
SHOWS_DIR="${SHOWS_DIR:-}"
INSTALL_OPENSUBTITLES="${INSTALL_OPENSUBTITLES:-0}"
ADMIN_USER="${ADMIN_USER:-admin}"
PASSWORD_FILE="${ADMIN_PASSWORD_FILE:-/var/lib/secrets/jellyfin-admin-password}"
API_KEY_FILE="${JELLYFIN_API_KEY_FILE:-/var/lib/secrets/jellyfin-api-key}"
LANG_PREF="${METADATA_LANGUAGE:-en}"
COUNTRY="${METADATA_COUNTRY:-NO}"
JSON='Content-Type: application/json'

log()  { echo "[provision-jellyfin] $*"; }
warn() { echo "[provision-jellyfin] WARNING: $*" >&2; }
die()  { echo "[provision-jellyfin] ERROR: $*" >&2; exit 1; }

# --- wait for the server ----------------------------------------------------
for i in $(seq 1 60); do
  curl -fsS -o /dev/null "$BASE/System/Info/Public" 2>/dev/null && break
  [ "$i" = 60 ] && die "Jellyfin never came up."
  sleep 2
done

[ -r "$PASSWORD_FILE" ] || die "No admin password at $PASSWORD_FILE
  Create it with:
    sudo install -m600 /dev/null $PASSWORD_FILE
    sudo sh -c 'echo YOURPASSWORD > $PASSWORD_FILE'"
ADMIN_PASS="$(tr -d '\n' < "$PASSWORD_FILE")"

# --- step 1: startup wizard, only if not already done -----------------------
if curl -fsS "$BASE/System/Info/Public" | grep -q '"StartupWizardCompleted":true'; then
  log "Startup wizard: already complete, skipping."
else
  log "Startup wizard: running..."
  curl -fsS -o /dev/null -X POST "$BASE/Startup/Configuration" -H "$JSON" \
    -d "{\"UICulture\":\"en-US\",\"MetadataCountryCode\":\"$COUNTRY\",\"PreferredMetadataLanguage\":\"$LANG_PREF\"}"
  curl -fsS -o /dev/null "$BASE/Startup/User"
  curl -fsS -o /dev/null -X POST "$BASE/Startup/User" -H "$JSON" \
    -d "$(printf '{"Name":%s,"Password":%s}' \
          "$(printf '%s' "$ADMIN_USER" | jq -Rs .)" \
          "$(printf '%s' "$ADMIN_PASS"  | jq -Rs .)")"
  curl -fsS -o /dev/null -X POST "$BASE/Startup/RemoteAccess" -H "$JSON" \
    -d '{"EnableRemoteAccess":true,"EnableAutomaticPortMapping":false}'
  curl -fsS -o /dev/null -X POST "$BASE/Startup/Complete" -H "$JSON"
  log "Startup wizard: done."
fi

# --- authenticate -----------------------------------------------------------
AUTH_HDR='MediaBrowser Client="provision", Device="nixos", DeviceId="nixos-provision", Version="1.0"'
RESP="$(curl -fsS -X POST "$BASE/Users/AuthenticateByName" -H "$JSON" -H "Authorization: $AUTH_HDR" \
  -d "$(printf '{"Username":%s,"Pw":%s}' \
        "$(printf '%s' "$ADMIN_USER" | jq -Rs .)" \
        "$(printf '%s' "$ADMIN_PASS"  | jq -Rs .)")" 2>/dev/null)" || RESP=""

TOKEN="$(printf '%s' "$RESP" | jq -r '.AccessToken // empty' 2>/dev/null || true)"
if [ -z "$TOKEN" ]; then
  die "Could not log in as '$ADMIN_USER'.

  This usually means the startup wizard was completed by hand in a browser,
  with a different username or password than this script expects.

  Fix either side so they match:
    - put the real password in $PASSWORD_FILE, or
    - in Jellyfin, set user '$ADMIN_USER' to the password in that file,
      or create that user as an administrator.
  Then: sudo systemctl start jellyfin-provision"
fi
TOKEN_HDR="Authorization: MediaBrowser Token=\"$TOKEN\""
log "Authenticated as '$ADMIN_USER'."

# --- step 2: libraries, each only if missing --------------------------------
# Films and TV must be SEPARATE libraries with different collection types.
# Pointing a "movies" library at a folder of episodes catalogues every episode
# as its own film, with no season or series grouping.
ensure_library() {
  local name="$1" type="$2" path="$3"
  [ -n "$path" ] || return 0

  local existing
  existing="$(curl -fsS "$BASE/Library/VirtualFolders" -H "$TOKEN_HDR" 2>/dev/null || echo '[]')"
  if printf '%s' "$existing" | jq -e --arg p "$path" \
       'any(.[]; (.Locations // []) | index($p))' >/dev/null 2>&1; then
    log "Library '$name': already points at $path, skipping."
    return 0
  fi

  log "Library '$name': creating ($type) at $path ..."
  curl -fsS -o /dev/null -X POST \
    "$BASE/Library/VirtualFolders?collectionType=$type&refreshLibrary=true&name=$(jq -rn --arg v "$name" '$v|@uri')" \
    -H "$JSON" -H "$TOKEN_HDR" \
    -d "{\"LibraryOptions\":{\"PathInfos\":[{\"Path\":\"$path\"}],\"EnableRealtimeMonitor\":true}}" \
    || warn "Could not create '$name' -- add it by hand in Dashboard > Libraries."
}

ensure_library "Movies" "movies"  "$MOVIES_DIR"
ensure_library "Shows"  "tvshows" "$SHOWS_DIR"

# --- step 3: hardware acceleration ------------------------------------------
# Haswell: H.264 encode/decode in hardware, no HEVC decode -- deliberately
# absent from HardwareDecodingCodecs.
log "Hardware acceleration: configuring VAAPI..."
curl -fsS -o /dev/null -X POST "$BASE/System/Configuration/encoding" \
  -H "$JSON" -H "$TOKEN_HDR" -d '{
    "HardwareAccelerationType": "vaapi",
    "VaapiDevice": "/dev/dri/renderD128",
    "EnableHardwareEncoding": true,
    "HardwareDecodingCodecs": ["h264","mpeg2video","vc1"],
    "EnableTonemapping": false,
    "AllowHevcEncoding": false,
    "EnableThrottling": true
  }' || warn "Could not set encoding config -- set it in the UI if transcoding is slow."

# --- step 3b: Open Subtitles plugin -----------------------------------------
# Adds a "Search subtitles" button to each item so you can browse releases and
# pick one by hand, which the automatic fetcher can't do. Installed through the
# API so it's described here rather than being undocumented state on the box.
#
# Jellyfin stores plugin settings in its own database, so the opensubtitles.com
# credentials still have to be entered once in the UI -- see INSTALL.md.
if [ "$INSTALL_OPENSUBTITLES" = "1" ]; then
  OS_GUID="4b9ed42f518548b598036ff2989014c4"
  if curl -fsS "$BASE/Plugins" -H "$TOKEN_HDR" 2>/dev/null \
       | jq -e --arg g "$OS_GUID" 'any(.[]; (.Id // "") | ascii_downcase == $g)' >/dev/null 2>&1; then
    log "Open Subtitles plugin: already installed, skipping."
  else
    log "Open Subtitles plugin: installing..."
    if curl -fsS -o /dev/null -X POST \
         "$BASE/Packages/Installed/Open%20Subtitles?assemblyGuid=$OS_GUID" \
         -H "$TOKEN_HDR"; then
      log "Open Subtitles plugin: installed. RESTART JELLYFIN to load it:"
      log "  sudo systemctl restart jellyfin"
      log "Then add your opensubtitles.com login in Dashboard > Plugins > Open Subtitles."
    else
      warn "Could not install the Open Subtitles plugin.
  Install it by hand: Dashboard > Plugins > Catalogue > Open Subtitles."
    fi
  fi
fi

# --- step 4: an API key, so the library-refresh timer can work --------------
# Without this, refresh-library.service skips every run and newly added films
# never appear until you rescan by hand.
if [ -s "$API_KEY_FILE" ]; then
  log "API key: already present, skipping."
else
  log "API key: creating one for the refresh timer..."
  curl -fsS -o /dev/null -X POST "$BASE/Auth/Keys?app=nixos-library-refresh" -H "$TOKEN_HDR" || true
  NEWKEY="$(curl -fsS "$BASE/Auth/Keys" -H "$TOKEN_HDR" 2>/dev/null \
            | jq -r '[.Items[]? | select(.AppName=="nixos-library-refresh")] | last | .AccessToken // empty')"
  if [ -n "$NEWKEY" ]; then
    install -m600 /dev/null "$API_KEY_FILE"
    printf '%s' "$NEWKEY" > "$API_KEY_FILE"
    log "API key: saved to $API_KEY_FILE"
  else
    warn "Could not create an API key. Automatic library refresh will be skipped.
  Make one in Dashboard > API Keys and save it to $API_KEY_FILE"
  fi
fi

# --- step 5: kick off a scan now --------------------------------------------
log "Requesting a library scan..."
curl -fsS -o /dev/null -X POST "$BASE/Library/Refresh" -H "$TOKEN_HDR" \
  || warn "Scan request failed."

log "Done."
