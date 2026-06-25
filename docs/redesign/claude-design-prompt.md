# KitchenSync — Claude Design Brief

> Paste everything below the line into a **new Claude Design project**. It is written as a
> self-contained brief addressed to the design model. It is long on purpose: it is reference
> material you consult **phase by phase** (see §2), not a single to-do you execute at once.

---

## 0. Mission

You are art-directing and designing **KitchenSync** — a household kitchen-management app for
iOS and Android (built in Flutter). It exists today as a working prototype: the pantry and
ingredient-dictionary flows are real and usable, but the look is a developer baseline, not a
designed product, and most of the app's vision is unbuilt. Your job is to design the **whole
product** — onboarding through premium power-features — as one cohesive, opinionated,
shippable system that looks like a product people pay for, not a template.

Keep the **soul** of the current identity (warm, earthy, food-forward; Fraunces + DM Sans;
green-and-amber on warm linen; first-class dark mode) and **elevate the execution**: stronger
hierarchy, editorial composition, real depth, designed motion, and a distinct visual
fingerprint per module. You **may extend** the palette, type ramp, and spacing beyond what
exists today — we reconcile the engineering tokens to your decisions afterward. Design for the
best result.

Deliver two layers: **(A) a refreshed design system** (foundations + components) and **(B) hero
screens** that assemble it. Everything in **light and dark**.

---

## 1. The product in one screen (context — read once, then design)

KitchenSync runs a household's whole food operation as **one synchronized loop**:

> **Recipes → Calendar (plan meals) → Shopping (buy what you lack) → Pantry (track what you
> have) → cook → leftovers & waste feed back into the Calendar → repeat.**

Load-bearing truths:

- **The Calendar is the brain.** Scheduling a meal drives everything downstream — it generates
  shopping needs and deducts from the pantry when you cook.
- **The Ingredient Dictionary is the spine.** Every recipe, pantry item, and shopping line
  references one canonical ingredient (consistent names, units, shelf life).
- **The Pantry is the single source of truth for inventory.**
- **Waste reduction is the emotional payoff** — the app helps people stop re-buying what they
  have and stop letting food rot.

**Households & roles.** A household has up to 6 members (premium; solo users get a private
one-person household). Roles: **Admin, Cook, Shopper, Member.** Shopping checklists are
**shared**; premium adds **per-member color-coded ticks** (who grabbed what).

**Dish lifecycle (name these states 1:1 in the UI):** `scheduled → cooked → leftover →
consumed / waste → cancelled`.

**Two genuinely distinctive mechanics — make them visually legible, not buried:**

1. **Shop Now partial fulfillment.** When you shop early, only the items you *actually buy* are
   subtracted from future scheduled lists — future lists visibly shrink. "Buying ahead pays
   down the future" should feel tangible.
2. **Shared household shopping** with per-member ticks and role-aware capability.

**Free vs Premium.** Premium unlocks: **Menu Sets** (reusable meal-plan templates applied to
the calendar by **modulo cycling** over a date range, in **Replace** or **Fill-empty** mode —
the "wow" feature); **pantry intelligence** (days-until-empty prediction, bulk-buy planning,
waste analytics); **Paste & Parse** bulk recipe import; **budget + target-servings** recipe
search; **meal merging** (one dish serving two meals); per-member checklist colors; joint
households.

---

## 2. How to generate this (operational contract — follow exactly)

### 2.1 Work in phases. Stop after each phase and wait for review.

Do **not** attempt the whole system in one pass — it will go shallow or truncate. Generate in
this order; after each phase, **stop and summarize what you produced**, then wait:

- **Phase 0 — Art-direction cover + Foundations** (all of §6 foundations). Foundations are the
  contract; lock the full token set here.
- **Phase 1 — Components** (§6 components + the Navigation card). 1a: primitives; 1b: the new
  module components.
- **Phase 2 — P0 screens**, in sub-batches of **3–4 artboards max** per response:
  2a Home + Calendar (month & week); 2b Dish-in-Date + Shopping checklist; 2c Pantry.
- **Phase 3 — P1 screens.**
- **Phase 4 — P2 screens.**

