# agama-integration-skills

Agent skills for Agama integration testing: preparing install media and, as more skills land, running and
reviewing tests.

The skills are plain Markdown plus small shell scripts, so they work with any coding agent that can read files
and run shell commands. Harnesses that implement the [Agent Skills](https://agentskills.io) format pick up the
`SKILL.md` frontmatter directly.

## Skills

| Skill | Use it when | What it does |
|---|---|---|
| [`prepare-test-iso`](skills/prepare-test-iso/SKILL.md) | you need a SLES / SLES-NVIDIA 16.x install ISO for a VM test | Downloads the latest `:TEST` build (Online or Full) from download.suse.de and patches it: live password, grub timeout, register URL, extra boot params. Writes `./isos/last-prepared.json` for later skills. |

## Layout

```
skills/<name>/
  SKILL.md        entry point: inputs, the exact command to run, outputs
  scripts/        helper scripts, called from SKILL.md via <skill-dir>/scripts/
```

A skill never references files outside its own directory: installers copy the skill directory verbatim.
Skills hand over through files in the working directory (e.g. `./isos/last-prepared.json`), not through each
other's directories.

## Install

Requirements: `bash`, `curl`, and for `prepare-test-iso` also `xorriso` and `mkmedia`
(`mkmedia` from the [mksusecd](https://github.com/openSUSE/mksusecd) package). Access to the SUSE internal
network (download.suse.de).

Any harness, with an installer:

```
npx skills add qe-installation-and-migration/agama-integration-skills -g
gh skill install qe-installation-and-migration/agama-integration-skills prepare-test-iso --scope user
```

pi, as a package in `settings.json`:

```json
{ "packages": ["git:github.com/qe-installation-and-migration/agama-integration-skills"] }
```

Manual, tracking the git checkout:

```
git clone https://github.com/qe-installation-and-migration/agama-integration-skills.git
mkdir -p ~/.agents/skills ~/.claude/skills
ln -s "$PWD/agama-integration-skills/skills/prepare-test-iso" ~/.agents/skills/prepare-test-iso
ln -s ../../.agents/skills/prepare-test-iso ~/.claude/skills/prepare-test-iso   # Claude Code
```

Use one install method only: harnesses that scan several directories report duplicate names. The link or
directory name must equal the skill name, as the Agent Skills format requires.

## Development

CI ([`.github/workflows/ci.yml`](.github/workflows/ci.yml)) runs on every push and PR; run the same locally:

```
shellcheck skills/*/scripts/*.sh
skill-validator check skills/
```

[skill-validator](https://github.com/agent-ecosystem/skill-validator) checks the [Agent Skills spec](https://agentskills.io/specification)
(frontmatter, `name` = directory, layout) and flags files `SKILL.md` no longer references. Warnings fail CI too.

## License

GPL-2.0, like the other repositories in this organization. See [LICENSE](LICENSE).
