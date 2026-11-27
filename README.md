# subblix — self-hosted media server

A headless NixOS box that streams personal MKV films, with subtitles that
arrive in the browser as **real DOM text** so the
[hover-translate](https://github.com/) extension can translate them word by word.

**→ [INSTALL.md](INSTALL.md) — start here.**

## What's in here

```
settings.nix        Everything you'd normally change. Usually the only file you touch.
flake.nix           Ties it all together.
hosts/media/        Disk layout and hardware for the physical box.
modules/            One file per concern: ssh, network, jellyfin, subtitles, ingest...
patches/            The jellyfin-web subtitle fix (see below).
overlays/           Applies that patch to the official package.
scripts/            Subtitle extraction, subtitle download, first-run provisioning.
openspec/           Why things are the way they are: proposal, design, specs.
```

## The one unusual thing: the jellyfin-web patch

Jellyfin's web player rewrites the on-screen subtitle element about **four
times a second**, even when the subtitle hasn't changed. Anything that
augments those subtitles — like wrapping each word in a hoverable span — gets
wiped out faster than it can be used.

Measured on stock Jellyfin 10.11.11:

| | Stock | Patched |
|---|---|---|
| DOM rewrites per 15s | 35 | 3 |
| Actual subtitle changes | 2 | 3 |
| Injected word spans | gone in 0.4s | survive the whole cue |

`patches/jellyfin-web-subtitle-no-redundant-rerender.patch` is **nine lines**.
It skips the DOM write when the active cue hasn't changed.

This is **not a fork**. nixpkgs' `jellyfin-web` package already supports
patches, so we append one file. You stay on official Jellyfin and get normal
updates. If an upstream change makes the patch stop applying, the build fails
loudly — it never silently reverts.

The patch is written to be submitted upstream; if accepted, it disappears
from here.

## Known limitations

- **One browser setting is manual.** Jellyfin's "Subtitle styling → Custom"
  lives in browser storage, not on the server, so it can't be automated and
  must be set on each browser. See Step 9 of INSTALL.md.
- **Casting bypasses translation.** The projector draws its own subtitles.
- **`.ass` subtitles are drawn as images** by the player, so the server
  extracts them to plain `.srt` alongside each film.
- **Bitmap (PGS) subtitles aren't OCR'd** — the subtitle downloader is used
  for those films instead.
- **HEVC can't be hardware-decoded** on this CPU (Haswell). The setup targets
  direct play; your PC and the projector decode it themselves.
