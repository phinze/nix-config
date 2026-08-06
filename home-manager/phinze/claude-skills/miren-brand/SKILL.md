---
name: miren-brand
description: Miren's brand system — the canonical color palette, typography, and logo assets. Load before choosing any color, font, or logo for anything Miren-facing: web UI, dashboards, docs sites, marketing pages, slides, diagrams, README banners, social images, or charts. Also load when reviewing existing Miren UI for brand drift, or when asked for "the brand colors", "our blue", "the Miren logo", or which logo variant to use on a given background.
---

# Miren Brand

The brand lives in `mirendev/brand`, extracted from Fred's Figma exploration and
kept in sync with it. This skill pins a read-only copy at:

```
@BRAND@
```

Read `@BRAND@/BRAND.md` before making brand decisions. It is the source of
truth, and it is long on purpose — the full 39-shade palette with CMYK/Pantone
values, the complete type scale, contrast ratios, clear-space and minimum-size
rules, and a ready-made CSS custom-property block under "Web Implementation".

## The one rule

**Do not invent colors.** Every color in Miren-facing work comes from the
palette below or from the extended scales in `BRAND.md`. This is the single
most common way agent-generated UI goes off-brand: it approximates the blue,
picks a "close enough" gray, or invents a semantic green nobody chose. Pull the
exact hex. If the palette genuinely has no shade for what you need, say so and
ask rather than inventing one — that's a brand decision, and it belongs
upstream (see "Steering the brand" below).

The same discipline applies to type. Hanken Grotesk is the brand face and
DM Mono is the technical face. Don't substitute a system stack because it was
convenient.

## Quick reference

Enough to answer most questions without opening `BRAND.md`. Anything beyond
this, go read the file.

| Role | Token | Hex |
|---|---|---|
| Primary blue | Topaz 700 | `#0059FF` |
| Hover / darker blue | Topaz 800 | `#0844C5` |
| Secondary blue, accents | Topaz 300 | `#80ABFF` |
| Warm accent, buttons on blue | Terra Cotta 500 | `#F6834B` |
| Primary text on light | Slate 800 | `#1B1F27` |
| Secondary text | Slate 500 | `#767989` |
| Warm background | Vanilla 100 | `#F8F1DD` |
| White | Slate 00 | `#FFFFFF` |

Four families, all in `BRAND.md`: **Topaz** (blues, 11 shades), **Terra Cotta**
(warm accents, 11), **Slate** (neutrals, 12), **Vanilla** (warm neutrals, 5).

**Type.** Hanken Grotesk (400/600/700/800/900) for everything; DM Mono for
technical and accent headers. Montserrat is the documented web fallback. Both
brand faces are on Google Fonts.

**Logos** live in `@BRAND@/assets/logos/`, in SVG, PNG, and PDF. Pick by
background, not by preference:

- Blue or dark background → `Miren-Logo-White.*`
- White or light background → `Miren-Logo-Secondary.*`
- Single-color printing → `Miren-Logo-Black.*` or `Miren-Logo-Mono.*`
- `Miren-Logo-Primary.*` is white-on-blue as a self-contained lockup, and is
  the preferred mark when you control the whole surface.

Use SVG for anything web or scalable. Icons and square avatars are in
`@BRAND@/assets/icons/`.

## Building web UI

`BRAND.md` ships a complete `:root` CSS custom-property block with all 39
shades plus semantic aliases (`--color-primary`, `--color-accent`,
`--color-text-primary`, and friends). Copy that block rather than retyping
hexes, and bind components to the semantic aliases so a future palette change
is one edit. Every combination documented in `BRAND.md` is WCAG AA compliant;
if you compose a new pairing, check the contrast yourself.

When the work is product UI — dashboards, admin panels, settings, data views —
pair this with the `interface-design` skill. That one handles hierarchy,
density, states, and craft; this one constrains the palette and type. They
compose: take the color world from here, not from a domain exploration.

## Steering the brand

If the work turns up a scenario the brand doesn't cover yet — a new semantic
color, a chart palette, a component pattern that should be consistent
everywhere — that's worth pushing upstream rather than solving locally and
forgetting. Paul has an open invitation from the design side to do exactly
this: land it in `mirendev/brand` and it gets picked up during brand work.

The pinned copy above is read-only (it's a Nix store path). To contribute, work
in a real checkout of `mirendev/brand`, then bump the input here so the pin
follows.

**Figma source:** the brand exploration lives at
`figma.com/design/nWDJh0pG0sOTiD2dulao3O/Miren-Branding-Exploration`, by Fred.
`BRAND.md` back-references it. The repo is the practical source of truth for
code; the Figma is where brand decisions get made.
