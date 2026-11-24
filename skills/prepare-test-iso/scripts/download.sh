#!/usr/bin/env bash
# Download the latest SLES TEST ISO (or, with --source agama-devel, the Agama Head live ISO) into ./isos (cwd), keeping
# the 2 newest builds per version. Prints the ISO path.
set -euo pipefail
usage="usage: download.sh [--product SLES|SLES-NVIDIA] <16.0|16.1|16.2> <Online|Full>
       download.sh --source agama-devel [16.1|16.2]   (Agama Head development build, x86_64, no flavor; without a version: the newest one Head publishes)"

if [ "${1:-}" = --source ]; then
  [ "${2:-}" = agama-devel ] && [ $# -le 3 ] || { echo "$usage" >&2; exit 1; }
  ver="${3:-}"
  case "$ver" in ""|16.1|16.2) ;; *) echo "$usage" >&2; exit 1 ;; esac
  # Devel:YaST:Agama:Head, x86_64 only: other architectures would run emulated, too slow for local VM tests
  if [ -z "$ver" ]; then
    # the ISO name has no version of its own besides SUSE_SLE_<ver>, which is also the images_SLES-<ver> directory
    ver="$(curl -fsS "https://download.suse.de/ibs/Devel:/YaST:/Agama:/Head/?json" | grep -o 'images_SLES-[0-9.]*[0-9]' | sed 's/images_SLES-//' | sort -uV | tail -n1)"
    [ -n "$ver" ] || { echo "no images_SLES-* directory in Agama Head" >&2; exit 1; }
  fi
  base="https://download.suse.de/ibs/Devel:/YaST:/Agama:/Head/images_SLES-$ver/iso"
  name="$(curl -fsS "$base/?json" | grep -o "agama-installer\.x86_64-[0-9.]*-SUSE_SLE_$ver-Build[0-9.]*\.iso" | sort -uV | tail -n1)"
  [ -n "$name" ] || { echo "no Agama Head x86_64 ISO for $ver" >&2; exit 1; }
  dir="$PWD/isos"; mkdir -p "$dir"
  src="$dir/$name"
  if [ ! -e "$src" ]; then
    curl -fSL "$base/$name" > "$src.part"
    # the build's own checksum file lists the versioned name
    want="$(curl -fsS "$base/$name.sha512" | awk '{print $1}')"
    got="$(sha512sum "$src.part" | awk '{print $1}')"
    [ -n "$want" ] && [ "$want" = "$got" ] || { rm -f "$src.part"; echo "sha512 mismatch for $name" >&2; exit 1; }
    mv "$src.part" "$src"
  fi
  printf '%s\n' "$dir/agama-installer.x86_64-"*"-SUSE_SLE_$ver-Build"*.iso | grep -v -- -modified | sort -V | head -n -2 | while read -r f; do rm -f "${f%.iso}"*; done
  echo "$src"
  exit 0
fi

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
name="$(curl -fsS "$base/?json" | grep -o "$product-$ver-$flavor-$arch-Build[0-9.]*\.install\.iso" | sort -uV | tail -n1)"
[ -n "$name" ] || { echo "no $product $flavor $arch ISO for $ver" >&2; exit 1; }

dir="$PWD/isos"
mkdir -p "$dir"
src="$dir/$name"
if [ ! -e "$src" ]; then
  curl -fSL "$base/$name" > "$src.part"; mv "$src.part" "$src"
fi
# keep only the 2 newest builds per version (with their modified ISOs)
printf '%s\n' "$dir/$product-$ver-"*-Build*.install.iso | sort -V | head -n -2 | while read -r f; do rm -f "${f%.iso}"*; done
echo "$src"
