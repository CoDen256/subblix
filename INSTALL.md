# Setting up the media server

Follow this top to bottom. Every command says which machine to run it on:

- **[laptop]** — the computer you're using now
- **[server]** — the headless box (via the USB installer, or later over SSH)

If something goes wrong, jump to [When things break](#when-things-break).

---

## Before you start

You need:

- The headless PC, plugged into the network with a cable
- Your NixOS installer USB stick
- A monitor + keyboard on the server **for the install only** — you can unplug them afterwards
- The server's disk will be **completely erased**

---

## Step 1 — Get your SSH key [laptop]

This is how you'll log into the server. Without it you'll be locked out.

```bash
# Do you already have one?
cat ~/.ssh/id_ed25519.pub
```

If that prints a line starting with `ssh-ed25519`, you're set — copy it.
If it says "No such file", make one:

```bash
ssh-keygen -t ed25519 -C "you@yourmachine"   # press Enter at every prompt
cat ~/.ssh/id_ed25519.pub
```

Copy the whole line it prints.

---

## Step 2 — Fill in your settings [laptop]

Open `settings.nix`. It's the only file you need to edit. Change these:

| Setting | What to put |
|---|---|
| `sshPublicKey` | The line you just copied. **Most important — don't skip.** |
| `username` | Your login name on the server |
| `diskDevice` | The disk to install on (you'll confirm this in Step 4) |
| `staticIp` | A free address on your network, e.g. `192.168.1.50` |
| `gateway` | Your router's address, usually `192.168.1.1` |
| `repoUrl` | Your GitHub repo, e.g. `github:yourname/subblix` |
| `timezone` | e.g. `Europe/Oslo` |

Leave everything else alone for now.

---

## Step 3 — Push it to GitHub [laptop]

The server installs itself *from GitHub*, so your settings have to be there first.

```bash
cd ~/dev/subblix
git init                       # only if this isn't a repo yet
git add -A
git commit -m "My media server configuration"
git branch -M main
git remote add origin https://github.com/YOURNAME/subblix.git
git push -u origin main
```

> **The repo is public, so never commit passwords or private keys.**
> Only your *public* key goes in here — that one is safe to share.

---

## Step 4 — Boot the installer [server]

1. Plug in the USB stick, monitor and keyboard.
2. Turn the server on and open the boot menu (usually `F12`, `F11` or `Esc`).
3. Pick the USB stick.
4. Wait for the shell prompt.

Then find your disk and check the network:

```bash
lsblk                 # find the disk - a 500GB one, likely "sda" or "nvme0n1"
ping -c3 github.com   # confirm you're online
```

**If `lsblk` shows something other than `sda`**, go back to `settings.nix`,
fix `diskDevice`, commit and push again (Step 3) before continuing.

> Tip: `/dev/sda` can change between boots. A safer value is the stable name
> from `ls -l /dev/disk/by-id/`.

---

## Step 5 — Install [server]

Two commands. The first **erases the disk**.

```bash
# 1. Partition and format (ERASES EVERYTHING on that disk)
sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko -- \
  --mode disko --flake github:YOURNAME/subblix#media

# 2. Install the system
sudo nixos-install --flake github:YOURNAME/subblix#media --no-root-password
```

The second command takes a while — it builds Jellyfin's web interface with our
subtitle patch. **10–30 minutes on this hardware is normal.** Let it run.

When it finishes:

```bash
reboot
```

Pull out the USB stick. You can unplug the monitor and keyboard now — you
won't need them again.

---

## Step 6 — Log in from your laptop [laptop]

```bash
ssh yourusername@192.168.1.50      # the staticIp from settings.nix
```

No password — your key does it. If you get "Permission denied", see
[When things break](#when-things-break).

---

## Step 7 — Set the two passwords [server, over SSH]

These live **outside** the repo because the repo is public.

```bash
# Password for the Jellyfin admin account
sudo mkdir -p /var/lib/secrets
sudo sh -c 'echo "pick-a-password-here" > /var/lib/secrets/jellyfin-admin-password'
sudo chmod 600 /var/lib/secrets/jellyfin-admin-password

# Password for the network share (used when copying films in)
sudo smbpasswd -a yourusername
```

Then let Jellyfin configure itself:

```bash
sudo systemctl restart jellyfin-provision
sudo systemctl status jellyfin-provision     # should say "Done."
```

This creates your admin account, the Movies library, and turns on hardware
video support — no clicking through a setup wizard.

---

## Step 8 — Copy some films in [laptop]

Open your file manager and connect to the share:

- **Linux / macOS:** `smb://192.168.1.50/media`
- **Windows:** `\\192.168.1.50\media`

Log in with your username and the `smbpasswd` password from Step 7.
Drop `.mkv` files into the **movies** folder.

Or from a browser/phone: `http://192.168.1.50:8080`

Within 15 minutes the server will automatically:
- pull subtitles out of the files into separate `.srt` files
- download missing Norwegian / German / English subtitles
- add the films to your library

To not wait:

```bash
ssh yourusername@192.168.1.50 'sudo systemctl start subtitle-extract'
```

---

## Step 9 — The one manual browser setting ⚠️

**This is the step that makes subtitle translation work. Don't skip it.**

1. Open `http://192.168.1.50:8096` and sign in.
2. Click your **user icon** (top right) → **Settings** → **Subtitles**.
3. Set **Subtitle styling** to **Custom**.
4. Save.

### Why this matters

On the default setting, Chrome draws subtitles in a place web extensions
cannot reach. They look completely normal on screen — but your translation
extension sees nothing at all. There is no error message.

**This setting is stored in your browser, not on the server.** So you must
repeat it on every computer and every browser profile you watch from, and
again if you ever clear your browsing data.

> **If hover-translation ever stops working, check this setting first.**

---

## Step 10 — Watching

**On your computer (with translation):**
Open `http://192.168.1.50:8096`, play a film, hover over subtitle words.

**On the projector:**
Install the **Jellyfin** app from the Play Store on the projector and point it
at `192.168.1.50`. This works better than casting — it plays more files
without the server having to convert anything.

Or cast from the Jellyfin phone app.

> When you cast, the projector draws the subtitles itself, so the translation
> extension can't reach them. That's expected — translation is for watching
> on your computer.

---

## Everyday use

### Change a setting

```bash
# [laptop] edit settings.nix, then:
git add -A && git commit -m "what changed" && git push

# [server]
ssh yourusername@192.168.1.50 'sudo nixos-rebuild switch --flake github:YOURNAME/subblix#media --refresh'
```

The server also does this by itself every night at 04:30.

### Undo a bad update

```bash
ssh yourusername@192.168.1.50 'sudo nixos-rebuild switch --rollback'
```

Or, if it won't boot at all: attach a monitor, and at the boot menu pick an
older entry. Nothing is ever destroyed — every update is a new entry.

### Check on things

```bash
systemctl status jellyfin              # is the media server up?
systemctl list-timers                  # when do the subtitle jobs next run?
journalctl -u subtitle-extract -n 50   # what did subtitle extraction do?
df -h /                                # how full is the disk?
```

---

## When things break

**"Permission denied" when connecting over SSH**
Your public key didn't make it into the config. Check `sshPublicKey` in
`settings.nix` is the full line from `cat ~/.ssh/id_ed25519.pub`, that you
pushed it, and that you installed *after* pushing.

**Can't reach the server at all**
Try `ping 192.168.1.50`. If that fails, the static IP may clash with another
device or be outside your router's range. Attach a monitor, log in, run
`ip addr` to see the real address.

**Subtitle translation stopped working**
1. Re-check Step 9 — subtitle styling must be **Custom**. This is nearly
   always the cause.
2. Try a different subtitle track. Tracks marked `.ass` are drawn as an image
   and can't be read; pick the plain one the server extracted instead.
3. Force your browser to reload the player: `Ctrl+Shift+R`. Jellyfin caches
   its own code aggressively, so after a server update the browser may still
   be running the old version.

**Films play but have no subtitles**
Check what the subtitle jobs did:
`journalctl -u subtitle-extract -u subtitle-fetch -n 100`

**You see the same subtitle language listed twice**
Expected. One is built into the film, the other is the plain-text copy the
server extracted. Either works; prefer the extracted one.

**The install fails while building**
Almost always out of memory while building Jellyfin's web interface. The
server has 12 GB so this is unlikely, but if it happens, re-run the
`nixos-install` command — it resumes rather than starting over.

---

## What's running where

| What | Where |
|---|---|
| Jellyfin (watch films) | `http://192.168.1.50:8096` |
| File Browser (upload) | `http://192.168.1.50:8080` |
| Network share | `smb://192.168.1.50/media` |
| Films on disk | `/srv/media/movies` |
| Your passwords | `/var/lib/secrets/` (never in git) |
