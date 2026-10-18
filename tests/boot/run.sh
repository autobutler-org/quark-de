#!/bin/sh
# Usage: run.sh <quark AppImage> <out dir>
# Boot a Debian cloud image in QEMU/KVM, install quark-de and the real Quark app in it, reboot into
# the greetd autologin, wait up to 180 s for the session, then collect tree.json, shot.png, shot.ppm,
# journal.txt, session-logs.txt and serial.log into <out dir> and judge them with assert.sh.
# Needs qemu-system-x86_64, qemu-img, genisoimage (or mkisofs), ssh, curl and a usable /dev/kvm.
# Downloads are cached in $BOOT_CACHE (default: <out dir>/cache).
set -eu

readonly appimage="${1:?usage: run.sh <quark AppImage> <out dir>}"
readonly out="${2:?usage: run.sh <quark AppImage> <out dir>}"
here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
readonly here repo
readonly cache="${BOOT_CACHE:-$out/cache}"
readonly work="$out/work"
readonly port="${BOOT_SSH_PORT:-10022}"
readonly session_timeout=180
readonly images=https://cloud.debian.org/images/cloud/trixie/latest
# generic, not genericcloud: the cloud kernel has no DRM drivers, so virtio-vga would show no display.
readonly image=debian-13-generic-amd64.qcow2

log() {
	echo "boot: $*" >&2
}

die() {
	log "error: $*"
	exit 1
}

for cmd in qemu-system-x86_64 qemu-img ssh ssh-keygen curl sha512sum; do
	command -v "$cmd" >/dev/null 2>&1 || die "$cmd not found: sudo apt install qemu-system-x86 qemu-utils openssh-client curl"
done
if command -v genisoimage >/dev/null 2>&1; then
	mkiso=genisoimage
elif command -v mkisofs >/dev/null 2>&1; then
	mkiso=mkisofs
else
	die "genisoimage not found: sudo apt install genisoimage"
fi
[ -r /dev/kvm ] && [ -w /dev/kvm ] || die "/dev/kvm is not usable by $(id -un); add yourself to the kvm group (or run the udev step from nightly-boot.yml)"
[ -r "$appimage" ] || die "$appimage not found; fetch it with tests/boot/fetch-quark.sh"

mkdir -p "$out" "$cache" "$work"
rm -f "$out/tree.json" "$out/shot.png" "$out/shot.ppm" "$out/journal.txt" "$out/session-logs.txt" "$out/serial.log"

# The base image, checked against Debian's SHA512SUMS; reused from the cache when it still matches.
curl -fsSLo "$cache/SHA512SUMS" "$images/SHA512SUMS"
if ! (cd "$cache" && grep " $image\$" SHA512SUMS | sha512sum -c --status - 2>/dev/null); then
	log "downloading $images/$image"
	curl -fsSLo "$cache/$image" "$images/$image"
	(cd "$cache" && grep " $image\$" SHA512SUMS | sha512sum -c -) >&2 || die "$image does not match Debian's SHA512SUMS; delete $cache and try again"
fi

rm -f "$work/disk.qcow2" "$work/key" "$work/key.pub"
qemu-img create -q -f qcow2 -b "$cache/$image" -F qcow2 "$work/disk.qcow2" 12G
ssh-keygen -q -t ed25519 -N '' -f "$work/key"
cat >"$work/user-data" <<EOF
#cloud-config
ssh_authorized_keys:
  - $(cat "$work/key.pub")
EOF
printf 'instance-id: quark-de-boot\nlocal-hostname: quark-de-boot\n' >"$work/meta-data"
"$mkiso" -quiet -output "$work/seed.iso" -volid cidata -joliet -rock "$work/user-data" "$work/meta-data"

qemu-system-x86_64 -enable-kvm -cpu host -m 4096 -smp 2 \
	-device virtio-vga -display none \
	-drive file="$work/disk.qcow2",if=virtio \
	-drive file="$work/seed.iso",if=virtio,format=raw,readonly=on \
	-nic user,model=virtio-net-pci,hostfwd=tcp:127.0.0.1:"$port"-:22 \
	-serial file:"$out/serial.log" &
qemu_pid=$!
trap 'kill "$qemu_pid" 2>/dev/null || :' EXIT

vssh() {
	ssh -i "$work/key" -p "$port" -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no \
		-o UserKnownHostsFile=/dev/null -o LogLevel=ERROR debian@127.0.0.1 "$@"
}

# until_deadline <epoch> <command>...: retry the command every 2 s until it succeeds or the deadline passes.
until_deadline() {
	deadline="$1"
	shift
	until "$@" >/dev/null 2>&1; do
		kill -0 "$qemu_pid" 2>/dev/null || die "QEMU exited; see $out/serial.log"
		[ "$(date +%s)" -ge "$deadline" ] && return 1
		sleep 2
	done
}

log "first boot: waiting for SSH"
until_deadline $(($(date +%s) + 300)) vssh true || die "the guest did not answer SSH within 300 s; see $out/serial.log"

log "provisioning (log: $out/provision.log)"
tar -C "$repo" --exclude=.git -cf - . | vssh 'rm -rf quark-de && mkdir quark-de && tar -xf - -C quark-de'
vssh 'cat >quark.AppImage' <"$appimage"
vssh 'sudo sh quark-de/tests/boot/provision.sh ~/quark-de ~/quark.AppImage' >"$out/provision.log" 2>&1 ||
	die "provisioning failed; see the end of $out/provision.log"

first_boot="$(vssh cat /proc/sys/kernel/random/boot_id)"
vssh 'sudo systemctl reboot' || :
start=$(date +%s)
log "rebooted; waiting up to $session_timeout s for Quark"

rebooted() {
	boot="$(vssh cat /proc/sys/kernel/random/boot_id)" && [ "$boot" != "$first_boot" ]
}

session_up() {
	rebooted && vssh 'sudo -u quark sh -s ready' <"$here/probe.sh"
}

if until_deadline $((start + session_timeout)) session_up; then
	log "Quark mapped after $(($(date +%s) - start)) s; letting it draw"
	sleep 10
elif rebooted; then
	log "no Quark window within $session_timeout s; collecting what is there"
else
	log "the guest did not come back within $session_timeout s"
fi

if rebooted; then
	vssh 'rm -rf /tmp/probe' || :
	if vssh 'sudo -u quark sh -s collect /tmp/probe' <"$here/probe.sh"; then
		for f in tree.json shot.png shot.ppm; do
			vssh "cat /tmp/probe/$f" >"$out/$f" || rm -f "$out/$f"
		done
	fi
	vssh 'sudo journalctl -b --no-pager' >"$out/journal.txt" || :
	vssh 'sudo sh -c "tail -n +1 /home/quark/.local/state/quark-de/*.log"' >"$out/session-logs.txt" 2>&1 || :
	vssh 'sudo systemctl poweroff' || :
fi
kill "$qemu_pid" 2>/dev/null || :
wait "$qemu_pid" 2>/dev/null || :

sh "$here/assert.sh" "$out" || {
	log "last lines of the session logs (all of them: $out/session-logs.txt):"
	tail -n 20 "$out/session-logs.txt" >&2 || :
	exit 1
}
