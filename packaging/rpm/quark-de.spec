Name:           quark-de
Version:        0.1.0
Release:        1%{?dist}
Summary:        Wayland desktop session where the Quark app is the desktop
License:        MIT-0
URL:            https://github.com/autobutler-org/quark-de
Source0:        %{url}/archive/v%{version}/%{name}-%{version}.tar.gz
BuildArch:      noarch

BuildRequires:  make

Requires:       sway
Requires:       foot
Requires:       firefox
Requires:       swayidle
Requires:       swaylock
Requires:       jq
Requires:       xdg-desktop-portal
Requires:       xdg-desktop-portal-wlr
Requires:       xdg-desktop-portal-gtk
Requires:       mako
Requires:       wireplumber
Requires:       brightnessctl
Requires:       playerctl
Requires:       libnotify
Requires:       wl-clipboard
Requires:       cliphist
Requires:       wofi
Requires:       grim
Requires:       slurp
Requires:       dex-autostart
Requires:       lxpolkit
# Weak dependency: without socat, quark-de-ctl gives Quark no sway IPC.
Recommends:     socat
# The Quark Flutter app is not packaged yet: install it from
# https://github.com/autobutler-org/quark/releases and put `quark` on PATH.
# Without it the session starts a fallback desktop that says so.

%description
Quark DE is a Wayland desktop session, a sway config plus a POSIX sh launcher,
where the Quark Flutter app is the desktop. A browser and a terminal live on
side workspaces. Pick "Quark" at the display manager login screen.

%prep
%autosetup

%build
# nothing to build: shell scripts and config files

%install
%make_install PREFIX=%{_prefix} WAYLAND_SESSIONS=%{_datadir}/wayland-sessions

%files
%license LICENSE
%doc README.md
%{_bindir}/quark-de
%{_bindir}/quark-de-*
%{_datadir}/quark-de/
%{_datadir}/xdg-desktop-portal/quark-portals.conf
%{_datadir}/wayland-sessions/quark-de.desktop

%changelog
* Sat Oct 17 2026 Brandon Apol <apolbrandon@gmail.com> - 0.1.0-1
- Initial package
