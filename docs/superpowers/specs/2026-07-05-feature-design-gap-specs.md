# KitchenSync Feature Design Gap Specs

Date: 2026-07-05

Status: research draft, observed in current worktree

Source design: `Feature Design.docx.md`

## Source Constraints

- The original `Feature Design.docx` file is not present in the repository. The audit uses `Feature Design.docx.md`, which is the only matching design source found by `find . -iname '*Feature*Design*.docx' -o -iname '*.docx' -o -iname '*Feature*Design*'`.
- The working tree was already dirty before this audit. Classifications below describe the current on-disk source, not a clean baseline.
- Do not treat file presence alone as completion. Each gap cites design evidence and implementation evidence, then uses a conservative status.
- Status taxonomy:
  - **Implemented**: code and tests or directly traced behavior support the design behavior.
  - **Partial**: the feature exists, but user-facing flow, persistence, permissions, or integration is incomplete.
  - **Scaffolded**: representative/sample UI or placeholder wiring exists, but the real behavior is not complete.
  - **Missing**: no concrete implementation was found in the audited source.
  - **Covered by existing spec**: already specified elsewhere; link rather than duplicate when planning implementation.
  - **Ambiguous**: current dirty worktree or source constraints prevent a confident classification.
- Confidence taxonomy:
  - **High**: direct design line plus direct source line show the gap.
  - **Medium**: direct design line plus implementation evidence show likely incompleteness, but runtime behavior was not driven.
  - **Low**: search did not find enough evidence, or dirty worktree/source extraction limits confidence.

## Executive Summary

KitchenSync is no longer just a pantry prototype. The current branch contains substantial modules for household context, recipes, calendar, shopping, pantry, ingredient dictionary, menu sets, premium gating, Firestore rules, and several widget/integration tests.

The main incomplete area is the product loop described by the Feature Design: Recipe -> Calendar -> Shopping -> Pantry -> Cooking/Leftovers/Waste -> Suggestions. Individual engines exist, but several user-facing surfaces still use sample data, fixed IDs, empty handlers, or incomplete persistence bridges. The highest-value next work is to make the loop real through parameterized routes, persisted records, and role/premium enforcement at the interaction points.

## Gap Inventory

