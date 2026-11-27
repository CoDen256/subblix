## Why

Personal MKV movies (Norwegian, German, English) need to be watchable two ways: cast to a Xiaomi Mi Smart Projector 2, and watched in a desktop browser where the `hover-translate` extension can read each subtitle word and translate it on hover. Jellyfin's web client renders text subtitles into the DOM only after a per-browser setting change, and then rewrites that DOM element roughly four times per second even when the subtitle has not changed — which destroys any word spans an extension injects, making hover translation unusable.

The whole server must also be reproducible from a public git repo: one `nixos-install` from a USB stick, then unattended self-updates.

## What Changes

- New NixOS flake describing the entire server: disk layout, users, SSH, firewall, networking, media storage, and services. Deployed by `nixos-install --flake` once, then `system.autoUpgrade` from a public GitHub repo.
- Jellyfin as the media server, with Intel QuickSync (VAAPI) enabled for the Haswell i5-4570, tuned to prefer direct play over transcoding.
- **Patched `jellyfin-web`**: a 9-line patch to `updateSubtitleText` so the subtitle element is rewritten only when the active cue actually changes. Applied through the existing `patches` list in the nixpkgs derivation via an overlay. Measured effect: DOM rewrites drop from 35-per-2-cue-changes to 1:1.
- Subtitle sidecar pipeline: a systemd timer that extracts embedded text subtitle tracks (`srt`, `ass`, `ssa`) from new MKVs into plain `.srt` files beside the movie, because `.ass` is otherwise drawn to a canvas and is invisible to the extension. PGS/bitmap OCR is an explicit non-goal.
- Subtitle fetching for `no`, `de`, `en` via a `subliminal` systemd timer, chosen over the Jellyfin OpenSubtitles plugin because plugin state is imperative and cannot live in git.
- Samba share plus a File Browser web uploader for getting movies onto the server.
- First-run server provisioning script driving Jellyfin's REST API (startup wizard, admin user, libraries, hardware acceleration) so a reinstall yields a working server without manual clicking.
- New `hover-translate` site adapter for Jellyfin, plus a small optional `getVideoElement()` hook on `ISiteAdapter`. (Implemented in the separate `hover-translate` repo; tracked here because the contract is defined by this change.)
- Operator checklist (`INSTALL.md`) covering USB boot, install, SSH keys, git pipeline, and updates.

## Capabilities

### New Capabilities
- `nixos-deployment`: declarative, reproducible installation and unattended update of the whole server from a public git repo.
- `media-server`: Jellyfin service configuration, hardware transcoding policy, storage layout, and first-run provisioning.
- `dom-subtitles`: the guarantee that text subtitles reach the browser as stable DOM text an extension can read, including the jellyfin-web patch and the sidecar extraction pipeline.
- `subtitle-acquisition`: locating and downloading missing subtitles for the configured languages.
- `media-ingest`: getting new movie files onto the server (Samba, web uploader).

### Modified Capabilities
<!-- None. This is the first change in the repo; openspec/specs/ is empty. -->

## Impact

- **New repo contents**: `flake.nix`, `settings.nix`, `hosts/`, `modules/`, `patches/`, `scripts/`, `INSTALL.md`.
- **Upstream dependency**: patch targets `jellyfin-web` 10.11.x `src/plugins/htmlVideoPlayer/plugin.js`. The patch must be re-verified on each jellyfin-web minor bump; the anchor is small and stable but not guaranteed.
- **Build cost**: patching jellyfin-web means the server compiles it rather than fetching a cached binary (~90 s on a modern machine, longer on the i5-4570, and webpack needs a few GB of RAM).
- **Secrets**: the repo is public, so no secrets may be committed. Samba credentials and any API keys are placed out-of-band on the server.
- **Separate repo**: `hover-translate` gains a Jellyfin adapter and one optional interface hook.
- **Hardware limits**: the i5-4570 cannot hardware-decode HEVC; design assumes direct play, with transcoding as a fallback only.
