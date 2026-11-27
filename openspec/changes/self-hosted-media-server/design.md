## Context

A headless Intel i5-4570 (Haswell, 4 cores), 12 GB RAM, single 500 GB SSD shared between the OS and media. Movies are personal MKVs, watched in original language (Norwegian, German, English). Two viewing paths: cast from a phone to a Xiaomi Mi Smart Projector 2 (Android TV with Chromecast built in), and watched directly in desktop Chromium where the `hover-translate` extension translates individual subtitle words on hover. Access is LAN-only. The configuration lives in a public GitHub repo and the server updates itself from it.

An empirical spike against Jellyfin 10.11.11 established the facts this design rests on:

- With subtitle styling `Custom`, Jellyfin renders text subtitles into `.videoSubtitles > .videoSubtitlesInner` as plain text. With the default `Auto`, Chromium gets native shadow-DOM rendering and the extension sees nothing. The setting lives in browser local storage under `<userId>-localplayersubtitleappearance3` and is never synced to the server.
- `updateSubtitleText` is driven by the `timeupdate` event and unconditionally re-assigns `innerHTML`. Measured: 35 rewrites per 15 s for 2 actual cue changes (~every 266 ms). Injected word spans went from 7 to 0 within 400 ms, permanently.
- `.ass`/`.ssa` are routed to `libass-wasm` on a canvas *before* the styling check, so `Custom` has no effect on them. Sidecar `.srt` files behave identically to embedded SRT.
- Every cue is prefixed with U+200E (LEFT-TO-RIGHT MARK) by `normalizeTrackEventText`.
- The Jellyfin startup wizard, admin user, library creation and hardware-acceleration settings are all reachable over the REST API.

## Goals / Non-Goals

**Goals:**
- One git repo describes the entire machine; `nixos-install --flake` reproduces it.
- Text subtitles arrive in the browser DOM and stay stable for the duration of each cue.
- Playback avoids server-side transcoding in the common case.
- Routine operator changes are confined to one settings file.
- First run requires no manual wizard clicking.

**Non-Goals:**
- OCR of bitmap (PGS) subtitles.
- Internet exposure, reverse proxy, TLS, or VPN.
- Translated subtitles on the projector (possible later via a secondary subtitle track).
- Replacing the Jellyfin web UI.
- 4K HEVC transcoding.
- Automating the per-browser subtitle styling setting.

## Decisions

### Patch jellyfin-web rather than adopt an alternative client

`updateSubtitleText` rewrites the subtitle element on every `timeupdate` regardless of whether the cue changed. A nine-line guard storing the last rendered cue per slot fixes it:

```
if (selectedTrackEvent?.Text) {
    if (this.#lastRenderedTrackEvents[i] !== selectedTrackEvent) {
        this.#lastRenderedTrackEvents[i] = selectedTrackEvent;
        subtitleTextElement.innerHTML = DOMPurify.sanitize(...);
        subtitleTextElement.classList.remove('hide');
    }
} else if (this.#lastRenderedTrackEvents[i] !== null) {
    this.#lastRenderedTrackEvents[i] = null;
    subtitleTextElement.classList.add('hide');
}
```

Verified by building the patched client and re-running the measurement: 2 rewrites for 2 cue changes, and injected spans present in all 60 samples across 12 s.

The nixpkgs `jellyfin-web` derivation already exposes a `patches` list (it currently carries an upstream security patch), so this is an `overrideAttrs` with one extra file. Dependencies are untouched, so `npmDepsHash` does not change.

*Alternatives considered.* **Litefin**, an alternative Jellyfin web client, was built and measured and is equally correct (1:1 rewrites, no LRM, no setting needed, nicer UI). Rejected because it is nine months old with a single maintainer, is absent from nixpkgs, needs ~800 MB of build dependencies hand-packaged, and hides its `<video>` inside a `<movi-player>` shadow root. A nine-line patch against the official client is a smaller permanent liability. **jellyfin-vue** was rejected: explicitly experimental, no stable release. **A mirror layer in the extension** was rejected by the operator, and would have been permanent complexity in the wrong place.

The patch is intended for upstream submission; if accepted it eventually disappears from this repo.

### Keep the LRM prefix; strip it in the adapter