| ID | Module | Status | Confidence | Design Requirement | Current Evidence | Gap |
| --- | --- | --- | --- | --- | --- | --- |
| FD-GEN-01 | General / Auth | Partial | High | Login/register with OAuth and email/password, then household selection. `Feature Design.docx.md:230`, `Feature Design.docx.md:242`, `Feature Design.docx.md:256`, `Feature Design.docx.md:266` | Email sign-in/register exists, while Apple/Google buttons use anonymous sign-in until provider credentials are configured. `lib/features/onboarding/presentation/screens/sign_in_screen.dart:10`, `lib/features/onboarding/presentation/screens/sign_in_screen.dart:33`, `lib/features/onboarding/presentation/screens/sign_in_screen.dart:50` | Replace anonymous OAuth placeholder with real provider auth and account-linking behavior. |
| FD-GEN-02 | General / Household | Partial | High | Free/premium household rules, active household context, role permissions across modules. `Feature Design.docx.md:274`, `Feature Design.docx.md:280`, `Feature Design.docx.md:338`, `Feature Design.docx.md:466`, `Feature Design.docx.md:550` | Household policy and active context exist. `lib/features/household/domain/services/household_policy.dart:11`, `lib/core/session/active_household_id_provider.dart:69`, `lib/app/router.dart:85` | Debug skip/preview fallback and partial UI permissions remain; enforce real membership/role/premium checks consistently in every module action, not only routes. |
| FD-GEN-03 | Settings | Partial | High | Profile, premium subscription, household management, notifications, app preferences, logout. `Feature Design.docx.md:590` | Settings rows exist for household, notifications, appearance, locale, premium, and a sign-out navigation. `lib/features/settings/presentation/screens/settings_screen.dart:64`, `lib/features/settings/presentation/screens/premium_screen.dart:191` | Profile is static and sign-out only routes to onboarding; add real auth sign-out, profile editing, and subscription lifecycle beyond trial flag writes. |
| FD-REC-01 | Recipes | Partial | Medium | Manual recipe creation with complete fields and dictionary linking. `Feature Design.docx.md:699`, `Feature Design.docx.md:705`, `Feature Design.docx.md:753` | Recipe model/repository exist; add recipe sheet imports drafts through parser. `lib/features/recipes/domain/entities/recipe_models.dart:7`, `lib/features/recipes/presentation/screens/recipes_screen.dart:29`, `lib/features/recipes/presentation/providers/recipe_repository_providers.dart` | No full manual recipe editor screen was found; ingredient auto-link/create behavior needs explicit UI and dictionary write path. |
| FD-REC-02 | Recipes | Implemented / Partial | High | Premium paste-and-parse accepts multiple recipes and creates entries. `Feature Design.docx.md:755`, `Feature Design.docx.md:759`, `Feature Design.docx.md:819` | Parser supports START/END blocks and validates fields. `lib/features/recipes/domain/services/recipe_import_parser.dart:16`, `lib/features/recipes/domain/services/recipe_import_parser.dart:22` | Premium gating and in-product parse template/validation UX need completion; current parsing is a service plus import sheet, not a polished premium workflow. |
| FD-REC-03 | Recipes | Partial | Medium | My Recipes / Discover, public save as local copy, public social actions, premium budget + servings search. `Feature Design.docx.md:655`, `Feature Design.docx.md:881`, `Feature Design.docx.md:935` | Tabs, public search, price normalization, and local copy persistence exist. `lib/features/recipes/presentation/screens/recipes_screen.dart:90`, `lib/features/recipes/data/datasources/recipe_remote_data_source.dart:53`, `lib/features/recipes/data/datasources/recipe_remote_data_source.dart:76` | Search icon is presentational, social like/comment behavior was not found, and premium search gating needs full household-premium enforcement. |
| FD-REC-04 | Recipes -> Calendar | Scaffolded | High | Recipe detail can schedule or start cooking through Calendar. `Feature Design.docx.md:897`, `Feature Design.docx.md:933` | Explorer found empty handlers on Recipe Detail's `Start cooking` and `Schedule` actions. `lib/features/recipes/presentation/screens/recipe_detail_screen.dart:199` | Add schedule/start-cooking actions that create or navigate to concrete `MealScheduleEntry` flows. |
| FD-CAL-01 | Calendar | Partial | High | Month/week/day views, date tap opens all dishes for that date. `Feature Design.docx.md:1140`, `Feature Design.docx.md:1160`, `Feature Design.docx.md:1333` | Month grid watches persisted meals, but day view has fixed demo title/sample dinner. `lib/features/calendar/presentation/screens/calendar_screen.dart:55`, `lib/features/today/presentation/screens/day_view_screen.dart:20`, `lib/features/today/presentation/screens/day_view_screen.dart:42` | Parameterize day route by selected date and render real meals from `activeCalendarMealsProvider`. Add week view or explicitly defer it. |
| FD-CAL-02 | Calendar | Partial | Medium | Calendar defaults, meal modes, meals/day, dishes/meal. `Feature Design.docx.md:1204`, `Feature Design.docx.md:1238`, `Feature Design.docx.md:1489` | Entities and repository for day settings exist. `lib/features/calendar/domain/entities/meal_schedule.dart:105`, `lib/features/calendar/data/datasources/calendar_remote_data_source.dart:48` | No user-facing calendar settings/defaults editor was found. Build UI to create/update `CalendarDaySettings` and apply defaults when scheduling. |
| FD-CAL-03 | Calendar / Cooking | Implemented / Partial | High | Done cooking deducts pantry, missing ingredients trigger problem/emergency shopping, leftovers can be saved/scheduled. `Feature Design.docx.md:1283`, `Feature Design.docx.md:1543`, `Feature Design.docx.md:1577` | Cooking lifecycle controller deducts pantry, marks problem on missing ingredients, saves/schedules/consumes leftovers. `lib/features/calendar/presentation/providers/calendar_repository_providers.dart:81`, `lib/features/calendar/presentation/providers/calendar_repository_providers.dart:112`, `lib/features/calendar/presentation/providers/calendar_repository_providers.dart:139`, `lib/features/calendar/presentation/providers/calendar_repository_providers.dart:266` | Wire the controller to real parameterized day UI and notifications; current screen invokes it through hardcoded sample meal IDs. |
| FD-CAL-04 | Calendar | Partial | Medium | Premium meal merging controlled by premium flag. `Feature Design.docx.md:1389` | Merge logic exists in controller. `lib/features/calendar/presentation/providers/calendar_repository_providers.dart:191` | Premium/role gating for merge action needs enforcement in UI and controller/service boundary. |
| FD-SHOP-01 | Shopping | Partial | High | Shopping home shows scheduled lists, Shop Now, and history. `Feature Design.docx.md:1647`, `Feature Design.docx.md:1663` | Shop Now flow builds and persists a generated list, but upcoming/history contain hardcoded rows. `lib/features/shopping/presentation/screens/shopping_screen.dart:20`, `lib/features/shopping/presentation/screens/shopping_screen.dart:28`, `lib/features/shopping/presentation/screens/shopping_screen.dart:71` | Replace hardcoded upcoming/history with `activeShoppingListsProvider` and persisted completed-list history. |
| FD-SHOP-02 | Shopping | Implemented / Partial | High | Generate deficits from calendar plans minus pantry stock. `Feature Design.docx.md:1765`, `Feature Design.docx.md:3227` | `ShoppingEngine.generateList` scales recipe quantities by scheduled serving size and subtracts pantry stock. `lib/features/shopping/domain/services/shopping_engine.dart:10`, `lib/features/shopping/domain/services/shopping_engine.dart:57`, `lib/features/shopping/domain/services/shopping_engine.dart:81` | Add unit normalization via dictionary; current aggregation is by exact `(ingredientId, unit)`. |
| FD-SHOP-03 | Shopping -> Pantry | Partial | High | Done Shopping applies purchases, adjusts future scheduled lists, preserves unbought items. `Feature Design.docx.md:1815`, `Feature Design.docx.md:1846`, `Feature Design.docx.md:1860`, `Feature Design.docx.md:3255` | Completion writes pantry/purchase history and calls scheduled-list adjustment. `lib/features/shopping/presentation/providers/shopping_repository_providers.dart:316`, `lib/features/shopping/data/datasources/shopping_remote_data_source.dart:82` | Persisted UI only toggles bought/unchecked; expose unavailable/substituted statuses and verify partial adjustment behavior end-to-end from real list records. |
| FD-SHOP-04 | Shopping Substitutions | Partial | High | Substitutions add actual ingredient to pantry and persist per-meal override without changing base recipe. `Feature Design.docx.md:1917` | Data model includes substitute fields and completion persists overrides when fields are set. `lib/features/shopping/domain/entities/shopping_plan.dart:89`, `lib/features/shopping/presentation/providers/shopping_repository_providers.dart:390` | Add substitution picker/editor UI and ensure checklist rows can set substitute ingredient, quantity, and unit. |
| FD-SHOP-05 | Shopping Suggestions | Partial | Medium | Suggested/emergency lists recover missed shopping and missing ingredients. `Feature Design.docx.md:1689`, `Feature Design.docx.md:1971` | Adaptive list controller exists; Day View creates emergency list on missing ingredients. `lib/features/shopping/presentation/providers/shopping_repository_providers.dart:120`, `lib/features/today/presentation/screens/day_view_screen.dart:74` | Add visible suggested-list queue/accept/ignore/delete flow and notification hooks for shoppers. |
| FD-PANTRY-01 | Pantry / Dictionary | Implemented | Medium | Canonical dictionary, ingredient picker, custom ingredients, pantry sections. `Feature Design.docx.md:2179`, `Feature Design.docx.md:2226`, `Feature Design.docx.md:2494` | Dictionary and pantry entities, repositories, UI, and integration tests exist. `lib/features/ingredient_dictionary/domain/entities/ingredient.dart:9`, `lib/features/ingredient_dictionary/presentation/screens/ingredient_picker_screen.dart:15`, `lib/features/pantry/presentation/screens/pantry_home_screen.dart:19`, `integration_test/seed_and_search_test.dart`, `integration_test/add_pantry_item_test.dart` | Continue tightening known repository limitations before relying on it for all modules. |
| FD-PANTRY-02 | Ingredient Dictionary | Partial | High | Any new ingredient name from recipes or shopping maps to or creates dictionary entry. `Feature Design.docx.md:2220`, `Feature Design.docx.md:3165` | Custom creation exists; repository comments note global-only lookup by ID and pagination TODO. `lib/features/ingredient_dictionary/presentation/screens/create_custom_ingredient_screen.dart`, `lib/features/ingredient_dictionary/data/repositories/ingredient_repository_impl.dart:10`, `lib/features/ingredient_dictionary/data/repositories/ingredient_repository_impl.dart:21`, `lib/features/ingredient_dictionary/data/repositories/ingredient_repository_impl.dart:81` | Add household-custom `getById` fallback, pagination, and recipe/shopping auto-create/link flows. |
| FD-PANTRY-03 | Pantry / Waste | Implemented / Partial | High | Waste reduces inventory and logs waste event, with calendar indicators and metrics. `Feature Design.docx.md:2338`, `Feature Design.docx.md:2376`, `Feature Design.docx.md:3339` | Waste use case and insights charts exist. `lib/features/pantry/domain/usecases/mark_as_waste.dart:35`, `lib/features/pantry/data/datasources/pantry_remote_data_source.dart:85`, `lib/features/pantry/presentation/screens/insights_screen.dart:45` | Calendar spoilage/waste indicators are limited; connect waste events to date labels and suggestions. |
| FD-PANTRY-04 | Pantry / Bulk | Partial | Medium | Bulk/non-food predictions and automated bulk list suggestions. `Feature Design.docx.md:2380`, `Feature Design.docx.md:2538`, `Feature Design.docx.md:2610` | Bulk prediction engine and insights UI exist. `lib/features/pantry/domain/services/bulk_prediction_engine.dart:32`, `lib/features/pantry/presentation/screens/insights_screen.dart:123`, `lib/features/shopping/presentation/providers/shopping_repository_providers.dart:250` | Add one-tap "add to next shopping list" UI and clear premium gating/persistence around bulk recommendations. |
| FD-MENU-01 | Menu Sets | Partial | High | Menu set list, create, create-from-past, view/edit/apply/duplicate/delete. `Feature Design.docx.md:2646`, `Feature Design.docx.md:2670`, `Feature Design.docx.md:2774`, `Feature Design.docx.md:2844`, `Feature Design.docx.md:2866` | Entities, repository, application engine, editor controller, and create-from-calendar exist. `lib/features/menu_sets/domain/entities/menu_set.dart:3`, `lib/features/menu_sets/domain/services/menu_set_application_engine.dart:27`, `lib/features/menu_sets/presentation/providers/menu_set_repository_providers.dart:84`, `lib/features/menu_sets/presentation/providers/menu_set_repository_providers.dart:105` | Home carousel uses hardcoded sample sets, and apply/duplicate route to editor rather than operating on selected persisted set. `lib/features/menu_sets/presentation/screens/menu_sets_screen.dart:26`, `lib/features/menu_sets/presentation/screens/menu_sets_screen.dart:163` |
| FD-MENU-02 | Menu Sets -> Calendar/Shopping | Partial | Medium | Applying menu sets creates many `MealScheduleEntry` records and scheduled shopping list effects. `Feature Design.docx.md:2866`, `Feature Design.docx.md:2914`, `Feature Design.docx.md:3035`, `Feature Design.docx.md:3353` | Application engine and persistence controller exist. `lib/features/menu_sets/domain/services/menu_set_application_engine.dart:99`, `lib/features/menu_sets/presentation/providers/menu_set_repository_providers.dart:240` | Connect persisted menu set selection to apply UI, include generated scheduled shopping list evidence, and gate create/apply by premium + role. |
| FD-SYS-01 | System Loop | Partial | High | Continuous loop across recipes, dictionary, calendar, shopping, pantry, leftovers, waste, menu recommendations. `Feature Design.docx.md:3115`, `Feature Design.docx.md:3412`, `Feature Design.docx.md:3514` | Individual modules and route guards exist. `lib/app/router.dart:78`, `firestore.rules:119`, `firestore.rules:180`, `firestore.rules:194`, `firestore.rules:208` | Missing a real end-to-end happy path from recipe creation/scheduling through shopping completion, cooking, leftovers, waste, and suggested list recovery. |
| FD-SYS-02 | Offline / Conflict / Notifications | Scaffolded | Medium | Household notifications and multi-user operational states. `Feature Design.docx.md:332`, `Feature Design.docx.md:1577`, `Feature Design.docx.md:1943` | Notifications screen and dev system-state demos exist; explorer notes sync conflict/offline queue are presentational. `lib/features/notifications/presentation/screens/notifications_screen.dart`, `lib/features/dev_tools/system_states_screen.dart:5` | Implement real notification triggers, offline queue/conflict UX, and multi-user shopping attribution if required for launch. |

