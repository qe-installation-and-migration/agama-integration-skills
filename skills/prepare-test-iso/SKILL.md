---
name: prepare-test-iso
description: "Download the latest SLES or SLES-NVIDIA TEST build (16.0, 16.1, 16.2; Online or Full) from download.suse.de and patch it for VM testing (live password, grub timeout, register URL). Use when the user asks to download/prepare/patch a SLES install ISO. Writes ./isos/last-prepared.json for later skills."
---

# Prepare Test ISO

Inputs: **source** (SLES `:TEST` build by default; `agama-devel` only if the user names it), **version** (`16.0`|`16.1`|`16.2`) and **flavor** (`Online`|`Full`). If either is missing, ask in one question and wait. Never guess or default the flavor.

Run exactly this from the working directory (no pipes or wrappers); `<skill-dir>` is this skill's directory. ISOs go to `./isos/`.

```bash
bash <skill-dir>/scripts/remaster.sh [--product SLES|SLES-NVIDIA] <version> <flavor> [--password <pw>] [--grub-timeout <sec>] [--register-url <url>] [boot-param ...]
```

Download only, no patching (last stdout line is the source ISO path, no JSON written):

```bash
bash <skill-dir>/scripts/download.sh [--product SLES|SLES-NVIDIA] <version> <flavor>
```

Development build instead of a SLES TEST build (only when the user asks for it, never as a fallback): the Agama Head live ISO from `Devel:/YaST:/Agama:/Head` (x86_64 only, no flavor, `16.1` or `16.2`). It is downloaded, checked against its `.sha512` and **not patched** (it autoboots; the live password is set later by the VM boot script), so no `--password`, `--grub-timeout`, `--register-url` or boot params are accepted. The output and `last-prepared.json` have the same shape (`"product":"agama-devel"`, `"patched":false`, empty `flavor`).

```bash
bash <skill-dir>/scripts/remaster.sh --source agama-devel <16.1|16.2>
```

| Option | Default |
|---|---|
| `--product` | `SLES` (`SLES-NVIDIA` is aarch64 only for now) |
| `--password` (`live.password`) | `nots3cr3t` |
| `--grub-timeout` | `3` (minimum `1`; `0` makes grub wait forever) |
| `--register-url` | latest version: `http://all-<build>.proxy.scc.suse.de`; older versions: none |
| extra args | passed verbatim as kernel boot params |

Only the latest `:TEST` build is used; the 2 newest builds per version are kept. The last stdout line is the modified ISO path (the source ISO is untouched). Everything else, including the build number, is in `./isos/last-prepared.json`; later skills should read it. Report the build number to the user.

If a script fails (e.g. `no SLES Online x86_64 ISO for <version>`), report the error in one line and stop. Do not probe other directories (`:PUBLISH`, main project, other versions) or offer substitute builds.
