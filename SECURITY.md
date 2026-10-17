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

- Quark never gets the raw socket. `quark-de-ctl guard` hands it an allowlisting socket as `SWAYSOCK`
  (`$XDG_RUNTIME_DIR/quark-de-ctl.<pid>.sock`, mode 0600). Each request is matched against a fixed table
  (`quark-de-ctl -h`) and mapped to a fixed action; Quark's text never reaches sway, so `exec`, `exit`, `reload`
  and `;` or `,` chains are rejected. Other apps still have the raw socket, so treat the bridge as defense in
  depth too.

Rules for the bridge: add a command only as a new fixed entry in that table, and never build a sway command from
text a user, a file, the network or a plugin supplied.

Not done here, and tracked as a follow-up: running network-facing services (such as the Quark backend) under a
separate UID from the desktop user. Until that exists, an RCE in anything running as the desktop user is full
control of the session.

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
