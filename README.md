# Quark DE

A Linux desktop session where [Quark](https://github.com/autobutler-org/quark) is the desktop.

[![Check](https://github.com/autobutler-org/quark-de/actions/workflows/check.yml/badge.svg?branch=main)](https://github.com/autobutler-org/quark-de/actions/workflows/check.yml)
[![License: MIT-0](https://img.shields.io/badge/License-MIT--0-yellow.svg)](LICENSE)

---

## What is it?

Log in, and you land in Quark: full screen, no panels, no window chrome. Quark is the GUI for the machine. When
you need something Quark doesn't do, a browser and a terminal wait on side workspaces, one keystroke away.

Under the hood it's [sway](https://swaywm.org) with a short config and a launcher script. No custom compositor.

| Workspace    | Runs                                    |
| ------------ | --------------------------------------- |
| 1 `quark`    | Quark (restarted if it exits)           |
| 2 `browser`  | Firefox                                 |
| 3 `terminal` | foot                                    |

If Quark exits, it is restarted and workspace 1 gets focus back. If it exits 3 times within 30 seconds, the
restarts stop and a bar says "Quark keeps crashing." with buttons to open a terminal, view the log, retry, or log
out. Once sway is gone, Quark is not restarted. Quark's output is appended to
`${XDG_STATE_HOME:-~/.local/state}/quark-de/quark.log`.

## Keybinds

`Super` is the Windows/Command key.

| Keys            | Does                           |
| --------------- | ------------------------------ |
| `Super+1`       | Quark                          |
| `Super+2`       | browser (starts it if closed)  |
| `Super+3`       | terminal (starts it if closed) |
| `Super+Tab`     | back to Quark                  |
| `Super+/`       | show these keys                |
| `Super+F1`      | show these keys                |
| `Super+L`       | lock the screen                |
| `Super+V`       | clipboard history (last 20)    |
| `Super+N`       | dismiss a notification         |
| `Super+Shift+N` | bring back the last one        |
| `Super+D`       | toggle do-not-disturb          |
| `Print`         | screenshot, full screen        |
| `Shift+Print`   | screenshot, region             |
| `Super+Print`   | screenshot, window             |
| `Super+Shift+E` | log out                        |

Opening a link from Quark switches to the browser; `Super+Tab` takes you back.

Screenshots land in `~/Pictures/Screenshots` (your XDG Pictures folder, if you set one), named by date and time. Each
one is also copied to the clipboard, and a notification shows where it was saved. `Shift+Print` lets you drag out a
region; `Esc` cancels it.

On your first login a bar at the top of the screen lists these keys. It shows once: a marker in
`${XDG_STATE_HOME:-~/.local/state}/quark-de/` remembers that you have seen it.

The volume, mic mute, brightness and play/pause/next/previous keys work on every workspace, even while the screen is
locked. Volume and brightness changes show the new level as a notification, so a notification daemon (such as
`mako`) has to be running to see it. The power key is left to systemd-logind, which by default powers off.

## Lock and idle

After 5 minutes idle the screen locks (swaylock); after 10 it turns off and wakes on input. Suspend and lid
close lock before sleeping. A fullscreen browser or other app (a video, say) keeps the screen on; Quark itself
does not, because it is always fullscreen. `loginctl lock-session` locks too. Without `swayidle` or `swaylock` the
session still starts, just without locking.

To change the timeouts, put them in a file in `~/.config/quark-de/sway/` (`$XDG_CONFIG_HOME/quark-de/sway/` if set),
such as `~/.config/quark-de/sway/idle`, and log in again. Values are in seconds:

```text
set $lock_timeout 600
set $screen_off_timeout 900
```

While locked, only the volume, brightness and media keys work, and notifications stay hidden behind the lock.

Two things the lock does not cover:

- **Other consoles.** `Ctrl+Alt+F<n>` still switches to a text console. The lock keeps this session covered, but
  anyone already logged in on another console is not locked. Log out of consoles you are not using; on an appliance,
  mask the spare gettys (`sudo systemctl mask getty@tty3.service`, and so on), keeping one for the recovery below.
- **A crashed locker.** If swaylock dies, the session stays locked: the outputs stay covered (blank or solid red)
  and input does nothing. To unlock, switch to a text console with `Ctrl+Alt+F2`, log in as the same user, and
  start a new locker:

  ```bash
  WAYLAND_DISPLAY=wayland-1 swaylock -f   # ls $XDG_RUNTIME_DIR shows the wayland-N name
  ```

  Switch back with `Ctrl+Alt+F1` (or whichever console the session runs on) and unlock as usual.

## Keyboard layout and input methods

At login, `quark-de-keyboard` applies the system keyboard layout to every keyboard: `XKBLAYOUT`, `XKBVARIANT`,
`XKBOPTIONS` and `XKBMODEL` from `/etc/default/keyboard`, or the `X11 Layout`/`Variant`/`Options`/`Model` lines of
`localectl status` where that file does not exist. Set it with `sudo localectl set-x11-keymap de pc105 nodeadkeys`
(or `sudo dpkg-reconfigure keyboard-configuration` on Debian), then log in again. If nothing is configured, sway's
default (US) is left alone. A layout sway cannot compile is written to stderr with the fix, and the keyboard stays US.

The layout is set before swaylock first runs, so a lock-screen password with non-ASCII characters (`ä`, `é`) types
the same as at the login screen.

The session does not install an input method. For Chinese, Japanese, Korean and other composed input, install
[fcitx5](https://fcitx-im.org) (or ibus) and start it from sway, for example in a file under `/etc/sway/config.d/`:

```text
exec fcitx5 -d --replace
```

Quark and other Wayland apps get input through the `text-input-v3` protocol, which sway supports; GTK apps that do
not speak it need `GTK_IM_MODULE=fcitx` (or `ibus`) in their environment.

## Clipboard

Everything you copy is kept in a [cliphist](https://github.com/sentriz/cliphist) history. On Wayland the clipboard
empties when the app you copied from closes; the copy is still in the history. `Super+V` lists the last 20 items in
[wofi](https://hg.sr.ht/~scoopta/wofi); pick one and it is back on the clipboard, ready to paste.

Copies a password manager marks with `x-kde-passwordManagerHint` (KeePassXC does) are not stored.

- `cliphist wipe` clears the history.
- To turn history off, delete the `exec wl-paste --watch quark-de-clipboard store` line from the installed sway config
  (`$PREFIX/share/quark-de/sway/config`) and log in again.

## Notifications

[mako](https://github.com/emersion/mako) shows notifications in the top-right corner, over Quark and on every
workspace. Click one to dismiss it. Do-not-disturb hides them until you toggle it off. `Super+Shift+N` restores
from a history of the last 20. The config is `config/mako/config`.

## Startup apps

Apps in `~/.config/autostart/*.desktop` and `/etc/xdg/autostart/` start at login, honoring their `OnlyShowIn` /
`NotShowIn` keys against the session's `XDG_CURRENT_DESKTOP`. With a systemd user session, `quark-de-autostart`
starts `xdg-desktop-autostart.target`; without one it runs `dex -a`. If an app fails to start, you get a
notification saying which one and how to find out why.

## Admin password prompts

Mounting a USB disk, changing the network or installing updates asks for your password through
[polkit](https://github.com/polkit-org/polkit). sway ships no polkit agent, so `quark-de-polkit` starts the first one
it finds of `polkit-gnome-authentication-agent-1`, `lxpolkit` and `polkit-kde-authentication-agent-1`, looking in
`PATH` and the distro libexec directories they install to. Without one those actions fail with no prompt;
`quark-de --check` warns about it.

Quark asks for privileges through polkit and never shows a password prompt of its own. A password dialog drawn by an
app is indistinguishable from a phishing one; the polkit agent is the only thing in the session that should ever ask.

Which actions need no password (udisks2 rules, for example) is left to your distro's polkit policy; Quark DE installs
no rules.

## Install

Dependencies: `sway`, `foot`, `firefox` (or `firefox-esr`, Debian's default), `swayidle`, `swaylock`, `mako`
(notifications; the session starts without it), and the Quark Linux app (`quark` on `PATH`, from the
[Quark releases](https://github.com/autobutler-org/quark/releases)). File dialogs and screen sharing also need
`xdg-desktop-portal`, `xdg-desktop-portal-wlr` and `xdg-desktop-portal-gtk`; `quark-de --check` warns if they are
missing.

Optional, for the media and brightness keys: `wpctl` (from `wireplumber`), `brightnessctl`, `playerctl`, and
`notify-send` (from `libnotify-bin`) for the on-screen level. The session starts without them and warns about each
one that is missing.

Optional: `wl-clipboard` and `cliphist` for clipboard history, `wofi` for the `Super+V` picker.

Optional, for screenshots: `grim`, `slurp`, and `wl-copy` (from `wl-clipboard`).

Optional: `dex`, which starts your startup apps when there is no systemd user session.

Optional: a polkit agent (`lxpolkit`, `policykit-1-gnome` or `polkit-kde-agent-1`) for admin password prompts.

```bash
sudo apt install sway foot firefox swayidle swaylock mako-notifier xdg-desktop-portal xdg-desktop-portal-wlr xdg-desktop-portal-gtk
sudo apt install wireplumber brightnessctl playerctl libnotify-bin   # optional
sudo apt install wl-clipboard cliphist wofi   # optional: clipboard history
sudo apt install grim slurp wl-clipboard   # optional: screenshots
sudo apt install dex   # optional: startup apps without systemd
sudo apt install lxpolkit   # optional: admin password prompts
sudo make install          # PREFIX=/usr/local by default; DESTDIR is honored
quark-de --check           # lists anything still missing and how to get it
```

Log out, pick **Quark** at the login screen. `sudo make uninstall` removes it.

If the session can't start, it says why in `~/.local/state/quark-de/session.log` (`$XDG_STATE_HOME` if set) and in
the journal (`journalctl -t quark-de`). Without `sway` you land back at the login screen. Without `quark` you get a
fallback session instead: an error bar saying what to install, a Log out button, and a foot terminal. A missing
`foot` or `firefox` is logged as a warning and the session starts anyway. The session also refuses to start, and
says how to fix it, when `XDG_RUNTIME_DIR` is unset, missing, owned by someone else or not mode 0700 (started from
`su` or `sudo`, say).

`make install` writes the install prefix into the installed `quark-de`, so a symlink to it (in `~/.local/bin`, say)
still finds the config.

Reporting a crash or a black screen? Run `quark-de --report`. It writes a tarball next to those logs and prints its
path. It holds `session.log`, `quark.log`, the `--check` output, `swaymsg -t get_version`, `get_outputs` and
`get_tree` (when sway is running), `journalctl --user -b -t quark-de` and `coredumpctl list quark` (when those are
installed), with your home directory and obvious tokens and passwords scrubbed. Nothing is uploaded: look it over,
then attach it to your issue.

The session sets `XDG_CURRENT_DESKTOP=Quark:sway`, and `make install` puts `quark-portals.conf` in
`$PREFIX/share/xdg-desktop-portal/`: screen sharing and screenshots go to the wlr portal, everything else (file
pickers, settings) to the gtk one.

The browser starts without `SWAYSOCK` and `I3SOCK` (`quark-de-browser` unsets them), so it and the processes it
spawns are not handed sway's IPC socket; see [SECURITY.md](SECURITY.md#trust-boundary-the-sway-ipc-socket).

Using a different browser? Change the `exec quark-de-browser` line (it starts `firefox`, or `firefox-esr` when that
is the one installed), its `assign [app_id="^firefox(-esr)?$"]` rule and the `$mod+2` binding
(`quark-de-focus <workspace> <app_id> <command>`) in `config/sway/config` to match (`swaymsg -t get_tree | grep app_id` shows the app ID).

## Roadmap

- Quark drives the workspaces itself (a "Browser" / "Terminal" button calling `swaymsg workspace …`), so the
  keybinds become a fallback instead of the only way to switch.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). `make check` lints (needs `shellcheck`, `shfmt`, `desktop-file-validate` and
`actionlint`; it says how to get any that are missing) and runs the unit tests; `make test` runs the headless sway tests
(needs `sway`, `foot`, `jq`, `wl-clipboard`, `cliphist`, `mako-notifier`, `libnotify-bin` and `grim`).

## License

[MIT-0](LICENSE)
