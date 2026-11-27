#!/usr/bin/env bash
#
# One-shot installer, meant to be run from the NixOS installer USB:
#
#   curl -sL https://raw.githubusercontent.com/CoDen256/subblix/main/scripts/install.sh | sudo bash
#
# It reads the disk from your settings.nix, shows you what will be erased,
# makes you type it back, then partitions and installs. To point it at a
# different repo or host:
#
#   REPO=github:you/yourrepo HOST=media sudo -E bash ...
#
set -euo pipefail

REPO="${REPO:-github:CoDen256/subblix}"
HOST="${HOST:-media}"
# Flakes may not be on by default in the installer; this turns them on for
# every nix call below without needing to quote flags through word splitting.
export NIX_CONFIG="experimental-features = nix-command flakes"

red()  { printf '\033[31m%s\033[0m\n' "$*"; }
grn()  { printf '\033[32m%s\033[0m\n' "$*"; }
bold() { printf '\033[1m%s\033[0m\n' "$*"; }
die()  { red "ERROR: $*"; exit 1; }

[ "$(id -u)" -eq 0 ] || die "Run this with sudo."

bold "=== Media server installer ==="
echo "Repo: $REPO#$HOST"
echo

# ---------------------------------------------------------------- checks ----
grn "Checking internet..."
curl -sfI --max-time 10 https://cache.nixos.org >/dev/null \
  || die "No internet. Plug in the network cable and try again."

# ------------------------------------------------------------------ disk ----
grn "Reading your configuration from $REPO ..."
DISK_CFG="$(nix eval --raw "$REPO#nixosConfigurations.$HOST.config.disko.devices.disk.main.device")" \
  || die "Couldn't read the config. Is $REPO pushed and public?"

bold "Disks on this machine:"
lsblk -dpno NAME,SIZE,MODEL | sed 's/^/  /'
echo

DISK="$DISK_CFG"

if [ ! -b "$DISK" ]; then
  red "Your settings.nix says the disk is:  $DISK_CFG"
  red "...but that device does not exist on this machine."
  echo
  echo "Pick the right one from the list above, then:"
  echo "  fix 'diskDevice' in settings.nix, commit, push, and re-run this."
  echo
  die "Nothing has been changed."
fi

SIZE="$(lsblk -dpno SIZE "$DISK" | head -1 | tr -d ' ')"
MODEL="$(lsblk -dpno MODEL "$DISK" | head -1 | sed 's/^ *//;s/ *$//')"

echo
red  "################################################################"
red  "#  EVERYTHING ON THIS DISK WILL BE PERMANENTLY ERASED           #"
red  "################################################################"
echo "   Disk:  $DISK"
echo "   Size:  $SIZE"
echo "   Model: ${MODEL:-unknown}"
echo
# Read from the terminal, not stdin: when this script is piped from curl,
# stdin is the script text itself.
[ -r /dev/tty ] || die "No terminal available to confirm on. Download the script and run it directly instead of piping it."
printf 'Type the disk path exactly to confirm (%s): ' "$DISK"
read -r CONFIRM </dev/tty
echo
[ "$CONFIRM" = "$DISK" ] || die "That didn't match. Nothing has been changed."

# ------------------------------------------------------- network card -------
echo
bold "Wired network cards (note the name for later — you'll want it if you"
bold "ever switch from DHCP to a fixed address):"
ip -br link | awk '$1 !~ /^(lo|docker|veth|wl)/ {printf "  %s  %s\n", $1, $2}'
echo

# ------------------------------------------------------------- install ------
grn "Partitioning and formatting $DISK ..."
nix run github:nix-community/disko -- --mode disko --flake "$REPO#$HOST"

grn "Installing the system. This compiles Jellyfin's web client with the"
grn "subtitle patch — 10-30 minutes is normal. Go make a coffee."
echo
nixos-install --flake "$REPO#$HOST"

# -------------------------------------------------------------- finish ------
echo
grn "################################################################"
grn "#  Done.                                                       #"
grn "################################################################"
cat <<'NEXT'

Next:
  1. reboot, and remove the USB stick
  2. Log in at this monitor as root, with the password you just set
  3. Give your own account a password too:   passwd <your-username>
  4. Find its address:                       ip addr
  5. From your laptop:                       ssh <your-username>@<that-address>

Then carry on from Step 8 in INSTALL.md.
NEXT
