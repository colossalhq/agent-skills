---
name: colossal-store-design
description: Create and apply Colossal design references. Use when the user wants to (1) generate a new design reference from a store screenshot — produces design.json + theme.css into the colossal-design-library — or (2) apply an existing reference to a project. The bundled theme.css is shadcn-flavored, so it drops in directly for shadcn-based projects; for other stacks (pure HTML/CSS, Tailwind without shadcn, Vue, etc.) the reference is translated to fit the project's architecture. For Colossal's React Vite template, defer to colossal-template-builder.
---

# Colossal Store Design

Two capabilities:

1. **Create a reference** — analyze one or more store screenshots and produce a design.json + theme.css into the `colossal-design-library` skill.
2. **Apply a reference** — take an existing reference from `colossal-design-library` and apply its design (theme tokens, fonts, sections, component props) to any project, translating to match the project's stack when needed.

This skill is generic. It does not assume the target project uses Colossal's React Vite template; for that case use `colossal-template-builder` instead, which knows the file layout and component prop API.

---

## Capability 1 — Create a reference

Analyze a reference store screenshot using Gemini and produce two artifacts in the sibling `colossal-design-library` skill:

- **`design.json`** — component props, section blueprints, and metadata
- **`theme.css`** — shadcn-flavored CSS custom properties for the storefront `:root`

Output directory: `../colossal-design-library/references/<store-slug>/`

The `<store-slug>` must be **generic** — no actual store names. Use descriptive slugs like `dark-luxury-fashion`, `minimal-coffee-earth`, `bold-streetwear-neon`.

### Run the script

```bash
bash scripts/analyze.sh <image-path>... <store-slug>

# Single screenshot:
bash scripts/analyze.sh ~/Desktop/reference-store.jpg bold-comfort-basics

# Multiple screenshots of the same store, combined into one reference:
bash scripts/analyze.sh ~/Desktop/page1.jpg ~/Desktop/page2.jpg ~/Desktop/page3.jpg soft-luxe-beauty

# Override the model (default: gemini-3.1-pro-preview):
GEMINI_MODEL=gemini-2.5-flash bash scripts/analyze.sh ~/Desktop/ref.png dark-luxury-fashion
```

The script will:

1. Validate that the `colossal-design-library` skill is installed as a sibling (or `COLOSSAL_DESIGN_LIBRARY_DIR` is set).
2. Base64-encode the image(s).
3. Send to Gemini with the analysis prompt from `scripts/prompt.txt`.
4. Save `design.json` (pretty-printed, validated, header/footer link arrays stripped).
5. Run `scripts/gen-theme.cjs` to generate `theme.css` from the theme object.

### Verify output

```
../colossal-design-library/references/<store-slug>/
  design.json    ← full analysis JSON
  theme.css      ← shadcn-flavored CSS custom properties
```

Post-processing checks before considering the run done:

1. All hex colors are valid 6-digit hex with `#` prefix.
2. `meta.sectionNames` matches `name` fields in `sections` array.
3. No real store name appears anywhere in the JSON.
4. `radiusButton` matches the actual buttons in the screenshot, not the general radius.

### Prerequisites

- `GEMINI_API_KEY` environment variable
- `jq`, `node`, `curl`
- `colossal-design-library` skill installed as a sibling (or `COLOSSAL_DESIGN_LIBRARY_DIR` set to its path)

---

## Capability 2 — Apply a reference to a project

Take an existing reference and adapt the design (colors, fonts, radii, section blueprints, component props) into the user's project.

### Step 1 — Pick a reference

If the user named a slug, use it. Otherwise list the catalog and match on industry/aesthetic/mood:

```bash
bash ../colossal-design-library/scripts/list.sh
```

The user's brief might span multiple references — it's fine to take theme from one, hero layout from another, product card style from a third. Final design is typically a mix.

### Step 2 — Read the reference

```
../colossal-design-library/references/<slug>/
  design.json    # component props, section blueprints, metadata
  theme.css      # shadcn-flavored CSS variables
  preview.html   # visual snapshot of the original
```

`design.json` contains opinionated props for header, footer, productCard, productGrid plus an array of section blueprints (layout/design/content prose). `theme.css` is a self-contained `:root { ... }` block plus an optional `@theme inline { ... }` Tailwind mapping.

### Step 3 — Detect the project's stack

Inspect the project before applying:

