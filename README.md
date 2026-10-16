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
out. Quark's output is appended to `${XDG_STATE_HOME:-~/.local/state}/quark-de/quark.log`.

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
| `Super+Shift+E` | log out                        |

Opening a link from Quark switches to the browser; `Super+Tab` takes you back.

On your first login a bar at the top of the screen lists these keys. It shows once: a marker in
`${XDG_STATE_HOME:-~/.local/state}/quark-de/` remembers that you have seen it.

The volume, mic mute, brightness and play/pause/next/previous keys work on every workspace, even while the screen is
locked. Volume and brightness changes show the new level as a notification, so a notification daemon (such as
`mako`) has to be running to see it. The power key is left to systemd-logind, which by default powers off.

## Lock and idle

After 5 minutes idle the screen locks (swaylock); after 10 it turns off and wakes on input. Suspend and lid
close lock before sleeping. A fullscreen browser or other app (a video, say) keeps the screen on; Quark itself
does not, because it is always fullscreen. Without `swayidle` or `swaylock` the session still starts, just without
locking.

## Install

Dependencies: `sway`, `foot`, `firefox`, `swayidle`, `swaylock`, and the Quark Linux app (`quark` on `PATH`, from the
[Quark releases](https://github.com/autobutler-org/quark/releases)). File dialogs and screen sharing also need
`xdg-desktop-portal`, `xdg-desktop-portal-wlr` and `xdg-desktop-portal-gtk`; `quark-de --check` warns if they are
missing.

Optional, for the media and brightness keys: `wpctl` (from `wireplumber`), `brightnessctl`, `playerctl`, and
`notify-send` (from `libnotify-bin`) for the on-screen level. The session starts without them and warns about each
one that is missing.

```bash
sudo apt install sway foot firefox swayidle swaylock xdg-desktop-portal xdg-desktop-portal-wlr xdg-desktop-portal-gtk
sudo apt install wireplumber brightnessctl playerctl libnotify-bin   # optional
sudo make install          # PREFIX=/usr/local by default; DESTDIR is honored
quark-de --check           # lists anything still missing and how to get it
```

Log out, pick **Quark** at the login screen. `sudo make uninstall` removes it.

If the session can't start, it says why in `~/.local/state/quark-de/session.log` (`$XDG_STATE_HOME` if set) and in
the journal (`journalctl -t quark-de`). Without `sway` you land back at the login screen. Without `quark` you get a
fallback session instead: an error bar saying what to install, a Log out button, and a foot terminal. A missing
`foot` or `firefox` is logged as a warning and the session starts anyway.

The session sets `XDG_CURRENT_DESKTOP=Quark:sway`, and `make install` puts `quark-portals.conf` in
`$PREFIX/share/xdg-desktop-portal/`: screen sharing and screenshots go to the wlr portal, everything else (file
pickers, settings) to the gtk one.

Using a different browser? Change the `exec firefox` line, its `assign [app_id="firefox"]` rule and the `$mod+2`
binding (`quark-de-focus <workspace> <app_id> <command>`) in `config/sway/config` to match (`swaymsg -t get_tree | grep app_id` shows the app ID).

## Roadmap

- Quark drives the workspaces itself (a "Browser" / "Terminal" button calling `swaymsg workspace …`), so the
  keybinds become a fallback instead of the only way to switch.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). `make check` lints (needs `shellcheck`, `shfmt`, `desktop-file-validate` and
`actionlint`; it says how to get any that are missing) and runs the unit tests; `make test` runs the headless sway tests
(needs `sway`, `foot` and `jq`).

## License

[MIT-0](LICENSE)
