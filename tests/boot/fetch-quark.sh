#!/bin/sh
# Usage: fetch-quark.sh <dir> [tag]
# Download the Quark desktop app (the x86_64 AppImage) from autobutler-org/quark releases into <dir>,
# check it against the sha256 digest GitHub records for the asset, and print its path.
# Defaults to the latest release. Needs gh (with GH_TOKEN in CI) and jq.
set -eu

readonly dir="${1:?usage: fetch-quark.sh <dir> [tag]}"
readonly tag="${2:-latest}"
readonly repo=autobutler-org/quark

if [ "$tag" = latest ]; then
	endpoint="repos/$repo/releases/latest"
else
	endpoint="repos/$repo/releases/tags/$tag"
fi
release="$(gh api "$endpoint")" || {
	echo "fetch-quark: cannot read release '$tag' of $repo; check the tag exists and gh is logged in (GH_TOKEN)" >&2
	exit 1
}
asset="$(printf '%s' "$release" | jq -r '[.assets[] | select(.name | endswith("-x86_64.AppImage"))][0] // empty | "\(.name) \(.digest)"')"
[ -n "$asset" ] || {
	echo "fetch-quark: release '$tag' of $repo has no *-x86_64.AppImage asset; pass a tag that has one" >&2
	exit 1
}
name="${asset% *}"
digest="${asset#* }"
case "$digest" in
sha256:*) ;;
*)
	echo "fetch-quark: $name has no sha256 digest on GitHub, so it cannot be verified; pass a newer tag" >&2
	exit 1
	;;
esac

mkdir -p "$dir"
gh release download "$(printf '%s' "$release" | jq -r .tag_name)" --repo "$repo" --pattern "$name" --dir "$dir" --clobber >&2
echo "${digest#sha256:}  $dir/$name" | sha256sum -c - >&2 || {
	echo "fetch-quark: $name does not match its GitHub digest; delete $dir/$name and try again" >&2
	exit 1
}
echo "$dir/$name"
