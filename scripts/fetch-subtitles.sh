#!/usr/bin/env bash
# Download subtitles for films that don't have one in your languages.
#
# Uses subliminal rather than Jellyfin's OpenSubtitles plugin: plugin state
# lives in Jellyfin's database and can't be expressed in the flake, which is
# exactly the kind of "config that only exists on the machine" this repo
# is trying to avoid.
set -euo pipefail

MEDIA_DIR="${MEDIA_DIR:?MEDIA_DIR not set}"
LANGS="${SUBTITLE_LANGS:-no de en}"
STATE_DIR="${STATE_DIR:-/var/lib/subtitle-extract}"
mkdir -p "$STATE_DIR"

log() { echo "[fetch-subtitles] $*"; }

lang_args=()
for l in $LANGS; do lang_args+=( -l "$l" ); done

log "Looking for missing subtitles (${LANGS}) under $MEDIA_DIR"

# subliminal skips files that already have a matching subtitle, so this is
# safe to run repeatedly and will not overwrite anything you already have.
if subliminal download "${lang_args[@]}" "$MEDIA_DIR" 2>&1 | tee /tmp/subliminal.out; then
  if grep -qiE "downloaded [1-9]" /tmp/subliminal.out; then
    log "New subtitles downloaded; requesting a library refresh."
    echo refresh > "$STATE_DIR/needs-refresh"
  else
    log "Nothing new."
  fi
else
  log "subliminal exited non-zero (often just 'no subtitles found'); continuing."
fi
