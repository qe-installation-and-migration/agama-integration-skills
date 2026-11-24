#!/usr/bin/env bash
# Remaster the latest SLES TEST ISO (fetched by download.sh): live password, grub timeout, register URL, boot params. Output dir: ./isos (cwd).
# With --source agama-devel only grub.cfg is patched: the grub timeout and the live password (kernel parameter).
set -euo pipefail
usage="usage: remaster.sh --source agama-devel [16.1|16.2] [--password <pw>] [--grub-timeout <sec>]   (newest Head build if no version, see SKILL.md)
       remaster.sh [--product SLES|SLES-NVIDIA] <16.0|16.1|16.2> <Online|Full> [--password <pw>] [--grub-timeout <sec>] [--register-url <url>] [boot-param ...]"
here="$(dirname "$(readlink -f "$0")")"
dir="$PWD/isos"
if [ "${1:-}" = --source ]; then
  # Agama Head live ISO: downloaded, checked against its .sha512 and patched only in grub.cfg: the menu timeout and the
  # live password as a kernel parameter. Tagging the ISO (tagmedia --add-tag live_password=..., what boot-vm.sh does) is
  # gone from the Head builds (confirmed with the developers; Build 23.2 refuses the ssh login): only live.password on
  # the kernel line works. Version optional: without it the newest Head one.
  [ "${2:-}" = agama-devel ] || { echo "$usage" >&2; exit 1; }
  shift 2
  ver=""; timeout=3; pw=nots3cr3t
  [[ "${1:-}" =~ ^16\.[0-9]+$ ]] && { ver="$1"; shift; }
  while [ $# -gt 0 ]; do
    case "$1" in
      --password) pw="${2:-}"; shift 2 || { echo "$usage" >&2; exit 1; } ;;
      --grub-timeout) timeout="${2:-}"; shift 2 || { echo "$usage" >&2; exit 1; } ;;
      *) echo "$usage" >&2; exit 1 ;;
    esac
  done
  # the password goes inside double quotes in grub.cfg: no quote, backslash, $ or whitespace
  case "$pw" in ""|*[!A-Za-z0-9_.,:@%+=-]*) echo "--password may only contain letters, digits and _.,:@%+=-" >&2; exit 1 ;; esac
  case "$timeout" in ""|*[!0-9]*|0) echo "--grub-timeout must be an integer >= 1 (0 stalls the menu)" >&2; exit 1 ;; esac
  command -v xorriso >/dev/null || { echo "xorriso not found" >&2; exit 1; }
  src="$("$here/download.sh" --source agama-devel $ver | tail -n1)"
  name="$(basename "$src")"
  ver="$(sed -E 's/.*SUSE_SLE_([0-9.]+[0-9])-Build.*/\1/' <<<"$name")"
  build="$(sed -E 's/.*-Build([0-9.]+)\.iso/\1/' <<<"$name")"
  out="${src%.iso}-modified.iso"
  rm -f "$out"
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  # Patch grub.cfg in place with xorriso and replay the boot setup. Not mkmedia: it rebuilds the image with the volume
  # id ISOIMAGE, and the live system then never finds its medium (Install-SUSE-SLE-<ver>-x86_64).
  xorriso -osirrox on -indev "$src" -extract /boot/grub2/grub.cfg "$tmp/grub.cfg" >/dev/null 2>&1
  chmod u+w "$tmp/grub.cfg"
  grep -q '^set timeout=' "$tmp/grub.cfg" || { echo "no 'set timeout=' in boot/grub2/grub.cfg of $name" >&2; exit 1; }
  sed -i -E "s/^set timeout=.*/set timeout=$timeout\nset live_options=\"live.password=$pw\"/" "$tmp/grub.cfg"
  xorriso -indev "$src" -outdev "$out" -boot_image any replay -map "$tmp/grub.cfg" /boot/grub2/grub.cfg -commit >/dev/null 2>&1 \
    || { rm -f "$out"; echo "could not patch the grub timeout of $name" >&2; exit 1; }
  cat > "$dir/last-prepared.json" <<J
{"iso":"$out","source_iso":"$src","version":"$ver","flavor":"","arch":"x86_64","product":"agama-devel","build":"$build","patched":true,"password":"$pw","grub_timeout":$timeout}
J
  echo "$out"
  exit 0
fi
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
latest="$(curl -fsS "https://download.suse.de/ibs/SUSE:/SLFO:/Products:/${product//-/_}:/?json" | grep -oE '"16\.[0-9]+:\\/"' | tr -d '"\\/:' | sort -V | tail -n1)"
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
# --tmp-dir: where mkmedia builds (override with TMPDIR); --no-sign: no GPG key needed for a VM test
mkmedia --create "$out" --boot "$params" --tmp-dir "${TMPDIR:-/tmp}" --no-sign "$tmp"

# JSON string escaping for the values that may contain a backslash or a quote
j() { local s=${1//\\/\\\\}; printf '%s' "${s//\"/\\\"}"; }
cat > "$dir/last-prepared.json" <<J
{"iso":"$(j "$out")","source_iso":"$(j "$src")","version":"$ver","flavor":"$flavor","arch":"$arch","product":"$product","build":"$build","password":"$(j "$pw")","grub_timeout":$timeout,"register_url":"$(j "$reg")","params":"$(j "$params")"}
J
echo "$out"
