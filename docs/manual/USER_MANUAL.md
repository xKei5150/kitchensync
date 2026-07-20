# KitchenSync — User Manual

KitchenSync is a household meal-planning app that ties your recipes, calendar,
shopping, and pantry into one loop: plan meals, generate shopping lists from
what you actually need, track what's on your shelves, cook, and keep leftovers
and waste under control.

This manual walks through every screen with a screenshot, explains what each one
does, and shows how the main tasks fit together.

> **About these screenshots.** They were captured on an iPhone 17 Pro simulator
> against a live development backend, using a sample premium household — **The
> Maple Street Kitchen** (Alex, Jamie, and Priya) — with a real week of meals
> planned, a stocked pantry, an active shopping list, and saved recipes. So the
> screens show the app genuinely in use, not empty placeholders.

---

## Contents

1. [Getting started](#1-getting-started)
2. [The bottom navigation](#2-the-bottom-navigation)
3. [Today — your home screen](#3-today--your-home-screen)
4. [Recipes](#4-recipes)
5. [Calendar & cooking](#5-calendar--cooking)
6. [Shopping](#6-shopping)
7. [Pantry](#7-pantry)
8. [Menu Sets (Premium)](#8-menu-sets-premium)
9. [Settings](#9-settings)
10. [Households, roles & sharing](#10-households-roles--sharing)
11. [Premium](#11-premium)
12. [Notifications](#12-notifications)
13. [The full loop — a worked example](#13-the-full-loop--a-worked-example)
14. [Fixes & review log](#14-fixes--review-log)

---

## 1. Getting started

When you first open KitchenSync you set up a **kitchen** — the space that holds
your recipes, meal plan, shopping lists, and pantry.

![Kitchen setup](screenshots/kitchen-setup.png)

You have three choices:

- **Just me** — a private, one-person kitchen. Free.
- **Create a household** *(Premium)* — a shared kitchen for up to 6 people with
  shared lists and per-member roles.
- **Join with a code** — if someone invited you, enter their invite code (for
  example `SAGE-417`) and tap **Join**.

Tap **Create and enter** to finish, or **Skip for now** to look around first.
Everything you do is scoped to your current kitchen, and you can switch kitchens
later from Settings.

---

## 2. The bottom navigation

Every core surface is one tap away from the bar pinned to the bottom of the
screen:

**Today · Recipes · Calendar · Shopping List · Pantry · Menu Sets · Settings**

Menu Sets appears only when your kitchen has Premium. Switching tabs preserves
each tab's place — scroll halfway down Pantry, jump to Today, come back, and
Pantry is exactly where you left it.

---

## 3. Today — your home screen

![Today dashboard](screenshots/today-dashboard.png)

Today is your daily summary for the active kitchen, pulled live from every other
module — nothing here is placeholder text:

- **Greeting and date** with a one-line status ("1 meal planned").
- **Today's meal card** — the dish you're cooking today with its serving size
  and a count of ingredients, plus a **Start cooking** button. (When a day is
  empty it shows a **Plan a meal** button instead.)
- **Use Soon** — pantry items approaching their use-by date (here, chicken with
  4 days left).
- **No upcoming shop / waste events this week** — quick counts from your
  shopping and waste history.

The header has quick access to **notifications** (bell), **settings** (gear),
and your **profile** (the coloured avatar).

---

## 4. Recipes

The Recipes tab is your cookbook, with two sub-tabs:

- **My Recipes** — recipes saved to your kitchen (private, plus your own public
  ones).
- **Discover** — public recipes shared by other users.

![Recipes — Discover](screenshots/recipes-discover.png)

Each card shows the recipe name, its **price per the selected serving size**
("£18.00 for 8"), the author, a save (bookmark) button, and live like/comment
counts. From here you can:

- **Search** recipes by name.
- Filter Discover results with the **budget** ("Under £500") and
  **target-servings** ("Serves 8") chips — a Premium search feature that ranks
  by price *per serving*, not just total price.
- Tap **+** (top right) to create a recipe, or the **magnifier** to search.
- Tap a card to open the recipe; tap the bookmark to save a public recipe as
  your own editable copy.

### Recipe detail

Tapping a recipe opens its detail view ("Closer Look").

![Recipe detail](screenshots/recipe-detail.png)

- A **servings slider** (1–12) rescales every ingredient quantity live.
- The **ingredient list** shows friendly names and quantities in sensible units
  (1 bunch, 400 g, 3 tbsp).
- Tags, a price estimate, and numbered **instructions** round out the page.
- **Start cooking** begins the cook flow; **Schedule** adds the recipe to a
  calendar day at a chosen serving size.

### Creating & editing recipes

Tap **+** on the Recipes tab to create a recipe. A recipe supports name, default
serving size, time tags (breakfast/lunch/…), recipe tags (cuisine/diet), a
description, ingredients (linked to the shared ingredient dictionary),
instructions, an optional dish image, location, a price estimate, an optional
YouTube link, an access type (private/public), and — for Premium authors —
monetization.

**Paste & Parse** *(Premium)* lets you paste several recipes as text at once;
the app splits them into separate recipes and saves each. Saving a public recipe
from Discover creates an **independent local copy** — editing your copy never
changes the original.

---

## 5. Calendar & cooking

![Calendar — month view](screenshots/calendar-month.png)

The Calendar is where you plan what to cook and when.

- **Month view is the default**; toggle to **Week** for a seven-day view.
- Today is ringed in green. Tap any day to open its **Day view**.
- The header actions (left to right) are: **shopping schedule** (cart), the
  **date-range defaults** editor (sliders), **apply a Menu Set** (grid+), and
  **previous / next** period.

### Reading the month at a glance

Each day is coloured and marked to show its status. In the screenshot above you
can read the whole week: a **green** run of planned dinners (19–23), a single
**red** problem day (24, where an ingredient is short), **blue** shopping days
(12, 25), a **leftover** dome on the 16th, and small **waste** glyphs on the 8th
and 14th. Days with nothing scheduled stay neutral — the calendar only turns red
when a planned meal genuinely needs attention.

| Marker | Meaning |
| --- | --- |
| 🟢 Planned | Meals are scheduled and ingredients are available |
| 🔴 Problem | A planned meal is missing ingredients (or flagged) |
| 🔵 Shop | A shopping date |
| 🟡 Missed | A shopping trip that was missed |
| Leftover | Leftovers are available that day |
| Spoilage | Something is predicted to spoil |
| Waste | A waste event was logged |

The day-summary card beneath the grid shows the selected day's meal and its
status ("MON 20 · PLANNED · One-pan chicken & rice").

### Date-range defaults

The sliders icon opens defaults you can apply across a date range: the meal mode
name, number of **meals per day**, number of **dishes per meal**, and the
default **serving size** used when scheduling. In a shared household these
defaults are Admin-only.

### Day view

![Day view](screenshots/day-view.png)

The Day view lists every dish planned for that date on a timeline. Each dish
shows its meal slot, serving size, price, and an "all in pantry" check when its
ingredients are in stock. From here you move it through its lifecycle:

1. **Mark cooked** (Scheduled → Done cooking)
2. **Servings** — change the serving size
3. **Merge 2 meals** *(Premium)* — combine slots so quantities scale together
4. **Swap** the recipe, **Cook next**, or **Cancel**
5. Afterwards, save **Leftovers** (with a safe-use date), then mark them
   consumed or wasted

If you try to cook and you're missing ingredients, the day is flagged as a
**problem** and you can create an **emergency shopping list** for whoever shops
in your household.

---

## 6. Shopping

![Shopping home](screenshots/shopping-home.png)

The Shopping tab has three sections that match how you actually shop:

- **Shop Now** — the big green card. Tap **Start a shop** to build a list for
  right now (from today through an end date you pick).
- **Upcoming** — lists generated from your scheduled shopping days (here, a
  "Shop Now · 19 Jul · 5 items" list).
- **History** — completed shops (tap **See all**).

### Weekly shopping schedule

![Shopping schedule](screenshots/shopping-schedule.png)

Pick the **day of the week** you usually shop, an **effective-from** date, and
toggle the schedule **Active**. KitchenSync then generates a shopping list for
each upcoming shop day from the meals you've planned. An active schedule can be
edited or **deactivated** here.

### How lists are built

For the meals in range, KitchenSync collects every recipe's ingredients, scales
them to the planned serving sizes, **normalizes compatible units** (e.g. kg → g
so they add up), **aggregates** the same ingredient across meals into one line,
and **subtracts what's already in your pantry**. Only what you're short of ends
up on the list.

### The checklist

![Shopping checklist](screenshots/shopping-list.png)

Opening a list shows its items as a checklist with a progress bar (here 2 of 5
bought). For each item you can mark it **bought** (it's checked off and struck
through), **substituted** (record what you actually bought — it updates the
pantry and that meal without changing the base recipe), **unavailable**, or
**skipped**, and you can edit quantities via the **⋯** menu.

**Done shopping** adds what you actually bought to your pantry, records purchase
history, and trims overlapping future lists so you don't buy the same thing
twice — without dropping anything you didn't manage to buy.

### Who can shop

In a shared household, **Admin** and **Shopper** can build and complete lists;
**Cook** and **Member** are read-only for shopping.

---

## 7. Pantry

![Pantry inventory](screenshots/pantry-inventory.png)

The Pantry ("On the shelves") tracks everything you have on hand.

- Filter by **All / Food / Bulk / Non-food** (and leftovers).
- **Search** your pantry.
- Each item card shows quantity, a freshness line ("Fresh · 23 days left"), a
  **Low** badge when stock is running down, the last purchase date, and a
  category tag (produce, dairy, …).
- The header actions are **insights** (chart), **bulk purchases** (cart), and
  the **waste log** (bin).
- **Add** puts a new item on the shelves.

### Adding an item

![Add to pantry](screenshots/pantry-add-item.png)

1. **Select an ingredient** from the shared dictionary.
2. Set the **quantity** with the stepper.
3. Choose a **unit**, grouped as **Formal Metric** (mg, g, kg, ml, l),
   **Formal Imperial** (oz, lb, fl oz, pt, qt, gal), **Cooking** (tsp, tbsp,
   cup), and **Informal** (piece, pinch, bunch, can, tin, jar, pack, bag, …).
4. Tap **Add to pantry**.

Pantry quantities also update automatically when you complete a shop (added) or
cook a meal (deducted).

### Waste log

![Waste log](screenshots/waste-log.png)

"The Ledger" records everything you've thrown away. Logging waste reduces the
item's pantry quantity, records the reason, and feeds the weekly/monthly counts
shown here (and on Today). The week strip (M–S) marks the days waste occurred.

### Pantry insights *(Premium)*

![Pantry insights](screenshots/pantry-insights.png)

A dashboard of your kitchen's health for the month:

- **Freshness right now** — how many items are Fresh / Soon / Expired / No date.
- **Section balance** — the mix of Food / Bulk / Non-food / Leftovers.
- **Waste — last 4 weeks** — a per-week bar chart with the recent events listed
  beneath.
- **Bulk timing** — how many bulk staples are due to run out (it learns each
  staple's purchase rhythm over time).

### Bulk purchases *(Premium)*

![Bulk purchases](screenshots/bulk-purchases.png)

"Bulk Foods to Purchase" predicts when staples will run out based on how fast
you use them, and lets you add recommendations straight to a shopping list.
Until it has enough purchase history to predict a run-out (or when everything is
well-stocked or dismissed) it shows the "Nothing due right now" state.

---

## 8. Menu Sets (Premium)

![Menu Sets list](screenshots/menu-sets-list.png)

Menu Sets ("A deck of weeks") are reusable meal-plan templates — save a week you
liked and apply it again later. Each saved set shows its name, length, meal
count, an estimated price, and a day-by-day preview ("Weeknight favourites ·
3 days · 4 meals · £16"). Per set you can **Apply to calendar**, **Duplicate**,
or (with the pencil) edit it. **Save this week as a set** turns a stretch of your
calendar into a new template.

### Menu Set editor

![Menu Set editor](screenshots/menu-set-editor.png)

- Give the set a **name** and a **length in days** (1–365).
- Each day (Mon, Tue, Wed …) previews its recipes at the top.
- **Tap a recipe** from the tray at the bottom to add it to Day 1.
- Use the per-day **EDIT DAYS** controls to **rename**, **move**, **duplicate**,
  or **clear** a day.
- **Save draft** keeps your work; **Apply to calendar** schedules the whole set
  across a date range you choose.

When you apply a set you pick a date range and a mode:

- **Fill** — only fills empty slots, keeping meals you already planned.
- **Replace** — clears existing meals in range first, then applies the template.

Generated meals use your active Calendar default serving size, refresh your
shopping demand, and remain **independently editable** afterward — later edits
to the template don't rewrite meals you already scheduled.

---

## 9. Settings

![Settings](screenshots/settings.png)

Settings gathers everything about you and your kitchen:

- **Profile** — your name, email, and role, with a pencil to edit your display
  name.
- **Premium banner** — shows **"Premium active"** when your kitchen already has
  Premium (or "Try Premium" to start a trial otherwise).
- **Household & roles** — manage who's in your kitchen.
- **Switch kitchen** — jump to another kitchen you belong to.
- **Notifications** — notification preferences.
- **Appearance** — light / dark / **Auto**.
- **Units & locale** — measurement system and currency (Metric · £ here).
- **Sign out** — ends your session and returns you to sign-in.

---

## 10. Households, roles & sharing

![Household & roles](screenshots/household-roles.png)

The Household screen ("Who's in the kitchen") lists everyone in the current
kitchen with their role and shows how full it is ("3 OF 6"). In the sample
kitchen: **Alex** (Admin), **Jamie** (Cook), and **Priya** (Shopper).

**Roles** determine what each person can do:

| Role | Can do |
| --- | --- |
| **Admin** | Everything: invite/remove members, assign roles, transfer Admin, manage the plan and settings |
| **Cook** | Author recipes, plan the calendar, build menu sets |
| **Shopper** | Build and complete shopping lists |
| **Member** | View everything; social actions (likes/comments); no edits |

Only an **Admin** can invite or remove members and change roles, and promoting
someone to Admin requires that they have Premium. You can't demote or remove
yourself if it would leave the kitchen without an Admin. **Switch kitchen** (from
Settings) reopens the kitchen picker so you can move between kitchens you belong
to; your selection is remembered.

---

## 11. Premium

![Premium](screenshots/premium.png)

KitchenSync Premium unlocks:

- **Menu Sets** — reusable meal-plan templates.
- **Pantry intelligence** — days-until-empty predictions and waste analytics.
- **Joint households** — up to 6 people with per-member roles.
- **Paste & Parse** and **budget recipe search**.

Pick **Annual** (£29, save 40%) or **Monthly** (£3.99) and tap **Start 7-day
free trial**. You can preview pantry insights before committing.

---

## 12. Notifications

Two related surfaces:

**Notification inbox** (bell on Today) — messages that need your attention, such
as an emergency shopping request or household activity.

![Notification inbox](screenshots/notification-inbox.png)

**Notification preferences** (Settings → Notifications, or the sliders in the
inbox) — toggle each category on or off:

![Notification preferences](screenshots/notification-preferences.png)

- **Emergency shopping** — missing ingredients that need a shopper.
- **Pantry expiry** — food nearing its safe-use date.
- **Bulk reminders** — predicted staple replenishments.
- **Household activity** — shopping and cooking updates from members.

Notifications are scoped to your household and only visible to their intended
recipient. Emergency shopping requests go to whoever shops in the household (and
honour each person's opt-out).

---

## 13. The full loop — a worked example

KitchenSync is designed around one continuous loop. A typical week:

1. **Find or write a recipe** in Recipes.
2. **Schedule it** from the recipe detail onto a calendar day at the serving
   size you need.
3. **Generate a shopping list** — scheduled or Shop Now — which scales the
   recipe, subtracts your pantry, and lists only what you're short of.
4. **Shop** using the checklist; mark items bought or substituted.
5. **Done shopping** — purchases flow into your pantry and future lists shrink.
6. **Cook** from the Day view; ingredients are deducted from the pantry.
7. **Save leftovers**, then later **consume** or **waste** them.
8. KitchenSync **suggests follow-up lists** to recover misses, spoilage, and new
   demand — and the loop continues.

---

## 14. Fixes & review log

An earlier draft of this manual flagged several rough edges. This section
records what was fixed and what remains.

### Fixed

| # | Where | Was | Now |
| --- | --- | --- | --- |
| R1 | Calendar (month) | **Every** day was shaded red "problem", even with nothing planned — alarming and meaningless. | Unplanned days are neutral; red is reserved for a planned meal that's genuinely missing ingredients (see the single red 24th in the screenshot). |
| R2 | Menu Set editor | A debug-looking "Remove first recipe" button; a "Drag from your recipes" tray with no usable drop target on touch. | The tray reads "Tap a recipe to add to Day 1" and **every** chip is tappable; per-day rename/move/duplicate/clear controls replace the debug button. |
| R3 | Settings | The "Try Premium" banner showed even when the kitchen already had Premium. | The banner reads **"Premium active — …unlocked"** with a medal icon for Premium kitchens. |
| R4 | Premium lock card | The premium veil overflowed its card by ~41 px. | The card now guarantees enough height for the veil; no overflow. |
| R6 | Recipes (Discover & detail) | Cards showed a **duplicated** like/comment row, and the byline showed a raw user id. | One social row (in the card); the byline reads **"You"** for your own recipes (or "A KitchenSync cook" for others). |
| R7 | Recipe detail | Ingredients displayed as raw ids ("baby-spinach"). | Ingredients resolve to friendly dictionary names ("baby spinach", "crushed tomatoes"). |
| R8 | Pantry insights | The "Waste · last 4 weeks" chart overflowed by ~26 px once bars were non-zero. | The chart sizes to its content; bars and labels render cleanly. |

All fixes are covered by the automated test suite (850 tests passing) and
verified live on the iOS simulator; the screenshots in this manual are from the
fixed build.

### Still open

| # | Where | Note |
| --- | --- | --- |
| R5 | Onboarding sign-in | Google/Apple sign-in shows "Not configured" until real OAuth provider credentials are supplied. This is an **external-credential dependency** — the Firebase Auth emulator cannot perform real third-party OAuth, so it can't be completed or screenshotted in this environment. The code already uses the genuine Firebase OAuth API with no anonymous fallback. |

Minor, non-blocking polish noted for later: the Premium **screen** itself still
offers "Start 7-day free trial" even to a kitchen that already has Premium (the
Settings banner is correct; only the full screen's CTA is unconditional).

---

*Manual generated from a live walkthrough on the iPhone 17 Pro simulator against
the development Firebase backend, using the sample premium household "The Maple
Street Kitchen". Screenshots live in `docs/manual/screenshots/`.*


