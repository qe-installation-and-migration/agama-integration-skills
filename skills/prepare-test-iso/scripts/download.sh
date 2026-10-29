#!/usr/bin/env bash
# Download the latest SLES TEST ISO into ./isos (cwd), keeping the 2 newest builds per version. Prints the ISO path.
set -euo pipefail
usage="usage: download.sh [--product SLES|SLES-NVIDIA] <16.0|16.1|16.2> <Online|Full>"
product=SLES
[ "${1:-}" = --product ] && { product="${2:?}"; shift 2; }
case "$product" in SLES|SLES-NVIDIA) ;; *) echo "$usage" >&2; exit 1 ;; esac
[ $# -eq 2 ] || { echo "$usage" >&2; exit 1; }
ver="$1"; flavor="$2"
case "$ver" in 16.0|16.1|16.2) ;; *) echo "$usage" >&2; exit 1 ;; esac
case "$flavor" in Online|Full) ;; *) echo "$usage" >&2; exit 1 ;; esac
# SLES_NVIDIA TEST currently ships aarch64 only
arch=x86_64; [ "$product" = SLES-NVIDIA ] && arch=aarch64

base="https://download.suse.de/ibs/SUSE:/SLFO:/Products:/${product//-/_}:/$ver:/TEST/product/iso"
name="$(curl -fsSk "$base/?json" | grep -o "$product-$ver-$flavor-$arch-Build[0-9.]*\.install\.iso" | sort -uV | tail -n1)"
[ -n "$name" ] || { echo "no $product $flavor $arch ISO for $ver" >&2; exit 1; }

dir="$PWD/isos"
mkdir -p "$dir"
src="$dir/$name"
if [ ! -e "$src" ]; then
  curl -fSLk "$base/$name" > "$src.part"; mv "$src.part" "$src"
fi
# keep only the 2 newest builds per version (with their modified ISOs)
printf '%s\n' "$dir/$product-$ver-"*-Build*.install.iso | sort -V | head -n -2 | while read -r f; do rm -f "${f%.iso}"*; done
echo "$src"