- `package.json` → frameworks (React, Next.js, Vue, Svelte, Astro), Tailwind, shadcn (`@radix-ui/*` packages, `class-variance-authority`, `tailwind-merge`)
- `components.json` → shadcn project (definitive marker)
- Tailwind config presence → CSS variable / utility-first project
- Existing CSS files → vanilla CSS, CSS modules, styled-components, etc.
- Existing theme conventions in the codebase

### Step 4 — Apply along the path that matches

Choose one path. Don't mix.

#### Path A — Project IS the Colossal React Vite template

**Stop and defer to `colossal-template-builder`.** It owns the file map (`src/routes/index.tsx`, `client-shell.tsx`, the 3-file CSS split) and the Colossal-specific component prop API.

#### Path B — Project uses shadcn/ui (or shadcn-compatible CSS variables)

The reference's `theme.css` is already in shadcn format — drop it in:

1. Find the project's theme/global CSS file (commonly `src/index.css`, `app/globals.css`, `styles/globals.css`).
2. Replace the existing `:root { ... }` block with the reference's `:root { ... }`. Keep custom tokens.
3. If the project uses `@theme inline { ... }` (Tailwind v4), keep the reference's block too.
4. Install fonts from `theme.fontPackages` in `design.json`. Import them in the entry file.
5. **Sections are an inspiration menu, not a checklist** — see Step 5.

#### Path C — Project uses Tailwind without shadcn

Map the reference's CSS variables onto the Tailwind config:

1. In `tailwind.config.{js,ts}` → `theme.extend.colors`, mirror the semantic names (`background`, `foreground`, `primary`, `secondary`, `muted`, `accent`, `destructive`, `border`, `input`, `ring`, `card`, `popover`) using the hex values from `:root`.
2. Map `--font-sans`, `--font-display`, `--font-mono`, `--font-serif` → `theme.extend.fontFamily`.
3. Map `--radius` → `theme.extend.borderRadius.DEFAULT` and `--radius-button` to a custom utility if buttons differ.
4. Install fonts from `theme.fontPackages` and import them globally.
5. **Sections are an inspiration menu, not a checklist** — see Step 5.

#### Path D — Project is pure HTML + CSS (no build step)

1. Keep the reference's `:root { ... }` block as-is — works in any modern browser.
2. **Drop** the `@theme inline { ... }` block (Tailwind v4-specific, not portable).
3. Add font links in `<head>` — use the Google Fonts CDN equivalent of each `theme.fontPackages` entry. (`@fontsource-variable/playfair-display` → `https://fonts.googleapis.com/css2?family=Playfair+Display:ital,wght@0,400..900;1,400..900&display=swap`.)
4. Use the `--radius`, `--font-*`, color variables directly in component CSS.
5. **Sections are an inspiration menu, not a checklist** — see Step 5.

#### Path E — Other component framework (Vue, Svelte, Astro, plain Next.js)

- For projects with shadcn-style CSS variables → follow Path B.
- For projects with vanilla Tailwind → follow Path C.
- For projects with their own styling system (CSS-in-JS, scoped styles, etc.) → adapt the principle: take the design tokens and fonts, then express them in the project's idiom. Don't impose CSS variables if the project doesn't use them.

### Step 5 — Use sections selectively (don't translate everything)

`sections[]` is a **menu of ideas, not a checklist**. The reference's section list reflects the original store's needs, not your user's. Don't blindly translate every section into the target project.

**Default behavior:**

- Apply only the sections that make sense for the user's project type and stated requirements.
- The user's intent overrides the reference. If the user only asked for a hero, just do the hero.
- For sections you do apply, the reference describes them in prose (`layout`, `design`, `content`) — translate that prose into code in the project's idiom:
  - `layout` → grid/flex structure
  - `design.background` → background CSS or image
  - `design.text` → typography styles
  - `content.headline`, `content.body`, `content.cta` → real text adapted to the user's actual store/content (don't paste the reference's descriptive prose verbatim — it's a brief, not final copy)
  - `content.media.description` → an image generation prompt or a real image path
  - `content.items[]` → repeat the section structure for each item

**Apply all sections only when the user explicitly asks** (e.g. "match this reference exactly," "build a full landing page like in the reference"). Otherwise stay close to what the user asked for.

### Step 6 — Ignore component props (Colossal UI library only)

`design.json` includes `header.*`, `footer.*`, `productCard.*`, `productGrid.*`, and `featuredProducts.*`. **These props target the Colossal UI library specifically and should be ignored for any other project.**

