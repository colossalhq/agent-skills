# AGENTS.md — Colossal Skills Repository Guide

This document orients AI coding agents (Claude Code, Cursor, Codex, OpenCode, Gemini CLI, GitHub Copilot, etc.) working in this repository. It explains what the repo is, how it's structured, and the conventions to follow when reading, editing, or adding to it.

`CLAUDE.md` is a symlink to this file — both names exist for cross-tool discovery, but there is only one source of truth.

---

## What this repo is

A collection of [Agent Skills](https://agentskills.io) for the Colossal storefront platform. Skills are distributed via the [`skills`](https://github.com/vercel-labs/skills) CLI and installable into ~50 coding agents:

```bash
npx skills add colossalhq/colossal-skills --all
```

There is no build step. The repo IS the published artifact — every file under `skills/<name>/` is what consumers receive verbatim.

---

## Repository layout

```
colossal-skills/
├── AGENTS.md             ← this file
├── CLAUDE.md             ← symlink to AGENTS.md
├── README.md             ← user-facing install / update guide
├── .gitignore
└── skills/
    ├── colossal-builder/
    │   └── SKILL.md
    ├── colossal-template-builder/
    │   ├── SKILL.md
    │   └── scripts/
    │       └── gen-image.sh
    ├── colossal-design-library/
    │   ├── SKILL.md
    │   ├── scripts/
    │   │   └── list.sh
    │   └── references/
    │       ├── <slug>/
    │       │   ├── design.json
    │       │   ├── theme.css
    │       │   └── preview.html
    │       └── ... (16 entries)
    └── colossal-store-design/
        ├── SKILL.md
        └── scripts/
            ├── analyze.sh
            ├── gen-theme.cjs
            └── prompt.txt
```

Every directory under `skills/` is one skill. The directory name MUST match the `name:` field in its `SKILL.md` frontmatter.

---

## The four skills and how they relate

| Skill | Role | Has scripts | Cross-skill refs |
|---|---|---|---|
| `colossal-builder` | Generic Colossal Storefront SDK guide (hooks, providers, types). Framework-agnostic React docs. | No | None |
| `colossal-template-builder` | React Vite template specifics — 3-file CSS architecture, theming, image generation, redesign workflow. | `gen-image.sh` | Mentions `colossal-builder` (SDK) and `colossal-design-library` (data) |
| `colossal-design-library` | Standalone catalog of design references — `design.json` + `theme.css` + `preview.html` per `<slug>/`. | `list.sh` | **None.** Self-describing. Knows nothing about other skills. |
| `colossal-store-design` | (1) Create new references from screenshots via Gemini → writes into `colossal-design-library`. (2) Apply an existing reference to any project — drops in for shadcn, translates for vanilla CSS / Tailwind / Vue / etc. | `analyze.sh`, `gen-theme.cjs`, `prompt.txt` | Reads from and writes to `colossal-design-library` |

Once installed, all four skills land as siblings under `<agent>/skills/`. Cross-references use the relative path `../<sibling-skill>/...`. This works regardless of which agent's path convention is used (`.claude/skills/`, `.agents/skills/`, `.cursor/skills/`, etc.) because every CLI installs siblings under the same parent.

**Hard rule:** `colossal-design-library` is intentionally standalone. Its `SKILL.md` must never mention any other skill by name. Any "this is consumed by X" framing belongs in this `AGENTS.md` or in `README.md`, not inside the library skill.

---

## Spec compliance

Skills follow the [Agent Skills specification](https://agentskills.io/specification). Every `SKILL.md`:

- Starts with YAML frontmatter between `---` delimiters.
- Has a `name` field — 1-64 chars, lowercase a-z + digits + hyphens, no leading/trailing/consecutive hyphens, **must match parent directory name**.
- Has a `description` field — 1-1024 chars, written imperatively ("Use when...") with concrete trigger keywords. The description carries the entire burden of skill activation; agents see only this at startup until they decide to load the body.
- Markdown body should stay under ~500 lines / ~5,000 tokens. Move long reference content into `references/<topic>.md` and tell the agent when to load it.

Optional but allowed: `license`, `compatibility`, `metadata`, `allowed-tools`. Don't add `compatibility: ...LICENSE.txt` if no LICENSE.txt is shipped — that's a dead reference.

The official spec defines three optional directories: `scripts/` (executables), `references/` (on-demand docs), `assets/` (static templates). Use them when they fit; don't force content into the wrong bucket.

---

## How a skill is consumed

Three-tier progressive disclosure (per spec):

1. **Catalog** — at session start, the agent reads only `name + description + location` for every installed skill. ~50-100 tokens per skill.
2. **Activation** — when a task matches a description, the agent loads the full `SKILL.md` body.
3. **Resources** — `scripts/`, `references/`, and bundled files load only when the body explicitly references them.

Write skills so the body is useful **after** the agent has decided the skill applies — it's already committed; don't re-justify the skill, just describe how to do the job.

---

## Conventions

### Paths in SKILL.md

- Use relative paths from the skill root (e.g. `scripts/gen-image.sh`, `references/<slug>/design.json`).
- For cross-skill access, use sibling paths (e.g. `../colossal-design-library/references/<slug>/`). Don't hardcode `.claude/skills/...` — that breaks every agent except Claude Code.
- Don't use absolute paths. Don't assume a specific cwd.

### Scripts

Every skill that ships executable code uses a `scripts/` subdirectory. Scripts must:

- Be non-interactive (no TTY prompts). Take all input via flags / env vars / stdin.
- Document themselves with `--help` (or a header comment).
- Print structured output on stdout (JSON / TSV when possible) and diagnostics on stderr.
- Use distinct exit codes for different failure types.
- Be idempotent where reasonable; agents may retry.
- Be `chmod +x` in git so they're directly executable post-install.

For scripts that need to find a sibling skill, derive the path from `$(dirname "$0")` rather than hardcoding it. Provide an env-var override (e.g. `COLOSSAL_DESIGN_LIBRARY_DIR` for `analyze.sh`) so users can install skills in non-default locations.

### Writing style for SKILL.md

- **Imperative, second-person tone.** "Use this skill when...", "Run X", "Read Y before Z."
- **Tables for hook surfaces, fields, options.** Agents pattern-match better against tables than against bullet prose.
- **Code blocks for runnable commands and snippets.** Always specify the language.
- **Bold for hard rules** (`**Never edit styles.css.**`).
- **A "Gotchas" section near the end** for non-obvious pitfalls — this is high-value content per the best-practices guide.
- **No marketing copy.** No "powerful," "robust," "seamless," etc. State what the skill does and what to do.

### Cross-skill mentions in SKILL.md bodies

- ✅ Allowed in `colossal-builder`, `colossal-template-builder`, `colossal-store-design`.
- ❌ Not allowed in `colossal-design-library` — it must remain standalone.

When a skill mentions a sibling, write the path explicitly (`../colossal-design-library/scripts/list.sh`) so the agent can act without further inference.

### Descriptions

Per the [optimizing-descriptions guide](https://agentskills.io/skill-creation/optimizing-descriptions):

- Imperative phrasing ("Use this skill when...").
- List concrete user intents, not implementation details.
- Include keywords for the kinds of prompts that should trigger the skill, even when the user doesn't name the domain directly.
- Stay concise. The 1024-char hard cap is generous; aim for less.
- One description per skill — don't try to be a checklist.

---

## Adding or editing a skill

### Edit an existing skill

1. Edit the relevant `skills/<name>/SKILL.md` and/or scripts directly.
2. Verify the file is well-formed: frontmatter parses, `name` matches the directory, description is under 1024 chars.
3. If you touched a script, smoke test it.
4. Commit. Consumers run `npx skills update` to pick up the change.

### Add a new skill

1. Pick a name: lowercase, hyphens, no leading/trailing/consecutive hyphens, must be unique within `skills/`.
2. Create `skills/<name>/SKILL.md` with valid frontmatter and an imperative description.
3. If shipping executables, put them in `skills/<name>/scripts/` and `chmod +x` them.
4. Update the README's skills table and layout tree.
5. Update this AGENTS.md "four skills" table if appropriate.

### Add a new design reference (data, not code)

Run `colossal-store-design`'s analyze script:

```bash
export GEMINI_API_KEY=<key>
bash skills/colossal-store-design/scripts/analyze.sh ~/Desktop/screenshot.jpg my-new-slug
```

Output goes to `skills/colossal-design-library/references/my-new-slug/`. Slugs must be generic (no real store names).

To bypass the script and add a reference by hand, drop a directory at `skills/colossal-design-library/references/<slug>/` containing `design.json` and `theme.css`. `list.sh` will pick it up automatically because it walks `references/*/` looking for `design.json`.

### Don't

- Don't introduce a skill that depends on another being installed without graceful failure. Scripts that need a sibling should error with a clear message ("install X, or set `<ENV_VAR>`"), not crash.
- Don't add hidden coupling to `colossal-design-library`. It stays generic.
- Don't add backwards-compat shims. Change the code. Skills version through the source repo, not in-file.
- Don't write docstrings or block comments inside SKILL.md scripts unless they're useful for the agent (one-line header + `--help` output is usually enough).
- Don't commit `.DS_Store` or `node_modules/` (`.gitignore` covers this).

---

## Storefront SDK reference

`colossal-builder/SKILL.md` documents `@colossal-sh/storefront-sdk` based on the actual source at `colossal-shop/packages/storefront-sdk`. When the SDK changes, update that SKILL.md to match — don't let the docs drift.

The SDK itself enforces these data constraints across every Colossal storefront, regardless of template:

- No contact, review, or newsletter forms.
- No login, account, or wishlist pages.
- No email inputs, even as static elements.

Any UI implying a backend the SDK doesn't expose is broken by definition. Both the builder and template-builder skills enforce this.

---

## Distribution and updates

- The repo's default branch is the only "version" — there is no semver pinning in the `skills` CLI.
- Consumers refresh with `npx skills update`. With the default symlink install, the canonical local copy is updated and every agent's symlinked path picks it up.
- A `--copy` install creates standalone copies; those need `update` to actually replace the bytes.
- User-local edits at `<project>/.claude/skills/<name>/...` get overwritten on `update`. Document this when relevant.

---

## Quick checks before committing

- [ ] `name:` field matches the parent directory name in every changed skill.
- [ ] Description is imperative and under 1024 chars.
- [ ] All cross-skill paths use `../<sibling>/...`, not absolute paths.
- [ ] Scripts are `chmod +x` and non-interactive.
- [ ] `colossal-design-library/SKILL.md` doesn't mention any other skill.
- [ ] README skills table and layout tree match the actual filesystem.
- [ ] No `.DS_Store` files snuck in.
