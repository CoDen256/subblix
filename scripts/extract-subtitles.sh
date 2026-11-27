#!/usr/bin/env bash
# Pull text subtitle tracks out of video files into plain .srt sidecars.
#
# WHY THIS EXISTS: Jellyfin's web player draws .ass/.ssa subtitles onto a
# <canvas> via libass. Canvas pixels contain no text, so a browser extension
# can never read them. The format check happens BEFORE the styling check, so
# no Jellyfin setting can change this. A sidecar .srt is the only way to get
# those subtitles into the DOM -- and sidecars behave identically to embedded
# SRT once there.
#
# Bitmap subtitles (PGS/DVD) are deliberately skipped: OCR is slow on this CPU
# and poor for Norwegian. fetch-subtitles.sh handles those films instead.
set -euo pipefail

MOVIES_DIR="${MOVIES_DIR:?MOVIES_DIR not set}"
STATE_DIR="${STATE_DIR:-/var/lib/subtitle-extract}"
mkdir -p "$STATE_DIR"

log() { echo "[extract-subtitles] $*"; }
changed=0

# Text formats we can convert. Anything else (pgssub, dvdsub) is bitmap.
is_text_codec() {
  case "$1" in
    subrip|srt|ass|ssa|mov_text|text|webvtt|vtt|sami|smi) return 0 ;;
    *) return 1 ;;
  esac
}

shopt -s nullglob globstar nocaseglob
for movie in "$MOVIES_DIR"/**/*.{mkv,mp4,avi,m4v,webm}; do
  [ -f "$movie" ] || continue

  # Skip files we've already handled and which haven't changed since.
  marker="$STATE_DIR/$(printf '%s' "$movie" | sha256sum | cut -d' ' -f1).done"
  if [ -f "$marker" ] && [ "$marker" -nt "$movie" ]; then
    continue
  fi

  log "Scanning: $(basename "$movie")"
  base="${movie%.*}"

  # One line per subtitle stream:  index,codec_name,language
  streams="$(ffprobe -v error -select_streams s \
      -show_entries 'stream=index,codec_name:stream_tags=language' \
      -of csv=p=0:nk=1 "$movie" 2>/dev/null || true)"
  [ -n "$streams" ] || { touch "$marker"; continue; }

  while IFS=',' read -r stream_index codec language; do
    [ -n "${stream_index:-}" ] || continue
    codec="${codec:-unknown}"
    language="${language:-und}"

    if ! is_text_codec "$codec"; then
      log "  stream $stream_index: $codec is bitmap - skipping (subtitle fetcher will cover it)"
      continue
    fi

    out="${base}.${language}.srt"
    # More than one track in the same language: disambiguate.
    [ -e "$out" ] && out="${base}.${language}.${stream_index}.srt"

    if [ -e "$out" ]; then
      continue
    fi

    log "  stream $stream_index ($codec/$language) -> $(basename "$out")"
    # -c:s srt flattens ASS styling tags down to plain text, which is exactly
    # what we want: styled markup would only get in the extension's way.
    if ffmpeg -v error -y -i "$movie" -map "0:$stream_index" -c:s srt "$out" 2>/dev/null; then
      chmod 0664 "$out" || true
      changed=1
    else
      log "  WARNING: extraction failed for stream $stream_index"
      rm -f "$out"
    fi
  done <<< "$streams"

  touch "$marker"
done

if [ "$changed" = 1 ]; then
  log "New subtitles written; requesting a library refresh."
  echo refresh > "$STATE_DIR/needs-refresh"
fi
log "Done."
