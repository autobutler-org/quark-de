# Debian/Ubuntu package

`debian/` installs through the repo's `make install` (`PREFIX=/usr`), so the package and a manual install never
drift apart. The package is `quark-de` (architecture `all`); the version is the top `debian/changelog` entry.

Build from the repo root (dpkg-buildpackage wants `debian/` there):

    sudo apt install build-essential debhelper
    ln -s packaging/deb/debian debian
    dpkg-buildpackage -us -uc -b
    rm debian

The `.deb` lands in the parent directory. The Quark app is not packaged; `quark-de --check` tells users to
install it from the Quark releases.
