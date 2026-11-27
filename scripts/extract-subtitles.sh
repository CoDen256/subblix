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
# Only these languages are extracted. A film can easily carry 20+ subtitle
# tracks; pulling them all out just clutters the picker with languages you
# will never select. Space-separated ISO 639-2/B codes.
WANTED_LANGS="${WANTED_LANGS:-nor nob nno deu ger eng}"
mkdir -p "$STATE_DIR"

log() { echo "[extract-subtitles] $*"; }
changed=0

# Is this track in one of the languages we care about?
# Norwegian appears as nor/nob/nno and German as deu/ger depending on who
# tagged the file, so each wanted language needs all of its aliases listed.
is_wanted_lang() {
  local want
  for want in $WANTED_LANGS; do
    [ "$1" = "$want" ] && return 0
  done
  return 1
}

# Which codecs actually NEED extracting?
#
# Only the ones Jellyfin's web player cannot put into the DOM. It routes
# .ass/.ssa to a <canvas> via libass BEFORE consulting the subtitle-styling
# setting, so those are unreadable to the browser extension no matter what --
# they are the whole reason this script exists.
#
# Everything else that is already text (subrip, mov_text, webvtt...) renders
# straight into .videoSubtitlesInner as plain text. Extracting those produced
# a duplicate sidecar for a track that already worked, which is why films
# showed two identical English entries in the picker.
#
# Bitmap formats (pgssub, dvdsub) can't be converted without OCR; the subtitle
# fetcher covers those films instead.
needs_extraction() {
  case "$1" in
    ass|ssa) return 0 ;;
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

    if ! needs_extraction "$codec"; then
      log "  stream $stream_index: $codec needs no sidecar - skipping"
      continue
    fi

    if ! is_wanted_lang "$language"; then
      log "  stream $stream_index: language '$language' not wanted - skipping"
      continue
    fi

    # ".ext" marks it as extracted-by-us, so it can never collide with a
    # subtitle downloaded by the fetcher for the same language.
    out="${base}.${language}.ext.srt"
    [ -e "$out" ] && out="${base}.${language}.${stream_index}.ext.srt"

    if [ -e "$out" ]; then
      continue
    fi

    log "  stream $stream_index ($codec/$language) -> $(basename "$out")"
    # -c:s srt flattens ASS styling tags down to plain text, which is exactly
    # what we want: styled markup would only get in the extension's way.
    if ffmpeg -nostdin -v error -y -i "$movie" -map "0:$stream_index" -c:s srt "$out" 2>/dev/null; then
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