## Implementation Specs For Later Work

### Spec 1: Replace Auth Placeholders With Real Account Onboarding

**Goal:** Users can register/sign in with email, Google, or Apple, then create/select/join a household without debug fallback.

**Scope:**
- `lib/features/onboarding/presentation/screens/sign_in_screen.dart`
- `lib/features/onboarding/presentation/screens/household_setup_screen.dart`
- `lib/core/session/active_household_id_provider.dart`
- `firestore.rules`
- onboarding and household tests

**Acceptance Criteria:**
- Apple and Google buttons use real Firebase OAuth provider credentials or are hidden behind feature flags until configured.
- Anonymous users can be linked to email/OAuth accounts without losing existing household data.
- Creating a solo household for a free user and a joint household for a premium user follows `HouseholdPolicy`.
- Joining by invite writes membership data that active household context can read immediately.
- Sign out calls Firebase Auth sign-out and clears active household/debug skip state.

**Verification:**
- Unit tests for `HouseholdPolicy` edge cases.
- Widget tests for email, OAuth disabled/configured states, create solo, create joint, join invite.
- Firestore rules tests for user, household, invite, and member writes.
- Emulator integration: register -> create household -> reload app -> active household routes work.

### Spec 2: Parameterize Calendar Day Flow And Recipe Scheduling

