# Setting up the media server

Follow this top to bottom. Every command is labelled with where to run it:

- **[laptop]** — the computer you're using now
- **[server]** — the headless box, via the USB installer or later over SSH

Roughly 20 minutes of your time, plus up to half an hour of waiting while it builds.

---

## What you need

- The headless PC, connected to your router **with a network cable**
- Your NixOS installer USB stick
- **A monitor and keyboard on the server for Steps 4–6.** You can unplug them
  afterwards and never attach them again — but you do need them for the
  install itself. There is no way to install a headless machine blind.
- The server's disk will be **completely erased**

---

## Step 1 — Get your SSH key [laptop]

This is how you'll log in afterwards.

```bash
cat ~/.ssh/id_ed25519.pub
```

If that prints a line starting with `ssh-ed25519` or `ssh-rsa`, copy it.
If it says "No such file", create one first:

```bash
ssh-keygen -t ed25519 -C "you@yourmachine"   # press Enter at every prompt
cat ~/.ssh/id_ed25519.pub
```

---

## Step 2 — First pass at settings [laptop]

Open `settings.nix`. It's the only file you need to touch. Set these now:

| Setting | What to put |
|---|---|
| `sshPublicKey` | The line you just copied |
| `username` | Your login name on the server |
| `fullName` | Your name (cosmetic) |
| `timezone` | e.g. `Europe/Berlin` |
| `repoUrl` | Your repo, e.g. `github:yourname/subblix` |

**Leave the network settings alone for now.** They default to DHCP, which
always works. You can switch to a fixed address in Step 9, once the server can
tell you what its network card is called.

You'll come back and set `diskDevice` in Step 4.

---

## Step 3 — Push to GitHub [laptop]

The server installs itself *from GitHub*, so your settings must be there first.

```bash
cd ~/dev/subblix
git add -A
git commit -m "My media server settings"
git push
```

> The repo is public. Never commit passwords or private keys — only your
> **public** key, which is safe to share.

---

## Step 4 — Boot the installer and look around [server]

1. Plug in the USB stick, monitor and keyboard.
2. Power on and open the boot menu (usually `F12`, `F11` or `Esc`).
3. Choose the USB stick and wait for a shell prompt.

Then gather two facts:

```bash
lsblk                 # the disk: a ~500GB one, likely "sda" or "nvme0n1"
ip link               # the wired network card, e.g. "enp3s0" or "eno1"
ping -c3 github.com   # confirm you're online
```

Write down both names. `ip link` lists things like `lo`, `enp3s0`, `wlp2s0` —
you want the wired one, usually starting `en` or `eth`, showing `state UP`.
Ignore `lo`.

**If the disk isn't `sda`**, go back to `settings.nix` on your laptop, fix
`diskDevice`, and push again (Step 3) before continuing.

---

## Step 5 — Install [server]

One command:

```bash
curl -sL https://raw.githubusercontent.com/CoDen256/subblix/main/scripts/install.sh | sudo bash
```

It reads the disk from your pushed `settings.nix`, lists what's actually in the
machine, shows you exactly what will be erased, and **makes you type the disk
path back** before touching anything. If `diskDevice` doesn't match reality it
stops and tells you, without changing a thing.

<details>
<summary>Or do it by hand, if you'd rather see both steps</summary>

```bash
# 1. Partition and format (DESTROYS everything on that disk)
sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko -- \
  --mode disko --flake github:YOURNAME/subblix#media

# 2. Install
sudo nixos-install --flake github:YOURNAME/subblix#media
```

</details>

The install takes a while — it compiles Jellyfin's web interface with our
subtitle patch. **10–30 minutes on this hardware is normal.** Let it run.

At the end it asks you to **set a root password**. Do it, and remember it.
This is your way in at a monitor if the network ever misbehaves. Skipping it
is how you end up with a machine nobody can log into.

---

## Step 6 — First boot [server]

```bash
reboot
```

Pull out the USB stick. Let it boot, then log in at the monitor as `root` with
the password you just set, and give your own account one too:

```bash
passwd coden        # use your username
```

### Pre-flight — check these BEFORE the monitor goes away

Once you unplug, none of this is checkable any more. Thirty seconds now saves a
lot of pain later:

```bash
systemctl status sshd                  # running?
cat /etc/ssh/authorized_keys.d/coden   # is your key really there?
systemctl status dhcpcd                # running?
ip link                                # is there an en* device, and what's its MAC?
ip addr                                # what address did it get?
```

> **There is no `~/.ssh` directory, and that's correct.** NixOS installs
> declarative keys to `/etc/ssh/authorized_keys.d/<user>`, and sshd is told to
> read both locations. Don't go hunting for `~/.ssh/authorized_keys` — it will
> never exist, and its absence means nothing is wrong.

