# KitchenSync Design System

## 1. Atmosphere & Identity

KitchenSync is a quiet kitchen command center: warm, scannable, and practical without feeling clinical. The signature is pantry-native warmth: linen surfaces, herb-green actions, amber highlights, and compact controls that make repeated household tasks fast.

## 2. Color

### Palette

| Role | Token | Light | Dark | Usage |
|------|-------|-------|------|-------|
| Brand primary | `KsTokens.brandPrimary` | `#2E7D32` | `#4CAF50` via `KsColors.brandPrimary` | Primary action, selected state, focus |
| Brand accent | `KsTokens.brandAccent` | `#F9A825` | `#F9A825` | Sparse highlights and premium/proposed accents |
| Surface base | `KsTokens.surfaceBase` | `#FAFAF7` | `#1E1F1B` via theme | Scaffold background |
| Surface raised | `KsTokens.surfaceRaised` | `#FFFFFF` | `#272822` via `KsColors.surfaceRaised` | Cards, fields, chips, dialogs |
| Surface sunken | `KsTokens.surfaceSunken` | `#F2EFE7` | `#232420` | Preview wells and grouped editor panels |
| Border | `KsTokens.border` | `#E8E5DD` | `#3D3F37` via theme | Hairlines and card outlines |
| Border strong | `KsTokens.borderStrong` | `#D7D2C8` | `#4D4F47` via theme | Inputs and unselected chips |
| Text primary | `KsTokens.textPrimary` | `#1A1C16` | `#E8E5DD` via theme | Main labels |
| Text secondary | `KsTokens.textSecondary` | `#5F6651` | `#B5BBAE` via theme | Supporting text |
| Text tertiary | `KsTokens.textTertiary` | `#8B9183` | theme lifted | Hints, field labels |
| Error | `KsTokens.expired` | `#C62828` | theme danger | Validation and destructive state |

### Rules

- Use `context.ksColors` or `KsTokens`; do not introduce new colors in component code.
- Selection is never color-only: selected chips also show a check glyph through `KsSelectChip`.
- Error states pair danger tint with real validation text.

## 3. Typography

### Scale

| Level | Token | Usage |
|-------|-------|-------|
| Display | `KsTokens.displaySmall` and larger | Focal numerals and hero values only |
| Headline | `KsTokens.headlineLarge`, `headlineMedium` | Screen and card headings |
| Title | `KsTokens.titleLarge`, `titleMedium`, `titleSmall` | Compact surface headings |
| Body | `KsTokens.bodyLarge`, `bodyMedium`, `bodySmall` | Form input and helper text |
| Label | `KsTokens.labelLarge`, `labelMedium`, `labelSmall` | Buttons, chips, metadata, field labels |

### Font Stack

- Display: Fraunces through `KsTokens`.
- UI/body: DM Sans through `KsTokens`.

### Rules

- Form surfaces use uppercase 10px field labels from `KsFieldLabel`.
- Chip labels use compact `labelMedium` with zero letter spacing.

## 4. Spacing & Layout

### Base Unit

KitchenSync uses the existing `KsTokens` spacing scale. Most form and picker spacing uses `space8`, `space12`, `space16`, `space20`, and `space24`.

### Rules

- Group form rows with 16px vertical rhythm.
- Chips use 8px row and run gaps.
- Keep fixed-format controls stable with minimum heights: chips at 44px, editor actions around 48px, grouped panels full-width.

## 5. Components

### Select Chip

- **Structure**: `KsSelectChip` wrapped in `Wrap`.
- **Variants**: selected, unselected, disabled through null `onTap`, optional dot color.
- **Spacing**: 12px horizontal, 10px vertical, 8px radius, 44px minimum height.
- **States**: selected has tonal brand fill, stronger border, and check glyph; unselected uses raised fill and strong border.
- **Accessibility**: semantic button with selected state.
- **Motion**: Material ripple only.

### Form Field

- **Structure**: `KsFieldLabel` above a Material text field or shared field.
- **Variants**: default, focused, error, disabled.
- **Spacing**: 12px field padding, 10-12px radius.
- **States**: focused border is 2px brand; error border/text uses danger.
- **Accessibility**: real text field with label, helper/error text, and keyboard focus.
- **Motion**: focus/ripple only.

### Unit Picker

- **Structure**: grouped sections with field labels and chip wraps; optional local-unit editor panel.
- **Variants**: select-only, create-enabled.
- **Spacing**: 16px section rhythm, 8px chip gaps, raised/sunken surfaces from existing tokens.
- **States**: selected chip, unselected chip, disabled chip, empty local section, validation error, slug preview.
- **Accessibility**: real buttons for unit choices and add action; real text field for local labels; validation text announced with `KsFieldError`.
- **Motion**: no decorative animation.
- **Ownership**: `unit_picker.dart` owns the controlled API, selected-unit/editor state, validation, registry grouping, and callbacks. `unit_picker_sections.dart` owns only the grouped chip section and add-local-unit editor render surfaces; it does not store local units or make selection decisions.
- **Controlled local units**: local-unit chips render from parent-provided `localUnitDefinitions`. Adding a local unit emits a `UnitDefinition` and selects its `UnitId`; the parent appends the definition and rebuilds the picker.

### Dialog / Sheet Surface

- **Structure**: Material dialog/sheet or raised card with title, body, and bottom actions.
- **Variants**: default, validation error.
- **Spacing**: 20px body padding, 12px action gap.
- **States**: buttons use existing `FilledButton`/`OutlinedButton` themes.
- **Accessibility**: labeled controls and focusable actions.
- **Motion**: platform Material transition only.

## 6. Motion & Interaction

Use existing `KsTokens.durationFast`, `durationMedium`, and `curveStandard` only when a state transition needs animation. This task's picker does not add new motion beyond Material focus/ripple behavior.

## 7. Depth & Surface

Strategy: mixed tonal-shift plus hairline borders. Form/editor panels use raised white/dark-walnut fills with `KsTokens.border`; preview/editor wells use `surfaceSunken`. No new shadow recipe is introduced for the unit picker.

Accepted debt: this document is an extraction artifact for task 9 and intentionally records the tokens/components needed for the unit picker. Broader screen-by-screen visual QA and full component showcase coverage remain outside this reusable component task.