**Implementation Status:** Done on 2026-07-05. Do not include this calendar scheduling spine in future gap-plan implementation batches except for regression fixes or explicitly new follow-up scope such as week view or calendar settings/defaults editor polish.

**Goal:** Recipe detail and calendar month/day screens operate on real selected recipes, dates, and persisted `MealScheduleEntry` records.

**Scope:**
- `lib/app/router.dart`
- `lib/features/recipes/presentation/screens/recipe_detail_screen.dart`
- `lib/features/calendar/presentation/screens/calendar_screen.dart`
- `lib/features/today/presentation/screens/day_view_screen.dart`
- `lib/features/calendar/presentation/providers/calendar_repository_providers.dart`

**Acceptance Criteria:**
- Recipe detail "Schedule" opens a date/meal-slot flow and persists a `MealScheduleEntry` with explicit serving size.
- Calendar date tap routes to `/day/:date` or equivalent and shows every meal for that date from Firestore.
- Day view action buttons operate on the selected meal, not `_sampleDinner`.
- Calendar defaults can be selected from active `CalendarDaySettings`.
- Missing ingredients mark the meal/date as problem and expose emergency-list action.

**Verification:**
- Widget test: schedule public/local recipe for a date, then calendar/day screens show it.
- Controller test: scheduling with calendar default stores explicit serving size.
- Integration test: recipe -> schedule -> day view -> change serving -> mark cooked with enough pantry.

