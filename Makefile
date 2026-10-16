PREFIX ?= /usr/local
WAYLAND_SESSIONS ?= /usr/share/wayland-sessions

.PHONY: help install uninstall check

help:
	@echo "make install    install the session (PREFIX=$(PREFIX), DESTDIR supported)"
	@echo "make uninstall  remove it"
	@echo "make check      lint the launcher with shellcheck"

install:
	install -d $(DESTDIR)$(PREFIX)/bin $(DESTDIR)$(PREFIX)/share/quark-de/sway $(DESTDIR)$(WAYLAND_SESSIONS)
	install -m755 session/quark-de $(DESTDIR)$(PREFIX)/bin/quark-de
	install -m644 config/sway/config $(DESTDIR)$(PREFIX)/share/quark-de/sway/config
	sed 's|^Exec=.*|Exec=$(PREFIX)/bin/quark-de|' session/quark-de.desktop > $(DESTDIR)$(WAYLAND_SESSIONS)/quark-de.desktop

uninstall:
	rm -f $(DESTDIR)$(PREFIX)/bin/quark-de $(DESTDIR)$(WAYLAND_SESSIONS)/quark-de.desktop
	rm -rf $(DESTDIR)$(PREFIX)/share/quark-de

check:
	@command -v shellcheck >/dev/null || { echo "shellcheck not found: sudo apt install shellcheck (or brew install shellcheck)"; exit 1; }
	shellcheck session/quark-de