Every component and screen consumes Foundations tokens by `var(--…)` **only**. If a screen
needs a value that doesn't exist, add it to Foundations first and flag it.

### 2.2 Output format — the card convention (this repo already uses it)

Produce **each** foundation, component, and screen as its **own standalone HTML5 document** —
one self-contained card per concept, never one giant page. Each card MUST:

1. Begin with a marker comment: `<!-- @dsCard group="<Group> — <Name>" -->` (groups:
   `Foundations`, `Components`, `Screens`).
2. Define **all** color/space/radius/type/motion values as CSS custom properties in a `:root{}`
   block, with a `[data-theme="dark"]{}` block overriding **only** the tokens that change.
   **Never hardcode a hex in markup** — cards consume tokens.
3. Use `color-mix(in srgb, var(--token) N%, transparent)` for tinted fills (mirrors Flutter
   alpha — typically 8/10/12/15% fills, 85% text).
4. Use **no JavaScript**. A subtle CSS-only hover/press transition is the only live motion.
5. **Badge** any token you introduce that isn't already in the system as `proposed`.

**Light + dark layout differs by layer:**
- **Foundations & Components:** show light and dark **side by side** in a two-panel grid; the
  dark panel is a container carrying `data-theme="dark"`.
- **Screens:** render as a **phone-width frame (~390px)**; place the **light frame and dark
  frame next to each other**, the dark one in a `data-theme="dark"` container.

### 2.3 States policy (prevents render-bloat)

Do **not** render every state for every screen. Show each screen's **primary** state in
light + dark, plus only the **one or two load-bearing** extra states named in §10. Reserve full
empty/loading/error treatment for the dedicated **empty-state** and **error-alert** component
cards; screens reference those rather than redrawing them.

### 2.4 Motion is documented, not animated

In the Motion foundation, list durations + easing as tokens. For each **signature moment**
(§8), show it as a labeled **before → after frame pair** plus a one-line spec (property,
duration token, curve token, reduced-motion fallback). No JS, no auto-play.

### 2.5 No external image dependencies

Do not link external images. Represent food/ingredient imagery with **CSS only**:
category-tinted gradient/placeholder blocks, the category-tinted thumbnail component, or subtle
CSS linen texture. Where a real photo would go, use a labeled tinted placeholder so the
composition reads with zero asset dependency.

---

## 3. The current baseline (the "before" you are evolving)

So "keep the soul" is verifiable, here is what exists today. Treat it as the *before*; you are
raising its ceiling, not replacing its DNA.

**What's built (≈8 real screens):** a basic routed **Home** (a Fraunces title + "What is in
your kitchen today?" over a grid of nav cards — placeholder, redesign it), **Pantry home**
(4 section tabs), **Add pantry item**, **Pantry item detail** (hero photo, quantity stepper,
mark-as-waste sheet), **Waste log** (bare list — overhaul it), **Ingredient picker** (debounced
search), **Ingredient detail**, **Create custom ingredient**. Everything else in §10 is **new**.

**Verified current tokens (match these as your starting point, then extend):**
- Brand green `#2E7D32` (light `#4CAF50`, dark `#1B5E20`); amber accent `#F9A825`.
- Warm-linen neutrals: base `#FAFAF7`, raised `#FFFFFF`; text `#1A1C16` / `#5F6651` / `#8B9183`.
- Freshness: fresh `#43A047`, expiring-soon `#FFB300`, expired `#C62828`, low-stock brown `#6D4C41`.
- 14 ingredient-category hues; 4 pantry-section hues (Food/Bulk/Non-Food/Leftover).
- Spacing on a 4-base scale; a radius scale (4→20 + full); soft warm shadows; motion
  150/300/500ms with easeOutCubic-family curves.
- Type: **Fraunces** (display → headline), **DM Sans** (title → label/body).
- **Semantic tokens already ship** in a brightness-aware `KsColors` extension (light + dark):
  `success / info / warning / danger / scrim / disabledFill / disabledText / focusRing`. Treat
  these as **existing**, not proposed. The **only** genuine proposal not yet in code is a
  **luminance-lifted dark-mode category set** — badge that `proposed`.

---

## 4. Art direction

### 4.1 The direction — *editorial farmhouse*

