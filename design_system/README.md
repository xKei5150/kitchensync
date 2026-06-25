# KitchenSync Design System

The canonical design system for KitchenSync — an editable **HTML/CSS mirror** of the
Flutter app's design tokens, hosted on **Claude Design**.

It tracks two source files:

- `lib/app/design_tokens.dart` — `KsTokens` (colors, spacing, radii, type ramp, motion)
- `lib/app/theme.dart` — light/dark `ColorScheme` resolution

Every value here is a faithful reflection of those two files. When the Flutter tokens
change, the mirror is re-synced (see [Re-sync](#re-sync)). The HTML is the place to
*see* and *propose* design decisions; the Dart is the place they ship.

---

## Structure

```
design_system/
├── styles/
│   ├── tokens.css      # SINGLE SOURCE OF TRUTH — CSS-var mirror of KsTokens
│   └── base.css        # shared card chrome + helper classes
├── foundations/        # the raw vocabulary
├── components/         # reusable UI primitives
└── screens/            # assembled compositions
```

### `styles/`

- **`tokens.css`** — the only place color, space, radius, type, and motion values live.
  Cards read these via `var(--…)` and **never** hardcode a hex. `:root` is the light
  theme; `[data-theme="dark"]` overrides only the tokens that change.
- **`base.css`** — shared "card chrome": `.ds`, `.ds-head` (`.ds-eyebrow` / `.ds-title`
  / `.ds-sub`), the `.ds-themes` light/dark grid, `.ds-panel`, `.ds-surface`, the
  `.t-*` type ramp, `.swatch*` helpers, `.spec` tables, `.badge-proposed`, and layout
  atoms (`.row` / `.col` / `.wrap` / `.between`). Reuse these before adding new CSS.

### `foundations/`

The raw design vocabulary, one card per concept:

- **color** — brand, freshness, neutrals, ingredient categories (14), pantry sections (4)
- **type** — the Fraunces (display) + DM Sans (body) ramp
- **spacing** — the 4-base scale
- **radius** — the corner-radius scale
- **elevation** — soft warm shadows
- **motion** — durations and easing curves

### `components/`

Reusable UI primitives, each shown in light **and** dark:

- tags & badges
- freshness indicators
- buttons
- inputs
- cards
- tiles
- sheets
- empty states
- section tabs

### `screens/`

Full compositions that assemble foundations + components into real app surfaces
(pantry home, ingredient detail, add-item flow, and so on).

---

## Card convention

Every card is a standalone HTML5 document. The pattern, mirrored across the system:

1. **First line is a marker comment** declaring its group, e.g.
   `<!-- @dsCard group="Components — Tags" -->`.
2. **`<head>` links both stylesheets** with relative paths (cards live one directory
   deep, so `../styles/` is correct):

   ```html
   <link rel="stylesheet" href="../styles/tokens.css" />
   <link rel="stylesheet" href="../styles/base.css" />
   ```

3. **`<body class="ds">`** opens with a `<header class="ds-head">` (eyebrow, title, sub).
4. **Light + dark** are shown side by side via a `.ds-themes` grid: one normal
   `.ds-panel` and one `.ds-panel` with `data-theme="dark"`, which re-resolves the
   token vars.
5. Card-specific CSS goes in a `<style>` block **after** the two `<link>`s, and reuses
   `base.css` helpers wherever possible.
6. **Alpha tints** use `color-mix(in srgb, var(--c) N%, transparent)` to mirror
   Flutter's `withValues(alpha:)` — typically `8 / 10 / 12 / 15%` fills and `85%` text.

No JavaScript: cards are pure CSS mockups (a subtle CSS-only hover/transition is fine).

---

## Token mapping to Flutter

| CSS in `tokens.css`              | Flutter source                                  |
| -------------------------------- | ----------------------------------------------- |
| `:root { … }`                    | `KsTokens` — the light values                   |
| `[data-theme="dark"] { … }`      | `theme.dart` dark `ColorScheme` overrides       |
| `--brand-*`, `--fresh`, …        | the corresponding `KsTokens` constants          |
| `--cat-*` (14), `--section-*` (4)| ingredient category + pantry section colors     |
| `--cat-*-dark` (14)              | `KsTokens` dark set · `IngredientCategoryColor.colorFor` |
| `--cal-*` (4)                    | `KsColors` calendar status (brightness-aware)   |
| `--surface-sunken`, `--hairline` | `KsColors` editorial surfaces (brightness-aware)|
| `--member-1..6`                  | `KsColors.memberTicks` / `memberTick(seat)`     |
| `--proposed-*`                   | `KsColors` semantic set (success/info/warning/…)|
| `--space-*`, `--radius-*`        | `KsTokens` spacing / radius scales              |
| `--*-size/-weight/-lh/-ls`       | `KsTokens` text-style ramp                      |
| `--display-xl/-2xl-*`            | `KsTokens.displayXl` / `KsTokens.display2xl`    |
| `--dur-*`, `--curve-*`           | `KsTokens` motion (durations + easing curves)   |

**In code today.** The editorial-farmhouse Foundations are now graduated into the
Flutter design system — every token family in the mirror exists in `design_tokens.dart`:

- `--proposed-*` — the semantic set (`disabledFill` / `disabledText`, `focusRing`,
  `success` / `info` / `warning`, `scrim`) ships on the `KsColors` theme extension. The
  `--proposed-*` alias names are kept only so existing cards keep resolving.
- `--cat-*-dark` — the luminance-lifted dark category set ships as `KsTokens.cat*Dark`,
  resolved per-theme by `IngredientCategoryColor.colorFor(Brightness)`.
- `--cal-*`, `--surface-sunken` / `--hairline`, `--member-1..6` — calendar status,
  editorial surfaces, and member ticks ship on the brightness-aware `KsColors`.
- `--display-xl-*` / `--display-2xl-*` — the hero ramp ships as `KsTokens.displayXl`
  and `KsTokens.display2xl`.

A card may still badge a token `proposed` while the *component or screen* that consumes
it is unbuilt, but the token itself now exists in the Flutter app.

---

## Re-sync

The folder maps to Claude Design through the **DesignSync** tool:

1. **`create_project`** — registers the design system project.
2. **`finalize_plan`** over `design_system/**` — stages the full set of cards + styles.
3. **`write_files`** — pushes the staged files to Claude Design.

**Updating one card:** edit the HTML file (or `tokens.css`), then re-run the sync — it
re-publishes just the changed card, so you don't have to touch the rest of the system.

**Golden rule:** change a value in `tokens.css`, never in a card. Cards consume tokens;
they don't define them. When the Flutter tokens move, update `tokens.css` to match and
re-sync — every card inherits the change for free.