When applying to a non-Colossal project:

- **Skip** the component prop fields entirely. They map to Colossal UI component APIs that don't exist elsewhere.
- The visual intent is already captured in `theme.css` (colors, radii, fonts) and in the section blueprints' `design` prose. That's enough to convey the look without translating Colossal-specific props.
- Don't try to invent equivalents (e.g. don't build a `productCard` component just because the reference has one — only build it if the user's project actually needs it).

If the target project IS using the Colossal UI library, defer to `colossal-template-builder` instead of this skill.

### Step 7 — Sanity checks

After applying:

- No `.dark {}` block (dark mode is not in the reference data).
- All fonts load — check that font packages are installed and imported.
- All hex colors render — no broken `var(--…)` calls.
- Internal links point to routes that exist. The reference doesn't include real navigation; don't invent `/about`, `/faq`, `/contact` pages unless the user asks.

---

## Available scripts

| File | Purpose |
|---|---|
| `scripts/analyze.sh` | Capability 1 — analyze screenshot(s) → design.json + theme.css into the library skill |
| `scripts/gen-theme.cjs` | Convert a `design.json` theme object into a self-contained `theme.css` (used by `analyze.sh`, also runnable standalone) |
| `scripts/prompt.txt` | The Gemini analysis prompt (edit to change extraction behavior) |

`gen-theme.cjs` standalone:

```bash
node scripts/gen-theme.cjs <design.json> <output.css>
```

---

## design.json schema

### Top-level structure

| Key | Type | Purpose |
|---|---|---|
| `meta` | object | description, industry, aesthetic, mood, sectionNames |
| `theme` | object | colors, customColors, radius, radiusButton, fonts, fontPackages |
| `header` | object | buttonStyle, size, layout, floating, colors, notes |
| `footer` | object | colorScheme, colors, description, notes |
| `productCard` | object | hoverEffect, cartButton, cartButtonIcon, carousel, notes |
| `productGrid` | object | columns (sm/md/lg/xl), gap, notes |
| `featuredProducts` | object | label, heading, notes |
| `sections[]` | array | section blueprints with layout, design, content |

### Key rules

- **No links in header or footer** — `header.links` and `footer.columns` do not exist in the schema. The `analyze.sh` script strips them if Gemini hallucinates them. Links are added by the customer later.
- **No real store names** — use generic descriptions everywhere.
- **No exact promo text** — describe generically ("promotional banner" not "Get 20% Off").
- **Button radius precision** — extract exact radius from CTA buttons: square = `0rem`, slightly rounded = `0.25rem`, rounded = `0.5rem`, pill = `9999px`.
- **Only one theme version** — extract what's visible (light or dark), don't generate the opposite.
- **No dark mode block** — `theme.css` never includes a `.dark {}` block.
- **Section descriptions are for AI** — descriptive prose, not Tailwind classes.
- **Image descriptions** are hints for AI image generation — mood, subject, lighting, composition.

### Component prop types

```typescript
// Header
type ButtonStyle = "default" | "icon";
type HeaderSize = "default" | "large";
type HeaderLayout = "standard" | "centered";
interface HeaderColors { bg?, text?, mutedText?, border?: string | false, badgeBg?, badgeText? }

// Footer
type FooterColorScheme = "default" | "inverted" | "custom";
interface FooterColors { bg?, text?, mutedText?, border?: string | false }

// Product Card
type CardHoverEffect = "lift" | "shadow";
type CardCartButton = "outline" | "ghost" | "icon-only" | "overlay";
type CardCartButtonIcon = "bag" | "plus";
type CardCarousel = "none" | "hover";
```

---

## Gemini API notes

Default model: `gemini-3.1-pro-preview`. Override with `GEMINI_MODEL`.

```bash
BASE_URL="${GOOGLE_AI_BASE_URL:-https://generativelanguage.googleapis.com}"
curl -s -X POST \
  "$BASE_URL/v1beta/models/gemini-3.1-pro-preview:generateContent" \
  -H "x-goog-api-key: $GEMINI_API_KEY" \
  -H "Content-Type: application/json" \
  -d @payload.json
```

Response: `jq -r '.candidates[0].content.parts[0].text' response.json`

**Important:** Gemini REST API uses camelCase keys: `inlineData`, `mimeType`, `responseMimeType`.