### Spec 3: Finish Manual Recipe Creation And Dictionary Linking

**Goal:** Users can manually create/edit recipes with all required fields and dictionary-linked ingredients.

**Scope:**
- New recipe editor screen or modal under `lib/features/recipes/presentation/`
- `RecipeRepository`
- `IngredientRepository`
- recipe parser/import providers

**Acceptance Criteria:**
- Manual editor captures name, default serving, time tags, recipe tags, description, ingredients, instructions, optional image, location, price, YouTube URL, visibility, and monetization.
- Ingredient rows use `IngredientPickerScreen`, allow household custom ingredient creation, and persist ingredient IDs.
- Public recipes require price estimate and default serving for budget/servings search.
- Private/public card actions follow role permissions.

**Verification:**
- Parser tests stay green.
- Widget tests for editor validation and ingredient linking.
- Firestore emulator test for create/edit/delete, public search, and local copy save.

### Spec 4: Replace Shopping Sample Surfaces With Persisted Lists

**Goal:** Shopping home, scheduled list, Shop Now, substitutions, and history use persisted records end to end.

**Scope:**
- `lib/features/shopping/presentation/screens/shopping_screen.dart`
- `lib/features/shopping/presentation/screens/shopping_list_screen.dart`
- `lib/features/shopping/presentation/providers/shopping_repository_providers.dart`
- `lib/features/shopping/data/datasources/shopping_remote_data_source.dart`

**Acceptance Criteria:**
- Shopping home lists upcoming pending scheduled lists and completed history from `activeShoppingListsProvider`.
- Shop Now supports date-range selection and persists a list before navigation.
- Checklist rows support bought, substituted, unavailable, skipped, with substitute ingredient/quantity/unit capture.
- Completing a Shop Now list updates pantry, records purchase history, and reduces only matching future scheduled-list quantities.
- Suggested/emergency lists can be accepted or ignored/deleted.

**Verification:**
- Unit tests for quantity reduction and unit-normalized grouping.
- Widget tests for list status transitions and substitution editor.
- Emulator integration: scheduled list + Shop Now overlap -> buy partial -> scheduled list shrinks only for bought items.