The `ip link` MAC is worth writing down if you plan to pin the address later.

### If you're moving the machine to a different place to plug it in

You can prove SSH works before you lose the monitor, with no router involved.
Plug the server's ethernet **straight into your laptop's ethernet port** — modern
cards auto-negotiate, no crossover cable needed. Both ends get IPv6 link-local
addresses automatically, with no DHCP server:

```bash
# [laptop]
ping6 -c3 ff02::1%enp3s0          # your laptop's wired device
ssh coden@fe80::XXXX:XXXX:XXXX:XXXX%enp3s0
```

That exercises the whole chain — driver, dhcpcd, sshd, your key — while you can
still fix things on screen.

Now you can unplug the monitor and keyboard for good.

---

## Step 7 — Log in from your laptop [laptop]

You shouldn't need to know its IP address. Try these in order:

```bash
ssh coden@media.local     # mDNS - works on Linux and macOS
ssh coden@media.lan       # your router's DNS
ssh coden@media           # same thing, via the "search lan" suffix
```

Any of them should let you in with your key, no password.

### How the names work

The server announces itself two independent ways, and neither needs a static
address:

| Name | How it resolves | Works on |
|---|---|---|
| `media.local` | mDNS — the server broadcasts it directly (avahi) | Linux, macOS, iOS. Android is unreliable. |
| `media.lan` / `media` | Your router's DNS — it registers DHCP hostnames | Anything using the router for DNS, Android included |

`media.lan` works because the server tells the router its hostname when asking
for an address, and OpenWrt's dnsmasq publishes DHCP leases under the `lan`
domain automatically.

**So you don't need a static lease just to get a name.** A reserved address is
only worth doing if you want the IP itself to never change — useful for the
projector, where some Android TV devices ignore the router's DNS and need a
literal address. To set one: note the MAC from `ip link`, then in OpenWrt go to
*Network → DHCP and DNS → Static Leases* and bind it to `192.168.1.50`.

---

## Step 8 — Set the two passwords [server, over SSH]

These live **outside** the repo, because the repo is public.

```bash
# Jellyfin admin account
sudo mkdir -p /var/lib/secrets
sudo sh -c 'echo "pick-a-password" > /var/lib/secrets/jellyfin-admin-password'
sudo chmod 600 /var/lib/secrets/jellyfin-admin-password

# Network share, for copying films in
sudo smbpasswd -a coden
```

Then let Jellyfin configure itself:

```bash
sudo systemctl restart jellyfin-provision
sudo systemctl status jellyfin-provision     # should end with "Done."
```

That creates your admin account, the Movies library, and turns on hardware
video support — no setup wizard to click through.

---

## Step 9 — (Optional) Pin the IP address

**You probably don't need this.** `media.local` and `media.lan` already work on
DHCP (Step 7). Pin the address only if you hit a device that can't resolve
either — some Android TV boxes ignore both mDNS and the router's DNS and want a
literal IP.

**Easier — reserve it on your router.** In OpenWrt: *Network → DHCP and DNS →
Static Leases*, bind the server's MAC to `192.168.1.50`. Nothing to change in
this repo, and the names keep working too.

**Or in the config** — needs the interface name from Step 4:

```nix
useDHCP = false;
staticIp = "192.168.1.50";
gateway = "192.168.1.1";
interface = "enp3s0";      # ← the real name, from `ip link`
```

