## 1. Repository skeleton

- [x] 1.1 Create `flake.nix` with nixpkgs + disko inputs and a `media` nixosConfiguration
- [x] 1.2 Create `settings.nix` holding every operator-tunable value (hostname, static IP, timezone, username, SSH key, disk device, media path, subtitle languages, ports, repo URL)
- [x] 1.3 Create `hosts/media/disko.nix` describing the single-disk GPT/ESP/ext4 layout
- [x] 1.4 Create `hosts/media/hardware.nix` for the Haswell machine (kernel modules, filesystems placeholder)
- [x] 1.5 Add `.gitignore` and a `README.md` pointing at `INSTALL.md`

## 2. Base system

- [x] 2.1 `modules/base.nix`: locale, timezone, console, nix settings, flakes enabled
- [x] 2.2 `modules/users.nix`: the operator account, wheel membership, authorized SSH key from settings
- [x] 2.3 `modules/ssh.nix`: key-only SSH, no root login, no password auth
- [x] 2.4 `modules/network.nix`: static IP, firewall allowing only SSH/Jellyfin/File Browser/Samba, avahi for `.local`
- [x] 2.5 `modules/maintenance.nix`: `nix.gc.automatic`, store optimisation, boot generation limit, `system.autoUpgrade` from the repo URL

## 3. jellyfin-web patch

- [x] 3.1 Write `patches/jellyfin-web-subtitle-no-redundant-rerender.patch` guarding `updateSubtitleText` on cue identity
- [x] 3.2 Add `overlays/jellyfin-web.nix` applying the patch via `overrideAttrs`
- [x] 3.3 Verify the patched package builds and the patch applies cleanly against the pinned jellyfin-web version
- [x] 3.4 Document in the patch header what it does, why, and how to re-verify after an upstream bump

## 4. Media server

- [x] 4.1 `modules/jellyfin.nix`: enable Jellyfin, open its port, set media group ownership
- [x] 4.2 Enable VAAPI: `hardware.graphics` with Intel driver packages, add the Jellyfin user to `render`/`video`
- [x] 4.3 Point the transcode directory at a tmpfs
- [x] 4.4 Wire the overlay so Jellyfin serves the patched web client
- [x] 4.5 `scripts/provision-jellyfin.sh`: idempotent first-run provisioning over the REST API (wizard, admin user, movie library, hardware acceleration)
- [x] 4.6 `modules/jellyfin-provision.nix`: oneshot systemd unit running the provisioning script after Jellyfin starts, reading the admin password from `/var/lib/secrets/`

## 5. Subtitle pipeline

- [x] 5.1 `scripts/extract-subtitles.sh`: for each MKV newer than its marker, probe streams and extract every text subtitle track to `<movie>.<lang>.srt`, skipping bitmap formats and existing files
- [x] 5.2 `modules/subtitle-extract.nix`: systemd service + timer running the extraction script
- [x] 5.3 `scripts/fetch-subtitles.sh`: run `subliminal` for the configured languages against movies with no sidecar
- [x] 5.4 `modules/subtitle-fetch.nix`: systemd service + timer for the fetcher
- [x] 5.5 Ensure both timers trigger a Jellyfin library refresh when they produce new files

## 6. Media ingest

- [x] 6.1 `modules/samba.nix`: share the media directory on the LAN with a dedicated user, credentials read from `/var/lib/secrets/`
- [x] 6.2 `modules/filebrowser.nix`: File Browser service rooted at the media directory, port opened in the firewall
- [x] 6.3 Make group ownership and umask consistent so uploads via either route stay readable by Jellyfin and the timers

## 7. hover-translate adapter (separate repo)

- [x] 7.1 Add an optional `getVideoElement()` hook to `ISiteAdapter`, defaulting to `document.querySelector("video")`
- [x] 7.2 Use that hook in `videoController.ts` instead of querying directly
- [x] 7.3 Add `JellyfinSiteAdapter` with container/window/segment selectors for `.videoSubtitles` / `.videoSubtitlesInner`
- [x] 7.4 Strip leading bidi control characters (U+200E and friends) when splitting words
- [x] 7.5 Register the adapter in `content.ts` and add the Jellyfin host to the manifest match patterns
- [ ] 7.6 Verify hover translation against the patched Jellyfin end to end
      (adapter contract verified by simulating the splitter against a live patched
      Jellyfin: selectors resolve, 1 split per cue, spans survive 60/60 samples,
      bidi marks stripped. Loading the packed extension in Chrome is still untested.)

## 8. Operator documentation

- [x] 8.1 Write `INSTALL.md`: USB boot, network, disk, install command, first boot
- [x] 8.2 Document SSH key setup and the git pull/update workflow, including rollback
- [x] 8.3 Document the secrets files the operator must create
- [x] 8.4 Document the one manual per-browser step (subtitle styling → `Custom`) and why it matters
- [x] 8.5 Document adding movies, the projector/casting path, and its known subtitle limitation

## 9. Verification

- [x] 9.1 `nix flake check` and a successful `nixos-rebuild build` of the full configuration
- [x] 9.2 Confirm the patched web client is the one being served
- [ ] 9.3 Re-run the subtitle measurement on the real server: rewrites must equal cue changes
      (verified on a local instance of the nix-built patched client: 3 rewrites /
      3 cue changes, ratio 1.00, vs 52 / 2 unpatched)
- [ ] 9.4 Confirm playback is direct play with no transcoding for a representative file
- [ ] 9.5 Confirm an `.ass`-only movie gains a working `.srt` sidecar
      (extraction script verified locally against an ASS-only MKV: produced clean
      plain-text .srt, second run was a no-op)
