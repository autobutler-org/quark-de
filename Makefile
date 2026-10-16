PREFIX ?= /usr/local
WAYLAND_SESSIONS ?= /usr/share/wayland-sessions

.PHONY: help install uninstall check test

HELPERS = $(wildcard session/quark-de-*)
SHELL_FILES = session/quark-de $(HELPERS) $(wildcard tests/*.sh tests/*/*.sh)

help:
	@echo "make install    install the session (PREFIX=$(PREFIX), DESTDIR supported)"
	@echo "make uninstall  remove it"
	@echo "make check      lint (shellcheck, shfmt, desktop-file-validate, actionlint) and run the unit tests"
	@echo "make test       run the headless sway tests (needs sway, foot, jq, wl-clipboard, cliphist, mako, libnotify-bin)"

install:
	install -d $(DESTDIR)$(PREFIX)/bin $(DESTDIR)$(PREFIX)/share/quark-de/sway $(DESTDIR)$(PREFIX)/share/quark-de/mako $(DESTDIR)$(PREFIX)/share/xdg-desktop-portal $(DESTDIR)$(WAYLAND_SESSIONS)
	install -m755 session/quark-de $(DESTDIR)$(PREFIX)/bin/quark-de
	install -m755 $(HELPERS) $(DESTDIR)$(PREFIX)/bin/
	sed 's|^set $$share .*|set $$share $(PREFIX)/share/quark-de|' config/sway/config > $(DESTDIR)$(PREFIX)/share/quark-de/sway/config
	install -m644 config/mako/config $(DESTDIR)$(PREFIX)/share/quark-de/mako/config
	install -m644 config/sway/fallback $(DESTDIR)$(PREFIX)/share/quark-de/sway/fallback
	install -m644 config/xdg-desktop-portal/quark-portals.conf $(DESTDIR)$(PREFIX)/share/xdg-desktop-portal/quark-portals.conf
	sed 's|^Exec=.*|Exec=$(PREFIX)/bin/quark-de|' session/quark-de.desktop > $(DESTDIR)$(WAYLAND_SESSIONS)/quark-de.desktop

uninstall:
	rm -f $(DESTDIR)$(PREFIX)/bin/quark-de $(addprefix $(DESTDIR)$(PREFIX)/bin/,$(notdir $(HELPERS))) $(DESTDIR)$(WAYLAND_SESSIONS)/quark-de.desktop $(DESTDIR)$(PREFIX)/share/xdg-desktop-portal/quark-portals.conf
	rm -rf $(DESTDIR)$(PREFIX)/share/quark-de

check:
	@missing=0; for cmd in shellcheck shfmt desktop-file-validate actionlint; do \
		command -v $$cmd >/dev/null && continue; \
		case $$cmd in \
		shellcheck | shfmt) hint="sudo apt install $$cmd (or brew install $$cmd)" ;; \
		desktop-file-validate) hint="sudo apt install desktop-file-utils (or brew install desktop-file-utils)" ;; \
		actionlint) hint="go install github.com/rhysd/actionlint/cmd/actionlint@latest (or brew install actionlint)" ;; \
		esac; \
		echo "$$cmd not found: $$hint"; missing=1; \
	done; exit $$missing
	shellcheck -x $(SHELL_FILES)
	shfmt -d $(SHELL_FILES)
	@tmp="$$(mktemp -d)" && grep -v '^DesktopNames=' session/quark-de.desktop >"$$tmp/quark-de.desktop" && \
		{ desktop-file-validate "$$tmp/quark-de.desktop"; status=$$?; rm -rf "$$tmp"; exit $$status; }
	actionlint
	sh tests/run.sh tests/unit

test:
	@for cmd in sway foot jq wl-copy cliphist mako notify-send dbus-daemon; do command -v $$cmd >/dev/null || { echo "$$cmd not found: sudo apt install sway foot jq wl-clipboard cliphist mako-notifier libnotify-bin dbus"; exit 1; }; done
	sh tests/run.sh tests/sway
