---
name: colossal-design-library
description: Curated catalog of design references for the Colossal storefront template. Use when the user wants to pick a theme/aesthetic for a storefront, list available references, copy a ready-to-use theme.css, or read component props and section blueprints from an existing reference. Each entry bundles design.json (component props + section blueprints + metadata), theme.css (CSS tokens), and preview.html.
---

# Colossal Design Library

A catalog of storefront design references. Each entry is a `<slug>/` directory containing `design.json` (component props, section blueprints, metadata), `theme.css` (shadcn-flavored CSS variables ready to drop in), and `preview.html` (visual snapshot). Plain files, editable in place after install.

## Layout

```
references/
  <slug>/
    design.json     # component props, section blueprints, metadata
    theme.css       # ready-to-use :root { ... } + @theme inline { ... }
    preview.html    # visual preview of the reference
```

Each `<slug>` is a generic descriptor (no real store names): `dark-luxury-fashion`, `minimal-coffee-earth`, `bold-streetwear-neon`.

## Listing references

```bash
bash scripts/list.sh
```

Outputs a JSON array of `{ slug, meta }` objects. `meta` includes `description`, `industry`, `aesthetic`, `mood`, and `sectionNames`. Use it to match a user's brief against the library:

```json
[
  {
    "slug": "soft-luxe-beauty",
    "meta": {
      "description": "A soft, minimal beauty store with pastel pink aesthetic...",
      "industry": "beauty",
      "aesthetic": "soft-pastel",
      "mood": "calm and refined",
      "sectionNames": ["hero", "product-carousel", "promo-banner"]
    }
  }
]
```

## design.json schema

Top-level keys:

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

Rules baked into the data:
- **No `header.links` or `footer.columns`** — those are user-configured later, not extracted.
- **No real store names** anywhere.
- **No exact promo text or discount percentages** — described generically.
- **Single theme version only** — light or dark, not both.
- **No `.dark {}` block in theme.css** — dark mode is not supported.

## Modifying references

These files are intended to be edited:
- Tune colors in `<slug>/theme.css` directly.
- Adjust component props or section blueprints in `<slug>/design.json`.
- Replace `<slug>/preview.html` if visuals drift from the design.

`npx skills update colossal-design-library` will overwrite local edits with upstream — keep edits in your own fork or commit them to the source repo.

## Adding new references

Drop a new `references/<slug>/` directory containing `design.json` and `theme.css`. The slug must be generic (no real store names): `dark-luxury-fashion`, `minimal-coffee-earth`, etc. `list.sh` will pick it up automatically.
