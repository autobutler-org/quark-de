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

## Keybinds

`Super` is the Windows/Command key.

| Keys            | Does                     |
| --------------- | ------------------------ |
| `Super+1`       | Quark                    |
| `Super+2`       | browser                  |
| `Super+3`       | terminal                 |
| `Super+Tab`     | back to Quark            |
| `Super+Shift+E` | log out                  |

## Install

Dependencies: `sway`, `foot`, `firefox`, and the Quark Linux app (`quark` on `PATH`, from the
[Quark releases](https://github.com/autobutler-org/quark/releases)).

```bash
sudo apt install sway foot firefox
sudo make install          # PREFIX=/usr/local by default; DESTDIR is honored
quark-de --check           # lists anything still missing and how to get it
```

Log out, pick **Quark** at the login screen. `sudo make uninstall` removes it.

Using a different browser? Change the `exec firefox` line and its `assign [app_id="firefox"]` rule in
`config/sway/config` to match (`swaymsg -t get_tree | grep app_id` shows the app ID).

## Roadmap

- Quark drives the workspaces itself (a "Browser" / "Terminal" button calling `swaymsg workspace …`), so the
  keybinds become a fallback instead of the only way to switch.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). `make check` lints the launcher.

## License

[MIT-0](LICENSE)