A beautifully art-directed cookbook that happens to run your kitchen logistics. Warm, tactile,
confident, calm. Linen-paper surfaces, a characterful serif for personality, a precise sans for
dense data. Generous editorial breathing room on hero/empty surfaces; tight, scannable density
on working surfaces (calendar grid, checklist, pantry list). It should respect food and respect
the user's time.

**Reference anchors (triangulate from these — match their qualities, don't copy):** the
typographic confidence and captioned-imagery rhythm of a *Kinfolk / Cereal*-style food
magazine; the warm editorial plating of a modern cookbook (*Salt Fat Acid Heat*); *NYT Cooking*'s
information density, made warmer. Think "food magazine meets a calm planning tool."

### 4.2 Design language — signature moves (the through-line; reuse on every surface)

These are not suggestions. They are what makes the five modules read as **one** product:

1. **Editorial measure.** Body and ingredient text sit in a narrow measure (~60–66ch feel)
   against wider full-bleed bands — never edge-to-edge running text.
2. **Running header / folio system.** A small uppercase eyebrow + a folio-style section marker
   on every screen (same system everywhere).
3. **Oversized Fraunces numerals as a recurring motif** — serving counts, day numbers,
   days-until-empty, money saved — treated as **display typography**, not UI labels.
4. **Italic Fraunces captions** under imagery and metric tiles.
5. **A recurring divider** — a hairline rule + a small botanical ornament (a sprig/leaf glyph)
   or a torn-linen edge — used as the section break across the app.
6. **Asymmetric, grid-breaking hero blocks** on empty/landing surfaces; **tight aligned grids**
   on working surfaces. The two postures are how density and warmth coexist.

### 4.3 Typography

- **Fraunces** for titles, hero numerals, recipe names, empty-state headlines, emotional
  moments. Exploit its character: high optical size for hero numerals/titles to get dramatic
  contrast; lean into its soft/wonky display personality; restrained at small italic captions.
- **DM Sans** for everything functional — lists, forms, metadata, buttons, chips, the calendar.
- Build a real ramp with **strong scale contrast**. The current ceiling (~36px) is timid — you
  have permission to extend it: introduce a **Display-XL (~52–64px)** for empty states and key
  metrics. The largest type on any screen should be **Fraunces, not a sans label**. Tight
  tracking on small uppercase labels. Signature treatments: a **drop cap** on recipe intros;
  **oversized italic numerals** on insight tiles.

### 4.4 Color — and the two semantic systems that must not collide

Evolve the §3 palette; tune/extend for contrast and richness. Two color systems coexist on the
same surfaces and **must stay distinguishable from each other by FORM and PLACEMENT, not hue**:

- **Calendar status** (carried by the **day-cell fill / edge**): **Green** = planned + ingredients
  available; **Red** = unplanned, or missing ingredients / a cooking problem; **Blue** = a
  shopping day; **Yellow** = a shopping date that passed without shopping (a warning).
  ⚠️ This "yellow" must be a **distinct yellow**, not the brand amber `#F9A825` or the
  expiring-amber `#FFB300`, or it will read as those. Differentiate it deliberately.
- **Freshness** (carried by a **left edge-bar + dot + icon** on item rows, never a raw fill):
  fresh green / expiring amber / expired red / low-stock brown.
- **Categories (14)** own **only small chips/tints**; they must never compete with a status fill
  in the same component.
- **Sections (4)** tint their pantry shelf bands.

**Required deliverable:** one annotated **color-zoning** diagram proving calendar-status,
freshness, and categories coexist on Home and Calendar without confusion. Design **light and
dark as equals** (see §4.8 and §9 a11y for the dark-separation rules).

### 4.5 Imagery strategy

- **Treatment:** natural-light, matte, slightly desaturated, single-subject on linen/wood —
  like a modern cookbook plate, **not** glossy commercial stock.
- **Framing:** full-bleed bands on recipe heroes; inset rounded "plates" on cards; circular
  crops for ingredients.
- **No photo?** Category-tinted placeholder; for ingredients, a simple **two-tone botanical
  line-drawing** in the category hue as the fallback glyph.
- **Density rule:** on data-dense working surfaces, **suppress imagery** in favor of category
  tints — the app is a planning tool, not a photo gallery.
- Remember §2.5: express all of this in **CSS only**.

### 4.6 Surfaces, depth, texture

- Depth through **soft warm shadows and layered surfaces**, not hard borders everywhere.
- **Deliberate radius rhythm** (not one uniform radius on everything).
- **Linen/paper grain** is welcome — but at **≤4% opacity, on base/hero/chrome surfaces only,
  NEVER behind body text, data rows, the calendar grid, checklist rows, or pantry lists.**
  Working/data surfaces use flat solid fills (see §9).

### 4.7 Motion (documented per §2.4)

Signature transitions to specify: a checklist item ticking + the future list **decrementing**;
a day cell **changing status**; the serving slider **rescaling** the ingredient list live. Keep
them compositor-friendly. For each, give a **reduced-motion fallback that preserves meaning**
(see §9), not one that deletes it.

### 4.8 Dark mode has its own mood

Dark mode is not an inverted-luminance copy. It reads as **warm low-light — an evening,
candlelit kitchen / dark-walnut**, never cool charcoal slate. Keep the linen warmth in the dark
neutrals; let **amber do more of the accent work**. Pick one screen (Home or Recipe detail) to
prove dark mode adds **mood**, not just contrast.

### 4.9 Voice & microcopy (the words are part of the art direction)

Warm, plainspoken, quietly competent — a good cook talking to a friend. Earthy, concrete,
food-literate. No chirpy-assistant "Oops!", no corporate SaaS, no exclamation spam, no gamified
hype. Show **real strings** on every surface, not lorem/placeholders:

- Empty pantry → "Nothing on the shelves yet. Add your first staple." (not "No items.")
- Expiry nudge → "Spinach is on its last day — soup tonight?" (not "Item expiring soon.")
- Waste win → "Three things saved from the bin this week."
- Premium upsell → "Reuse a week you loved." (a capability, not a paywall)
- Shop Now → "Knock out next week early?"
- Error → "That didn't save — your shelf is unchanged."

Numbers get Fraunces; the warm one-liners get DM Sans. Annotate voice on at least Home, empty
states, expiry alerts, and the upsell.

### 4.10 Anti-template guardrails + acceptance test

Do **not** ship any of: default Material/stock card grids with no hierarchy; a centered-headline
+ gradient-blob + generic-CTA hero; unmodified component-library defaults; flat layouts with no
depth/motion; one uniform radius/shadow/padding everywhere; safe grey-on-white with one
decorative accent; dashboard-by-numbers (sidebar/cards/charts with no point of view).

**Baseline quality (every surface):** scale-contrast hierarchy, intentional spacing rhythm,
**semantic** (not decorative) color, designed interaction states. **Distinctiveness (the system
as a whole must visibly land at least 3 of 4):** editorial/grid-breaking composition;
atmosphere/texture; clarifying signature motion; data-viz-as-system. A submission where every
screen is a tidy vertical card list **fails** even if each screen checks the baseline boxes.

**Acceptance test:** screenshot any two non-adjacent screens with labels hidden. A stranger
should (a) tell they're the same app, (b) tell they're **different modules** at a glance (by
silhouette), and (c) correctly guess one is about food and one is about a schedule. If they fail
any of these, push the per-module fingerprints (§7) harder.

---

## 5. Connective tissue (what repeats on every screen)

To make it one product, apply to every hero: the **same app-bar/header + folio system**; the
**same bottom-nav** (§6 Navigation card); the **same freshness color+icon language** appearing
on Home, Pantry, Shopping **and** Calendar (the eye learns it once); the **same oversized-numeral
treatment**; the **same divider motif**. Show the **loop as visual continuity** — the *same meal
chip* appears on the Calendar, on Home's "tonight," and surfaces its ingredients into a Shopping
row — so cross-screen recognition tells the synchronized-loop story (§11).

---

## 6. Design system to deliver (Layer A)

**Foundations** (one card each, light+dark side-by-side): **Color** (brand; the
calendar-status set; freshness; the 14 category hues; the 4 section hues; neutrals/text; the
shipped semantic set success/info/warning/danger/focus/disabled/scrim; the `proposed`
dark-category set). **Typography** (full Fraunces + DM Sans ramp incl. Display-XL, with usage +
the signature treatments). **Spacing.** **Radius.** **Elevation.** **Motion** (durations +
curves, signature transitions named).

**Components** — evolve the existing, add the new:
- *Existing, elevate:* tags/category chips, freshness bar / status dot / expiry badge,
  thumbnail with category-tinted placeholder, cards + metadata rows, quantity stepper, section
  tabs, empty state, inline error alert, buttons, inputs, sheets/alerts.
- *New:* **Navigation** (bottom-nav — stable core tabs for everyone; see §10 note) + global
  chrome; **calendar day cell** (status fill/edge + status glyph + meal chips + shopping/
  leftover/waste icons + today/selected) and the **month grid**; **meal/dish chip** (recipe,
  time-tag, serving count, lifecycle state); **recipe card** in two variants — *private*
  (edit/delete) and *public* (price, save, like + comment counts); **serving-size scaler**;
  **shopping checklist row** (unchecked/bought/substituted/unavailable/skipped + optional
  per-member tick); **member avatar + role badge** + **invite-code** affordance; **Menu Set
  card** (with a 7-day mini-preview strip — visually un-confusable with a recipe card) and the
  **mini-calendar slot editor** (drag a recipe into a slot); **insight/metric tile**;
  **premium lock/upsell**; **notification row**.

**Distinctive component decisions (reject the clichés):**
- **Insight tile** — no number+sparkline cliché. Tie the metric to food: days-until-empty as a
  depleting pantry-jar level; money-saved as a warm growing stack; waste-this-week as a small
  almanac strip. Data-viz inherits the linen/serif world, not a charting library.
- **Premium lock** — never a grey scrim + padlock. Show the feature *working*, softly veiled,
  with one warm invitation — a closed cookbook you want to open.

---

## 7. Per-module visual fingerprint (each screen must NOT look like its neighbor)

Assign each module a distinct composition archetype — two screens side by side must be
distinguishable by **silhouette alone**:

- **Home / "Today"** = a warm editorial **briefing / kitchen journal** — an oversized Fraunces
  greeting + date, one hero focus, then a calm urgency-ranked stack. **NOT a dashboard, NOT a
  bento of stat tiles** (both banned). The layout reorders by what matters today.
- **Calendar** = an **ink-on-paper almanac/ledger**; the grid *is* the hero, chrome recedes.
- **Dish-in-Date** = a **vertical day-timeline**, dishes as a lifecycle filmstrip, not stacked cards.
- **Shopping** = a **tactile, receipt-like in-store checklist**, high-density single column,
  thumb-zone actions.
- **Pantry** = **pantry-shelf sectioning** with category-tinted shelf bands.
- **Recipe detail** = a **full-bleed cookbook spread**, photo-led, asymmetric.
- **Waste & insights** = a **data-editorial spread** where charts *are* the typography.
- **Menu Sets** = a **horizontal deck/carousel** of template cards — deliberately unlike every
  vertical list in the app.

---

## 8. Signature moments (design these as set-pieces; storyboard before → after)

1. **"Paying down the future."** An item is bought in-store → tick animates → the **same item
   strikes through on the next scheduled list with the count decrementing** ("Next week: 11 → 10
   items"). Design the explicit **payoff frame** — a small ledger/receipt beat that says "you
   just saved a future trip." This is the screenshot people share.
2. **"The almanac glance."** The month grid reads as a **status heat-map** — a stranger reads the
   household's week (good=green, problem=red, shopping=blue, missed=yellow) in **under two
   seconds, zero labels**. The grid's color+glyph rhythm is the signature, not any one cell.
3. **"Live rescale."** The serving slider rescales the ingredient list with numbers tumbling in
   real time — show the list at **2 servings and 6 servings** side by side.

Spend disproportionate craft here and on the P0 spine.

---

## 9. Accessibility & mobile (operationalized — not just principles)

**Color is never the only signal.** Mandate redundant, greyscale-surviving encodings:
- **Calendar status (in each day cell, consistent corner):** planned+available = filled dot +
  check; problem = outlined ring + alert-triangle; shopping day = cart/bag glyph; missed-shopping
  = dot + clock-with-slash. Deliver a **greyscale month-grid proof** where all four remain
  distinct.
- **Freshness:** fresh = full edge-bar, no badge; expiring = edge-bar + clock badge + day-count
  ("3d"); expired = edge-bar + alert-triangle + "Expired"; low-stock = dashed/striped edge-bar +
  down-arrow + "Low". **The day-count number is the primary signal; color reinforces.**
- **Per-member ticks:** never color-only — pair each member color with their **avatar/initial**;
  member colors must be CVD-distinguishable from each other and must **not** reuse the reserved
  status hues.

**Contrast caps (both themes):**
- Warm tertiary grey (`#8B9183` tier ≈ 2.4:1 on linen) is for **decorative/disabled/placeholder
  only — never body or actionable text.** All text ≥ 4.5:1 (≥ 3:1 for ≥24px/700).
- **Amber is never text on light surfaces;** when amber must read as text, use a darkened step
  (≈`#A35200`/warning tier) at 4.5:1.
- Status edge-bars, dots, focus rings, borders are **non-text UI → ≥ 3:1** against their adjacent
  surface (verify amber and brown bars specifically).
- **Focus ring meets 3:1 against every background it can land on** (use a dual-tone/offset
  outline so it survives green-on-green / amber-on-amber).

**Texture vs legibility:** grain/photography on empty/hero/chrome only; any text over imagery
needs a solid or ≥85% scrim restoring 4.5:1 (reaffirms §4.6).

**Touch & reach:** every interactive element ≥ 44×44pt hit area with ≥ 8pt spacing between
adjacent targets (governs calendar cells, checklist ticks, stepper buttons, chips, per-member
ticks). Primary actions (Shop Now, Quick-Add, Mark Cooked, checklist toggles) sit in the bottom
~⅓ **thumb zone** — never strand the only primary action top-right. Show a thumb-reach overlay on
Home, Calendar, Shopping.

**Bottom sheets & safe areas:** drag grabber; peek/half/full detents; ≥3:1 scrim; **resize above
the keyboard** (no covered inputs in the servings / mark-as-waste / invite / add-item forms); all
bottom-anchored CTAs/nav respect safe-area insets (home indicator, notch/Dynamic Island, Android
gesture bar). Show one sheet over the keyboard and one screen with insets visualized.

**Dynamic type:** respect OS font-scale to **≥200%**. Rows/chips/badges/sheets/buttons reflow,
don't truncate; clamp the Fraunces display at huge scales; the calendar grid degrades gracefully
(abbreviated chips → count badges) instead of clipping. Provide a **200%** variant of Home,
Calendar, and one list screen.

**Dense grid in dark mode / small sizes:** lifted hues must stay **mutually distinguishable AND
≥3:1** on the dark surface; tinted fills carry a slightly more saturated border for edge
definition. Prove the densest month-grid cell at ~360pt width in dark mode. Where density and
target size conflict, **target size wins**; design working surfaces to a **360pt small-phone
floor**.

**Reduced motion (preserve meaning):** future-list decrement → cross-fade the count + show a
non-animated delta ("−2"), no row-slide; day-cell status → instant swap + quick opacity fade;
serving rescale → numbers update on release via fade. No parallax/auto-texture. Cap remaining
durations ~150ms.

**RTL & i18n:** support RTL (mirror layout, nav, chevrons, swipe directions, edge-bar side,
calendar reading order; don't mirror food imagery or the time-flow direction that would invert
meaning). Locale-aware date / first-day-of-week / number / **unit** formatting throughout. Show
one core screen (Calendar or Shopping) in RTL.

**Semantics:** every status/freshness/member element exposes a **text accessibility label**
("June 12, planned, ingredients available" / "Milk, expires in 3 days"), since the visible
meaning is icon+color, not text. Define logical focus order for the grid and for sheets.

**Verification surface (deliverable):** (1) a contrast table for every text+surface and every
status/freshness pair in both themes with AA pass/fail; (2) CVD simulations (deuteranopia,
protanopia, tritanopia) of the month grid, freshness states, category swatches, member ticks;
(3) a greyscale render of the month grid and pantry list proving all states stay distinct.

---

## 10. Screens to design (Layer B — exact, closed set)

Design **exactly** the numbered screens below — no more, no fewer; each is one primary artboard
in light + dark, plus only its named load-bearing state(s). Generate in the §2.1 phase order.

### P0 — the spine (Phase 2)

1. **Home / "Today"** *(redesign the existing placeholder home).* The §7 editorial briefing.
   Load-bearing extra state: **two day variants** (a calm day vs. a busy/expiring day) to prove
   the layout adapts.
2. **Calendar — month view** (+ the **week** variant). The almanac glance (§8.2).
3. **Dish-in-Date — daily view.** The day's dishes with full lifecycle actions (view recipe,
   swap dish, change servings, mark cooked, schedule leftover, cancel). Show **multiple dish
   lifecycle states**.
4. **Shopping — in-store checklist.** Shared, with per-member ticks (premium) and the
   **substitution moment**; carries Signature 1 (§8.1).
5. **Pantry — sectioned home** *(elevate existing).* Food/Bulk/Non-Food/Leftovers; freshness
   bars, quantities, expiry badges, low-stock flags. Load-bearing state: **near-spoilage warning.**

### P1 — value & growth (Phase 3)

6. **Recipe detail ("Closer Look")** with the live serving-size scaler (§8.3). Reused by the
   calendar when picking a meal.
7. **Recipes home** — *My Recipes* / *Discover* tabs with both recipe-card variants; include the
   premium **budget + target-servings** search affordance. Load-bearing state: **empty My-Recipes.**
8. **Pantry item detail** *(elevate existing)* — hero, metadata, quantity stepper, mark-as-waste sheet.
9. **Shopping home** — upcoming scheduled shop dates, a prominent **Shop Now**, history; plus the
   **Shop Now setup** ("how many days ahead?") moment.
10. **Waste & insights** *(overhaul the bare waste log + add premium metrics)* — the
    data-editorial spread: waste-trend + money-saved viz as designed system elements.

### P2 — premium & system (Phase 4)

11. **Menu Sets home** — the horizontal template deck (duration, 7-day preview,
    apply/duplicate/edit).
12. **Menu Set editor** — the mini-calendar slot editor (drag recipes into day slots) + the
    **Apply-to-Calendar** dialog (start date, **modulo cycling** over a range, **Replace vs
    Fill-empty**).
13. **Onboarding** — sign in / sign up (OAuth + email) and **household setup** (create solo /
    create joint / join via invite code); warm, food-forward.
14. **Household & roles** — members list, role assignment (Admin/Cook/Shopper/Member), invite flow.
15. **Settings hub** + a tasteful **Premium upgrade** screen.
16. **Notification inbox** *(spec is light here — design a sensible center)* — expiry alerts,
    emergency-shopping pings, household activity.

**Navigation note:** the bottom-nav's **core tabs are stable across roles and tiers.** Conditional
capability (member management, Menu Sets, metrics, per-member ticks) appears **inside a module or
as a clearly-marked entry**, never as a tab that pops in and out. The plan/shop/track loop is the
same spine for everyone; premium/role differences live one level down.

---

## 11. The five things that MUST come through

If a stranger swiped your screens: (1) the **synchronized loop** feels connected, not five
separate apps; (2) the **calendar status language** reads instantly in a dense grid; (3)
**freshness/expiry** is one calm pervasive system across pantry, shopping, and home; (4)
**shopping is collaborative** and **buying ahead pays down the future**; (5) **waste reduction is
the reward** — the app makes wasting less feel good.

---

## 12. Definition of done

Structured **Foundations → Components → Screens**, each its own card, each light+dark, generated
in the §2.1 phases with a stop after each. Foundations consumed by `var(--…)` everywhere. Every
banned pattern (§4.10) avoided; the distinctiveness bar and acceptance test met; the §8 signature
moments and §9 verification surface delivered. **Better five unforgettable screens + a clean
system than 100 uniformly-polished ones** — spend craft on the signature moments and the P0
spine; the long tail (settings, notifications, secondary states) should be correct and on-system,
not where you chase memorability. Make it warm. Make it KitchenSync.
