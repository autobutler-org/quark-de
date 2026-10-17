# Security Policy

Quark DE is the desktop session on devices that hold people's photos, documents, and passwords. We take reports seriously.

## Supported Versions

Only the latest release is supported. Devices auto-update from the release feed, and fixes ship in the next tag rather
than as backports — there are no maintained release branches.

Check which quark-de commit or release you installed. The current release is listed on the
[releases page](https://github.com/autobutler-org/quark-de/releases).

## Reporting a Vulnerability

**Do not open a public issue.** File a private security advisory:

<https://github.com/autobutler-org/quark-de/security/advisories/new>

Please include:

- What you found, and which component it affects
- Steps to reproduce
- The version you tested
- What an attacker could actually do with it, and what access they'd need first

We'll acknowledge the report, tell you whether we consider it a vulnerability, and let you know when a fix is out. If
you'd like credit in the advisory, say so and tell us how you want to be named.

Please give us a chance to ship a fix before publishing. Devices auto-update, but not instantly.

## In scope

- Authentication and session handling — login, setup, recovery phrases, token lifetime
- Vault cryptography and anything that could expose stored credentials
- Path traversal or unauthorized file access through the API
- Anything reachable from outside the home network, including remote access and the update mechanism
- Privilege escalation on the device, especially around USB mounting
- The release pipeline, the OS images, and dependency supply chain
- Anything that sends user data off the device

That last one matters most. Quark's entire premise is that your data stays in your house. If you find something that
contradicts that — a request to a third party, telemetry, a file leaving the device — report it as a vulnerability even
if nothing is technically "exploitable."

## Trust boundary: the sway IPC socket

sway listens on an IPC socket (`$SWAYSOCK`, also exported as `$I3SOCK`) in `$XDG_RUNTIME_DIR`. Any process running
as the desktop user can connect to it and send any command: `exec` a program, `exit` the session, rebind keys,
reconfigure inputs and outputs. sway has no per-client IPC policy; the i3-style `ipc` and `security` blocks were
removed in sway 1.0, so there is nothing in the config to restrict it.

**Same UID means full session control.** The socket's owner and the `0700` runtime directory keep other users out,
and that is the only boundary. A compromised process running as the desktop user (a browser exploit, a malicious
Quark plugin, a dependency of Quark) can drive the whole session.

What Quark DE does about it:

- The browser starts without `SWAYSOCK` and `I3SOCK` in its environment, both at login and when Super+2 relaunches
  it, so the browser and the processes it spawns are not handed the socket path. This is defense in depth, not a
  boundary: a process running as the same user can still find the socket in `$XDG_RUNTIME_DIR`. A sandboxed browser
  (Flatpak, snap) cannot.
- `bindsym --locked` is used only for media and brightness keys. Locking is `swaylock`, which uses the
  ext-session-lock protocol: an IPC client cannot dismiss it, and no key binding that acts on the session may be
  `--locked`.

Rules for a future Quark IPC bridge (the roadmap item where Quark switches workspaces itself):

- Send only a fixed allowlist of commands, such as `workspace 1:quark`, `workspace 2:browser` and
  `workspace 3:terminal`, chosen from a table, never built from strings.
- No string interpolation: no text from a user, a file, the network or a plugin ever reaches a sway IPC command.
- Prefer a small broker that holds the socket and exposes only that allowlist, so Quark itself never gets raw
  `SWAYSOCK`. Other apps still have the raw socket, so treat the broker as defense in depth too.

Not done here, and tracked as follow-ups: the broker and its allowlist, and running network-facing services (such
as the Quark backend) under a separate UID from the desktop user. Until those exist, an RCE in anything running as
the desktop user is full control of the session.

## Out of scope

- Attacks requiring physical access to an unlocked device. The threat model assumes the box is in your home; if someone
  is standing over it, they have already won.
- The wide-open state before first-boot setup completes. This is documented and intentional — see
  [docs/auth.md](docs/auth.md).
- Scanner output with no demonstrated impact
- Missing hardening headers or best-practice deviations with no path to exploitation
- Denial of service against your own device by your own request

If you're unsure whether something is in scope, file the advisory anyway and let us decide.

## Non-critical concerns

Hardening ideas, defense-in-depth improvements, and non-exploitable concerns can go in the public tracker using the
[security issue template](https://github.com/autobutler-org/quark-de/issues/new?template=security.yaml).
