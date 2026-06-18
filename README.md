# agent-skills

Agent Skills for the Colossal storefront platform. Distributed via the [Agent Skills format](https://agentskills.io) and installable into ~50 coding agents (Claude Code, Cursor, Codex, GitHub Copilot, Gemini CLI, OpenCode, etc.) using the [`skills`](https://github.com/vercel-labs/skills) CLI.

## Skills in this repo

| Skill | Purpose |
|---|---|
| [`colossal-builder`](./skills/colossal-builder) | Generic Colossal Storefront SDK guide — hooks, providers, data constraints. Framework- and template-agnostic. |
| [`colossal-template-builder`](./skills/colossal-template-builder) | Build and redesign storefronts on the React Vite template — 3-file CSS architecture, theming, animations, image generation, redesign execution strategy. References `colossal-builder` and `colossal-design-library`. |
| [`colossal-design-library`](./skills/colossal-design-library) | Standalone catalog of design references (`design.json` + `theme.css` + `preview.html`). Self-describing — knows nothing about other skills. Editable in place after install. |
| [`colossal-store-design`](./skills/colossal-store-design) | Two capabilities: **(1) create** a new design reference from store screenshots (writes into `colossal-design-library`), and **(2) apply** an existing reference to any project — drops in for shadcn-based projects, translates to vanilla CSS / Tailwind / other stacks otherwise. |

These skills work as a set:

- `colossal-template-builder` is the entry point for building/redesigning storefronts on the React Vite template.
- It pulls SDK details from `colossal-builder` and design references from `colossal-design-library`.
- `colossal-store-design` writes new entries into `colossal-design-library`.

Install all four together for the full workflow, or just `colossal-builder` if you only need SDK guidance for a different template.

## Install

Install all skills into the current project:

```bash
npx skills add colossalhq/agent-skills --all
```

Pick specific skills and target agents:

```bash
npx skills add colossalhq/agent-skills \
  --skill colossal-builder \
  --skill colossal-template-builder \
  --skill colossal-design-library \
  --skill colossal-store-design \
  -a claude-code -a cursor \
  -y
```

Install globally (available across all projects):

```bash
npx skills add colossalhq/agent-skills -g
```

List without installing:

```bash
npx skills add colossalhq/agent-skills --list
```

After install, skills land at `<project>/.claude/skills/<name>/` for Claude Code and `<project>/.agents/skills/<name>/` for most other agents. The CLI auto-detects which agents you have installed.

## Update

```bash
# Refresh installed skills to the latest version on this repo's main branch
npx skills update

# Just one
npx skills update colossal-design-library
```

If you installed using the default symlink method, `update` refreshes the canonical local copy and every agent picks it up immediately. With `--copy`, you'll need `update` to actually replace the bytes.

## Layout

```
skills.sh.json            # skills.sh website page config (section grouping)
skills/
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
│       ├── bold-comfort-basics/
│       │   ├── design.json
│       │   ├── theme.css
│       │   └── preview.html
│       └── ... (16 entries total)
└── colossal-store-design/
    ├── SKILL.md
    └── scripts/
        ├── analyze.sh
        ├── gen-theme.cjs
        └── prompt.txt
```

## Cross-skill references

Once installed, all four skills are siblings under `<agent>/skills/`. They reference each other via relative paths and by name:

- `colossal-template-builder` mentions `colossal-builder` for SDK details (the model loads it from the catalog when needed) and reads `../colossal-design-library/references/<slug>/...` for theme/design data.
- `colossal-store-design` **writes** to `../colossal-design-library/references/<slug>/...` when creating new references (via `analyze.sh`), and **reads** from it when applying an existing reference to a non-Colossal project.
- `colossal-design-library` is the only skill with no outbound references — it doesn't know about any of the others.

If you install `colossal-store-design` without `colossal-design-library`, set `COLOSSAL_DESIGN_LIBRARY_DIR` to point at an existing library skill directory.

## Editing the design library

`skills/colossal-design-library/references/<slug>/` is plain files — `design.json`, `theme.css`, `preview.html` — and is intended to be edited. Either:

- Edit in your installed location (`<project>/.claude/skills/colossal-design-library/references/<slug>/`) for project-local tweaks. **Note:** `npx skills update` will overwrite local edits.
- Fork this repo, edit, push, and install from your fork (`npx skills add <your-org>/agent-skills`).

## Working with design references

`colossal-store-design` covers both directions:

**Create** — generate a new reference from a store screenshot:

```bash
export GEMINI_API_KEY=<key>

# Inside <project>/.claude/skills/colossal-store-design/ (or wherever installed):
bash scripts/analyze.sh ~/Desktop/store-screenshot.jpg my-new-slug
```

Output goes to `../colossal-design-library/references/my-new-slug/`. Commit it to your fork to share with the team.

**Apply** — adapt an existing reference to a project. Model-driven; no script. The skill detects the project's stack and applies the reference accordingly — direct drop-in for shadcn projects, translated mapping for Tailwind/vanilla CSS/Vue/Svelte/etc. For Colossal's React Vite template, `colossal-template-builder` handles the application instead.

## Specification

These skills follow the [Agent Skills specification](https://agentskills.io/specification): each skill is a directory with a `SKILL.md` containing YAML frontmatter (`name` matches the directory, `description` describes what the skill does and when to use it).

## License

Internal — Colossal.
