---
name: prepare-test-iso
description: "Download the latest SLES or SLES-NVIDIA TEST build (16.0, 16.1, 16.2; Online or Full) from download.suse.de and patch it for VM testing (live password, grub timeout, register URL). Use when the user asks to download/prepare/patch a SLES install ISO. Writes ./isos/last-prepared.json for later skills."
---

# Prepare Test ISO

Inputs: **version** (`16.0`|`16.1`|`16.2`) and **flavor** (`Online`|`Full`). If either is missing, ask in one question and wait. Never guess or default the flavor.

Run exactly this (no pipes/wrappers), from the working directory:

```bash
bash <skill-dir>/scripts/remaster.sh [--product SLES|SLES-NVIDIA] <version> <flavor> [--password <pw>] [--grub-timeout <sec>] [--register-url <url>] [boot-param ...]
```

`<skill-dir>` is this skill's directory. ISOs go to `./isos/`. The ISO URL is always the latest in `https://download.suse.de/ibs/SUSE:/SLFO:/Products:/<SLES|SLES_NVIDIA>:/<version>:/TEST/product/iso/` (resolved and downloaded by `scripts/download.sh`).

Download only, no patching (last stdout line is the source ISO path, no JSON written):

```bash
bash <skill-dir>/scripts/download.sh [--product SLES|SLES-NVIDIA] <version> <flavor>
```

| Option | Default |
|---|---|
| `--product` | `SLES` (`SLES-NVIDIA` ships aarch64 only for now, so that arch is used) |
| `--password` (`live.password`) | `nots3cr3t` |
| `--grub-timeout` | `3` (minimum `1`; `0` makes grub wait forever) |
| register URL | latest version (auto-detected): `http://all-<build>.proxy.scc.suse.de`; older: none. `--register-url` overrides |
| extra args | passed verbatim as kernel boot params |
| retention | 2 newest builds per version |

Last stdout line is the modified ISO path (source ISO is untouched). Details (`iso`, `source_iso`, `version`, `flavor`, `build`, `password`, `grub_timeout`, `register_url`, `params`) are in `./isos/last-prepared.json`; later skills should read it. Report the build number to the user.

If the script fails (e.g. `no SLES Online x86_64 ISO for <version>`), report the error in one line and stop. Do not probe other directories (`:PUBLISH`, main project, other versions) or offer substitute builds; only the `:TEST` ISO is wanted.