The U+200E prefix is deliberate upstream ("Force LTR as the default direction") and removing it risks breaking right-to-left languages. The word splitter in the extension strips leading bidi control characters instead. This keeps the patch minimal and upstreamable.

### Native NixOS services, not Docker

Jellyfin, Samba and the timers all exist as NixOS modules. Docker would add a second layer to version for no gain, and the VAAPI device permissions are two lines natively.

### Sidecar extraction as a systemd timer

A timer scans the media tree for MKVs newer than their marker file and runs `ffmpeg` once per embedded text subtitle track, writing `<movie>.<lang>.srt`. This exists specifically so `.ass` tracks, which are otherwise canvas-only, have a DOM-readable equivalent. Tracks are named so the sidecar is distinguishable from the embedded original in the picker.

*Alternative considered.* Remuxing the MKV to drop the ASS track. Rejected as destructive to the original file.

### `subliminal` timer instead of the Jellyfin OpenSubtitles plugin

Plugin installation and configuration are imperative state under `/var/lib/jellyfin` and cannot be expressed in the flake — precisely the hole this project is trying to avoid. A `subliminal` timer is a few declarative lines. Bazarr was ruled out because it has no standalone library scanner and expects Radarr.

### First-run provisioning over the REST API

A oneshot unit runs after Jellyfin starts and, if the startup wizard is incomplete, drives `/Startup/*`, creates the library via `/Library/VirtualFolders`, and sets hardware acceleration. The spike confirmed every one of these calls returns 204. Idempotent: it checks `StartupWizardCompleted` and exits early.

### Secrets by path, not in the repo

The repo is public. The Samba password file and any API credential live under `/var/lib/secrets/`, created once by the operator and referenced by path. `agenix`/`sops-nix` is deliberately deferred — for a single-user LAN server it is complexity without benefit.

### Transcode scratch on tmpfs

Transcoding output goes to a tmpfs rather than the SSD, sparing write amplification on the single shared disk. Sized conservatively against 12 GB of RAM.

## Risks / Trade-offs

- **The patch stops applying after a jellyfin-web update** → the anchor is a small, stable block; the build fails loudly rather than silently reverting, and `flake.lock` pins the version so the operator chooses when to bump. Checklist documents re-verification.
- **The server must compile jellyfin-web** (~90 s on a modern machine, longer on the i5, webpack needs a few GB of RAM) → acceptable for occasional updates; the alternative is a binary cache, deferred.
- **The `Custom` subtitle setting silently resets** on a new browser profile or after clearing site data, and the failure mode is invisible (subtitles still display) → documented prominently in the checklist as the first thing to check if hover translation stops working.
- **HEVC cannot be hardware-decoded on Haswell** → design targets direct play; the projector's Android TV app and desktop Chromium both decode HEVC themselves. 4K HEVC is out of scope.
- **Single disk, no redundancy** → media is replaceable and the configuration is in git; accepted. Nix GC and a boot-entry cap keep the OS from crowding out media.
- **`.local` mDNS resolution is unreliable on Android** → a static IP is the primary address, mDNS a convenience.
- **Casting bypasses the extension** → inherent; the projector renders its own subtitles. Noted as a known limitation, with a secondary-subtitle track as a possible future route.

## Migration Plan

This is a greenfield install, so "migration" is first deployment:

1. Operator writes the NixOS installer to USB and boots the target machine.
2. Operator edits `settings.nix` (hostname, IP, disk, SSH key, languages) and pushes.
3. From the installer shell: partition via disko, then `nixos-install --flake <repo>#media`.
4. Reboot; the provisioning unit configures Jellyfin on first start.
5. Operator copies movies in over Samba and sets subtitle styling to `Custom` in their browser.

Rollback: every rebuild creates a new generation. A bad update is recovered by selecting the previous generation at the boot menu, or `nixos-rebuild switch --rollback` over SSH.

## Open Questions

- Whether a server-side transcode forces subtitle burn-in could not be reproduced locally (localhost counts as LAN, so bitrate caps were ignored, and the test machine direct-plays HEVC). Code review indicates burn-in requires `alwaysBurnInSubtitleWhenTranscoding`, which defaults off. To be confirmed on the real server.
- Whether to submit the patch upstream immediately or after running it locally for a while.
- Whether a secondary translated subtitle track for the projector is worth building later.