### Spec 5: Wire Pantry Waste, Bulk, And Spoilage Back Into Calendar/Shopping

**Goal:** Pantry is the source of inventory truth and feeds calendar date labels, shopping suggestions, and premium bulk actions.

**Scope:**
- `lib/features/pantry/**`
- `lib/features/calendar/**`
- `lib/features/shopping/**`
- `lib/features/ingredient_dictionary/data/repositories/ingredient_repository_impl.dart`

**Acceptance Criteria:**
- `IngredientRepository.getById` resolves global and household-custom ingredients.
- Spoiled/expired/waste events create calendar markers for the correct date.
- Bulk prediction recommendations can be added to the next scheduled shopping list.
- Pantry insights are gated by real household premium status.
- Manual adjustments and waste are logged for metrics.

**Verification:**
- Repository tests for custom ingredient lookup and pagination.
- Widget tests for pantry insights premium locked/unlocked states.
- Integration test: mark pantry item waste -> waste log, insights, and calendar marker update.

### Spec 6: Complete Menu Set Home And Apply UX

**Goal:** Menu Sets operate on persisted templates rather than hardcoded carousel samples.

**Scope:**
- `lib/features/menu_sets/presentation/screens/menu_sets_screen.dart`
- `lib/features/menu_sets/presentation/screens/menu_set_editor_screen.dart`
- `lib/features/menu_sets/presentation/providers/menu_set_repository_providers.dart`
- `lib/features/menu_sets/domain/services/menu_set_application_engine.dart`

**Acceptance Criteria:**
- Menu Sets home renders `activeHouseholdMenuSetsProvider`.
- Each persisted set supports view/edit, apply, duplicate, and delete.
- Apply flow lets user choose start/end or cycle count and replace/fill mode.
- Apply persists created/deleted calendar entries and generated scheduled shopping list when appropriate.
- Premium and role rules match the design: premium households see the tab; create/apply only for allowed roles.

**Verification:**
- Domain tests for modulo application, fill/replace, missing recipe handling.
- Widget tests for persisted list empty/loading/data states and selected set actions.
- Emulator integration: create from past calendar -> apply to future range -> calendar and shopping update.

### Spec 7: End-To-End Product Loop

**Goal:** Prove the full design loop works through real screens and persisted data.

**Scenario:**
1. User signs in and selects a household.
2. User creates a recipe with dictionary-linked ingredients.
3. User schedules the recipe on the calendar.
4. Shopping list generation subtracts pantry stock.
5. User completes shopping, including one substitution.
6. Pantry updates and scheduled list adjustments occur.
7. User marks meal cooked.
8. Pantry deducts ingredients and saves leftovers.
9. User schedules leftover and later marks waste/spoilage.
10. Insights/calendar/suggested shopping reflect the result.

**Acceptance Criteria:**
- All steps use persisted data and real route navigation.
- No sample data is required for the flow.
- Role/premium gates are tested with admin, cook, shopper, and member contexts.

**Verification:**
- One emulator-backed integration test for the happy path.
- One negative test for member read-only restrictions.
- One edge test for missing ingredients creating emergency/suggested shopping.

## Suggested Implementation Order

1. **Foundation hardening:** Auth/OAuth, active household selection, real sign-out, role/premium checks at action boundaries.
2. **Calendar scheduling spine:** Recipe detail scheduling, parameterized day route, calendar defaults UI.
3. **Recipe editor and dictionary linking:** Manual create/edit, complete ingredient linking, public search gating.
4. **Shopping persistence cleanup:** Persisted list home/history, substitution editor, scheduled-list shrink verification.
5. **Pantry feedback loop:** Custom ingredient lookup, waste/spoilage calendar markers, bulk recommendation actions.
6. **Menu Set persisted UX:** Replace sample carousel, apply selected set, duplicate/delete.
7. **Full-loop QA:** Emulator-backed E2E across recipe, calendar, shopping, pantry, leftovers, waste, and suggestions.

## Open Questions

- Should Apple/Google OAuth be enabled for this milestone, or hidden until production credentials exist?
- Is "premium" currently a trial flag only, or should payment/subscription provider integration be part of the next implementation plan?
- Should week view be implemented now, or explicitly deferred while month/day flows are completed?
- Should suggested/emergency shopping send push notifications, in-app notifications, or both?
- Is multi-user color-coded checklist attribution required for launch, or only after shared household collaboration is stable?
