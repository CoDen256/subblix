# Applies our subtitle re-render fix on top of the official jellyfin-web.
#
# We are NOT forking Jellyfin. nixpkgs' jellyfin-web derivation already has a
# `patches` list (it ships an upstream security patch); we append one more file
# to it. Dependencies are untouched, so npmDepsHash stays valid.
#
# If an upstream bump makes the patch stop applying, the BUILD FAILS loudly.
# It will never silently revert to the unpatched behaviour.
final: prev: {
  jellyfin-web = prev.jellyfin-web.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      ../patches/jellyfin-web-subtitle-no-redundant-rerender.patch
    ];
  });
}