Push, then rebuild (see [Everyday use](#everyday-use)).

> If you set `useDHCP = false` but leave `interface` empty, the static address
> cannot be applied. The config detects this, warns you at build time, and
> falls back to DHCP so the machine stays reachable.

---

## Step 10 — Copy some films in [laptop]

Connect to the share from your file manager:

- **Linux / macOS:** `smb://media.local/media`
- **Windows:** `\\media.local\media`

Log in with your username and the `smbpasswd` password from Step 8. Drop
`.mkv` files into the **movies** folder.

From a phone or browser instead: `http://media.local:8080`

Within 15 minutes the server automatically extracts subtitles from the files,
downloads missing Norwegian / German / English ones, and adds the films to
your library. To not wait:

```bash
ssh coden@media.local 'sudo systemctl start subtitle-extract'
```

---

## Step 11 — The one manual browser setting ⚠️

**This is what makes subtitle translation work. Don't skip it.**

1. Open `http://media.local:8096` and sign in.
2. **User icon** (top right) → **Settings** → **Subtitles**.
3. Set **Subtitle styling** to **Custom**.
4. Save.

### Why

On the default setting, Chrome draws subtitles somewhere browser extensions
cannot reach. They look completely normal on screen — your translation
extension simply sees nothing, with no error.

**This is stored in your browser, not on the server.** Repeat it on every
computer and browser profile you watch from, and again if you clear your
browsing data.

> If hover-translation ever stops working, check this first.

---

## Step 12 — Watching

**On your computer, with translation:**
`http://media.local:8096`, play a film, hover over subtitle words.

**On the projector:**
Install the **Jellyfin** app from the Play Store on the projector and point it
at `media.lan` — or its IP, if the projector ignores your router's DNS. Better
than casting: it plays more files directly, without the server having to
convert anything.

Casting from the Jellyfin phone app also works.

> When casting, the projector draws its own subtitles, so the translation
> extension can't reach them. That's expected — translation is for watching at
> your computer.

---

## Everyday use

### Change a setting

```bash
# [laptop]
git add -A && git commit -m "what changed" && git push

# [server]
ssh coden@media.local \
  'sudo nixos-rebuild switch --flake github:YOURNAME/subblix#media --refresh'
```

The server also does this itself nightly at 04:30.

### Undo a bad update

```bash
ssh coden@media.local 'sudo nixos-rebuild switch --rollback'
```

If it won't boot at all: attach a monitor and pick an older entry at the boot
menu. Nothing is ever destroyed — each update is a new entry.

### Check on things

```bash
systemctl status jellyfin              # is the media server up?
systemctl list-timers                  # when do the subtitle jobs next run?
journalctl -u subtitle-extract -n 50   # what did subtitle extraction do?
df -h /                                # how full is the disk?
```

---

## When things break

### Subtitle translation stopped working

1. **Check Step 11** — subtitle styling must be `Custom`. Almost always this.
2. **Force the browser to reload the player: `Ctrl+Shift+R`.** Jellyfin caches
   its own code in a service worker, so after a server update your browser can
   keep running the old version for a long time. This genuinely happens and
   looks exactly like "the patch didn't work".
3. **Try the other subtitle track.** Tracks that came as `.ass` are drawn as a
   picture and can't be read; pick the plain one the server extracted.

### You see the same language listed twice

Expected. One is built into the film, the other is the plain-text copy the
server extracted. Either plays; prefer the extracted one.

### Films play but have no subtitles

```bash
journalctl -u subtitle-extract -u subtitle-fetch -n 100
```

### `media.local` doesn't resolve

Try `media.lan`, then `media`, then the IP from your router's lease list. The
two name systems are independent, so one failing doesn't mean the server is
down:

- `media.local` needs mDNS on **your** machine. On Linux check that
  `/etc/nsswitch.conf` has `mdns4_minimal` in its `hosts:` line and that
  `avahi-daemon` is running.
- `media.lan` needs your device to use the router for DNS. Phones with a
  "Private DNS" setting enabled will bypass it.

### Can't reach the server / it's not in the DHCP leases

Log in at a monitor as `root` (Step 5's password) and check:

```bash
ip addr          # does it have an address at all?
ip link          # is the network card UP?
systemctl status dhcpcd
```

If `interface` was set to a name that doesn't exist, the static address silently
fails to apply. Fix it in `settings.nix`, or set `useDHCP = true`, push, and
rebuild.

### Locked out of a headless machine

If it has no network address *and* you have no console password, you cannot get
in remotely — there's nothing listening. Recover from the USB installer. This
replaces the system but **leaves your data alone**:

```bash
# [laptop] fix settings.nix (set useDHCP = true if unsure), commit, push

# [server] boot the USB installer
lsblk
sudo mount /dev/sda3 /mnt          # the big root partition
sudo mount /dev/sda1 /mnt/boot     # the small 1G EFI one
sudo nixos-install --flake github:YOURNAME/subblix#media --root /mnt
# set a root password when prompted
reboot
```

Don't use `install.sh` here — it repartitions, which would wipe your films.

This is why Steps 5 and 6 insist on setting passwords.

### The install fails part-way through building

Usually memory pressure while building Jellyfin's web interface. Re-run the
`nixos-install` command — it resumes rather than starting over.

---

## Where everything is

| What | Where |
|---|---|
| Jellyfin (watch films) | `http://media.local:8096` |
| File Browser (upload) | `http://media.local:8080` |
| Network share | `smb://media.local/media` |
| Films on disk | `/srv/media/movies` |
| Your passwords | `/var/lib/secrets/` (never in git) |

If a name doesn't resolve from some device, try `media.lan` instead, or fall
back to the IP from your router's lease list. Android in particular often
ignores `.local`.
