#!/usr/bin/env bash
# Remaster the latest SLES TEST ISO (fetched by download.sh): live password, grub timeout, register URL, boot params. Output dir: ./isos (cwd).
set -euo pipefail
usage="usage: remaster.sh [--product SLES|SLES-NVIDIA] <16.0|16.1|16.2> <Online|Full> [--password <pw>] [--grub-timeout <sec>] [--register-url <url>] [boot-param ...]"
here="$(dirname "$(readlink -f "$0")")"
dir="$PWD/isos"
product=SLES
[ "${1:-}" = --product ] && { product="${2:?}"; shift 2; }
[ $# -ge 2 ] || { echo "$usage" >&2; exit 1; }
ver="$1"; flavor="$2"; shift 2

pw=nots3cr3t; timeout=3; reg=""; extra=()
while [ $# -gt 0 ]; do
  case "$1" in
    --password) pw="${2:?}"; shift 2 ;;
    --grub-timeout) timeout="${2:?}"; shift 2 ;;
    --register-url) reg="${2:?}"; shift 2 ;;
    *) extra+=("$1"); shift ;;
  esac
done
case "$timeout" in ""|*[!0-9]*|0) echo "--grub-timeout must be an integer >= 1 (0 stalls the menu)" >&2; exit 1 ;; esac
for t in mkmedia xorriso; do command -v $t >/dev/null || { echo "$t not found" >&2; exit 1; }; done

src="$("$here/download.sh" --product "$product" "$ver" "$flavor")"
name="$(basename "$src")"
build="$(sed -E 's/.*-Build([0-9.]+)\.install\.iso/\1/' <<<"$name")"
arch="$(sed -E "s/^$product-$ver-$flavor-([^-]+)-Build.*/\1/" <<<"$name")"
# default register proxy only exists for the newest version (detected)
latest="$(curl -fsSk "https://download.suse.de/ibs/SUSE:/SLFO:/Products:/${product//-/_}:/?json" | grep -oE '"16\.[0-9]+:\\/"' | tr -d '"\\/:' | sort -V | tail -n1)"
[ -z "$reg" ] && [ "$ver" = "$latest" ] && reg="http://all-$build.proxy.scc.suse.de"

params="live.password=$pw"
[ -n "$reg" ] && params="$params inst.register_url=$reg"
params="$params ${extra[*]:-}"

out="${src%.iso}-modified.iso"
rm -f "$out"
tmp="$(mktemp -d)"
trap 'chmod -R u+w "$tmp"; rm -rf "$tmp"' EXIT
xorriso -indev "$src" -osirrox on -extract / "$tmp" >/dev/null
chmod -R u+w "$tmp"
sed -i -E "s/^set timeout=.*/set timeout=$timeout/" "$tmp/boot/grub2/grub.cfg"
# --tmp-dir: /tmp is blocked in the sandbox; --no-sign: no GPG key needed for a VM test
mkmedia --create "$out" --boot "$params" --tmp-dir "${TMPDIR:-/tmp}" --no-sign "$tmp"

cat > "$dir/last-prepared.json" <<J
{"iso":"$out","source_iso":"$src","version":"$ver","flavor":"$flavor","arch":"$arch","product":"$product","build":"$build","password":"$pw","grub_timeout":$timeout,"register_url":"$reg","params":"$params"}
J
echo "$out"
