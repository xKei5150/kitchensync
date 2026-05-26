Table of Contents  
[1\.	General Module	4](#general-module)

[1.1. Purpose of the General Module	4](#1.1.-purpose-of-the-general-module)

[1.2. User Flow Overview (Narrative)	5](#1.2.-user-flow-overview-\(narrative\))

[1.3. HOUSEHOLD SYSTEM (Narrative)	6](#1.3.-household-system-\(narrative\))

[1.4. Household Rules (Final Version)	7](#1.4.-household-rules-\(final-version\))

[1.5. Household Membership Roles	8](#1.5.-household-membership-roles)

[1.6. Developer Instructions — Household Enforcement	9](#1.6.-developer-instructions-—-household-enforcement)

[1.7. Navigation System (Entry → Dashboard)	11](#1.7.-navigation-system-\(entry-→-dashboard\))

[1.8. Settings Module	11](#1.8.-settings-module)

[1.9. General Module Summary	12](#1.9.-general-module-summary)

[2\. RECIPES MODULE	13](#2.-recipes-module)

[2.1 Purpose	13](#2.1-purpose)

[2.2 Navigation Structure	14](#2.2-navigation-structure)

[2.3 Time Tags	14](#2.3-time-tags)

[2.4 Recipe Creation Options	14](#2.4-recipe-creation-options)

[2.5 Listed Recipe Overview (Venn Diagram Explanation)	17](#2.5-listed-recipe-overview-\(venn-diagram-explanation\))

[2.6 Save → Local Copy Behavior	18](#2.6-save-→-local-copy-behavior)

[2.7 Closer Look (Detailed Recipe View)	18](#2.7-closer-look-\(detailed-recipe-view\))

[2.8 Premium Search Features	19](#2.8-premium-search-features)

[2.9 Data Structures (Updated)	20](#2.9-data-structures-\(updated\))

[2.10 Integration with Ingredient Dictionary (Yellow)	21](#2.10-integration-with-ingredient-dictionary-\(yellow\))

[2.11 Permissions (Role-based)	21](#2.11-permissions-\(role-based\))

[2.12 Summary	21](#2.12-summary)

[3\. CALENDAR / SCHEDULING MODULE	22](#3.-calendar-/-scheduling-module)

[3.1 Purpose	22](#3.1-purpose)

[3.2 Calendar Views & Navigation (User Narrative)	22](#3.2-calendar-views-&-navigation-\(user-narrative\))

[3.3 Color & Label System for Dates	23](#3.3-color-&-label-system-for-dates)

[3.4 Meal Structure: Meal Modes, Meals Per Day, Dishes Per Meal	23](#3.4-meal-structure:-meal-modes,-meals-per-day,-dishes-per-meal)

[3.5 Default Serving Logic	24](#3.5-default-serving-logic)

[3.6 Dish Lifecycle (Per Scheduled Meal)	25](#3.6-dish-lifecycle-\(per-scheduled-meal\))

[3.7 Dish-in-Date Flow (Daily View)	26](#3.7-dish-in-date-flow-\(daily-view\))

[3.8 Leftovers & Waste Handling	26](#3.8-leftovers-&-waste-handling)

[3.9 Meal Merging (Premium)	27](#3.9-meal-merging-\(premium\))

[3.11 Date Planning Labels (Spoilage & Leftovers)	28](#3.11-date-planning-labels-\(spoilage-&-leftovers\))

[3.12 Data Model (Developers)	28](#3.12-data-model-\(developers\))

[3.13 Role Permissions (Calendar)	29](#3.13-role-permissions-\(calendar\))

[3.14 Calendar → Pantry → Shopping Interaction Summary	29](#3.14-calendar-→-pantry-→-shopping-interaction-summary)

[3.15 Emergency Shopping Triggers (High-Level)	30](#3.15-emergency-shopping-triggers-\(high-level\))

[3.16 Summary	30](#3.16-summary)

[4\. SHOPPING LIST MODULE	31](#4.-shopping-list-module)

[4.1 Purpose	31](#4.1-purpose)

[4.2 Entry Points: How Users Get Into Shopping	31](#4.2-entry-points:-how-users-get-into-shopping)

[4.3 Types of Shopping Lists	32](#4.3-types-of-shopping-lists)

[4.4 Data Model	32](#4.4-data-model)

[4.5 How Lists Are Generated	33](#4.5-how-lists-are-generated)

[4.6 Scheduled Shopping Lists	34](#4.6-scheduled-shopping-lists)

[4.7 Shop Now (Your New Behavior)	34](#4.7-shop-now-\(your-new-behavior\))

[4.8 Substitution Logic (And Local Recipe Adjustment)	36](#4.8-substitution-logic-\(and-local-recipe-adjustment\))

[4.9 Checklist Behavior (In-Store Flow)	37](#4.9-checklist-behavior-\(in-store-flow\))

[4.10 Suggested Shopping Lists	37](#4.10-suggested-shopping-lists)

[4.11 Role Permissions (Shopping)	38](#4.11-role-permissions-\(shopping\))

[4.12 Data Flow Recap	38](#4.12-data-flow-recap)

[4.13 Developer Endpoints (Suggested)	38](#4.13-developer-endpoints-\(suggested\))

[4.14 Summary	39](#4.14-summary)

[5\. PANTRY & INGREDIENT DICTIONARY MODULE	39](#5.-pantry-&-ingredient-dictionary-module)

[5.1 Purpose	39](#5.1-purpose)

[5.2 Main Concepts	40](#5.2-main-concepts)

[5.3 Pantry UI Structure (User Narrative)	40](#5.3-pantry-ui-structure-\(user-narrative\))

[5.4 Ingredient Dictionary (Core Yellow Block)	41](#5.4-ingredient-dictionary-\(core-yellow-block\))

[5.5 PantryItem Structure (What’s in stock)	42](#5.5-pantryitem-structure-\(what’s-in-stock\))

[5.6 How Pantry Gets Updated	42](#5.6-how-pantry-gets-updated)

[5.7 Waste & Spoilage Tracking	44](#5.7-waste-&-spoilage-tracking)

[5.8 Bulk Pantry (Premium-heavy)	44](#5.8-bulk-pantry-\(premium-heavy\))

[5.9 Purchase History	45](#5.9-purchase-history)

[5.10 Leftovers in Pantry	46](#5.10-leftovers-in-pantry)

[5.11 UI Flows (Pantry Screen)	46](#5.11-ui-flows-\(pantry-screen\))

[5.12 Role Permissions (Pantry)	47](#5.12-role-permissions-\(pantry\))

[5.13 Interactions With Other Modules	48](#5.13-interactions-with-other-modules)

[5.14 Summary	48](#5.14-summary)

[6\. MENU SETS MODULE	49](#6.-menu-sets-module)

[6.1 Purpose	49](#6.1-purpose)

[6.2 How Users See Menu Sets (Narrative)	49](#6.2-how-users-see-menu-sets-\(narrative\))

[6.3 Anatomy of a Menu Set	50](#6.3-anatomy-of-a-menu-set)

[6.4 Creating a Menu Set	51](#6.4-creating-a-menu-set)

[6.5 Viewing & Editing Menu Sets	52](#6.5-viewing-&-editing-menu-sets)

[6.6 Applying a Menu Set to the Calendar	53](#6.6-applying-a-menu-set-to-the-calendar)

[6.7 Editing After Application	55](#6.7-editing-after-application)

[6.8 Role Permissions (Menu Sets)	55](#6.8-role-permissions-\(menu-sets\))

[6.9 Integration with Other Modules	55](#6.9-integration-with-other-modules)

[6.10 Developer Endpoints (Suggested)	56](#6.10-developer-endpoints-\(suggested\))

[6.11 Summary	57](#6.11-summary)

[7\. SYSTEM INTERACTIONS (FULL ECOSYSTEM OVERVIEW)	57](#7.-system-interactions-\(full-ecosystem-overview\))

[7.1 High-Level Flow Overview	57](#7.1-high-level-flow-overview)

[7.2 Ingredient Dictionary as the Core Reference Spine (Yellow)	58](#7.2-ingredient-dictionary-as-the-core-reference-spine-\(yellow\))

[7.3 Recipes → Dictionary → Pantry (Before Scheduling)	58](#7.3-recipes-→-dictionary-→-pantry-\(before-scheduling\))

[7.4 Calendar as the “Meal Brain” (Indigo)	58](#7.4-calendar-as-the-“meal-brain”-\(indigo\))

[7.5 Calendar → Shopping (Indigo → Teal)	59](#7.5-calendar-→-shopping-\(indigo-→-teal\))

[7.6 Shopping → Pantry Updates (Teal → Yellow)	60](#7.6-shopping-→-pantry-updates-\(teal-→-yellow\))

[7.7 Cooking → Pantry Deductions (Indigo → Yellow)	60](#7.7-cooking-→-pantry-deductions-\(indigo-→-yellow\))

[7.8 Leftovers → Calendar & Pantry (Yellow ↔ Indigo)	61](#7.8-leftovers-→-calendar-&-pantry-\(yellow-↔-indigo\))

[7.9 Spoilage, Waste & Warnings (Yellow ↔ Indigo)	61](#7.9-spoilage,-waste-&-warnings-\(yellow-↔-indigo\))

[7.10 Menu Sets as the Automation Layer (Green)	61](#7.10-menu-sets-as-the-automation-layer-\(green\))

[7.11 Household System Integration (General)	62](#7.11-household-system-integration-\(general\))

[7.12 Summary of System Flow (Step-by-Step)	62](#7.12-summary-of-system-flow-\(step-by-step\))

[7.13 Visualization Summary	64](#7.13-visualization-summary)

[7.14 Developer Takeaway	64](#7.14-developer-takeaway)

1. # **General Module** {#general-module}

![A screenshot of a computer screenAI-generated content may be incorrect.][image1]

## **1.1. Purpose of the General Module** {#1.1.-purpose-of-the-general-module}

The General Module is responsible for:

* User identity and authentication

* Account creation & login

* Household creation, joining, and selection

* Role-based access

* Premium vs free environment rules

* Navigation into the functional modules (Tabs)

* Persisting the active household and session

This module ensures that the system always knows:

* **Which user is currently active**

* **Which household context is active**

* **What permissions the user has inside that household**

  All other features (Recipes, Calendar, Pantry, Shopping, Menu Sets) depend on correct functioning of this module.

  ## **1.2. User Flow Overview (Narrative)** {#1.2.-user-flow-overview-(narrative)}

  Below is the exact sequence a user experiences upon opening the app:

**Step 1 — Launch App → Login Page**

The login page presents:

* **Login**

* **Register**

* OAuth Methods (Google, Apple, etc.)

User chooses between signing in or creating an account.

**Step 2 — Registration**

User can register via:

* Google / OAuth

* Email \+ password (manual registration)

After successful registration:

* A **solo household** is automatically created for free users

* A **prompt to create a joint household** appears for premium users

**Step 3 — Login**

User logs in using:

* OAuth

* Email/password

Upon login, user is taken to:

**Household Page (Pick Household)**

**Step 4 — Household Page Logic**

User must select WHICH household to operate in.

Depending on membership and subscription:

**Free User Household Options**

* Can only have **1 solo household** (default, personal)

* Can optionally join **1 premium-created joint household** (if invited)

**Premium User Household Options**

* Has their solo household

* Can create **one** joint household

* Can join or help administer **multiple** households if granted admin privileges

The Household Page offers:

* **Pick** (choose an existing household)

* **Create** (only allowed if premium and hasn’t created a joint household yet)

* **Join** (enter an invite code for a premium household)

Once a household is selected, it becomes:

**Active Household Context**

This determines all future data and permissions.

**Step 5 — Dashboard**

After selecting a household, user sees the Dashboard with main tabs:

* Recipes

* Calendar

* Shopping List

* Pantry

* Menu Sets (Premium-only)

* Settings

This marks the transition into the main feature modules.

## **1.3. HOUSEHOLD SYSTEM (Narrative)** {#1.3.-household-system-(narrative)}

This is one of the most important and unique parts of your app.

A household determines:

* Who shares recipes

* Who shares pantry & shopping lists

* Who participates in meal planning

* Who receives notifications

* Which users can edit or only view

* How premium benefits extend

  ## **1.4. Household Rules (Final Version)** {#1.4.-household-rules-(final-version)}

These rules define how households work for free and premium users.

**1\.4.1 Free User Rules**

A free user:

**✔ Rule 1 — Has exactly 1 household: a solo household**

* Only **one member** (themselves)

* Cannot add members

* Cannot invite others

* Cannot convert to joint

  **✔ Rule 2 — Cannot create joint households**

  Solo only.

  **✔ Rule 3 — CAN join one premium-created joint household**

  IF invited by a premium admin.

  **✔ Rule 4 — Free users in joint households have normal household roles**

  (assigned by admins)

  **1\.4.2 Premium User Rules**

  A premium user:

  **✔ Rule 5 — Can create ONE joint household**

* Up to 6 members total

* They become the first admin

* Can invite:

  * 5 free users

  * Unlimited premium users

  **✔ Rule 6 — Can join additional households as admin**

  **BUT only if another premium user assigns them.**

  **✔ Rule 7 — Unlimited household membership (if invited by premium admins)**

  But can create only one joint household.

    **✔ Rule 8 — Premium benefits extend to all free users inside their joint household**

  Premium acts like a **household-wide upgrade**.

  ## **1.5. Household Membership Roles** {#1.5.-household-membership-roles}

There are **4 roles**, each with specific privileges:

**1.5.1. Admin**

* Can invite/remove members

* Assign roles

* Create & edit Menu Sets

* Manage household settings

* Manage shopping schedules

* Override pantry items

* Transfer admin to another premium user

* Can mark items waste/discarded

* Full access to all premium features (if household has premium)

  **1.5.2. Cook**

* Can:

  * Schedule meals

  * Mark meals cooked

  * Adjust meal servings

  * Create household-specific recipe overrides

  * Manage leftovers & reschedules

* Cannot modify household membership

  **1.5.3. Shopper**

* Can:

  * Manage shopping lists

  * Complete shopping

  * Confirm substitutions

  * Update purchased quantities

  * Review bulk items

* Cannot schedule meals

  **1.5.4. Member**

* View-only except:

  * Can view recipes

  * View pantry

  * View calendar

  * View shopping list

* Cannot edit or manage data

  ## **1.6. Developer Instructions — Household Enforcement** {#1.6.-developer-instructions-—-household-enforcement}

This section is for implementation clarity.

**1.6.1 Database Structure**

**users**

id

email

name

password\_hash

oauth\_provider

is\_premium (bool)

**households**

id

creator\_user\_id

is\_joint (bool)

max\_members (int)  // 1 for free households, 6 for premium

**household\_members**

id

household\_id

user\_id

role (enum: admin, cook, shopper, member)

**1.6.2 Household Creation Logic**

**Free User**

if \!user.is\_premium:

    create household:

       is\_joint \= false

       max\_members \= 1

**Premium User**

if user has no other joint household:

    create household:

       is\_joint \= true

       max\_members \= 6

else:

    REJECT: "Premium users can only create one joint household."

**1.6.3 Joining Logic**

**Free User may join:**

* Only **premium-created** households

* And only if max\_members not exceeded

  **Premium User may join:**

* Any household where a premium admin grants admin/cook/shopper/member role

  **Prevent invalid membership:**

  if household.is\_joint \== false AND household.current\_members \>= 1:

      reject (solo household cannot have \>1 member)

  **1.6.4 Active Household Selection (Critical)**

  Every app module checks for:

  if \!activeHouseholdId:

     redirect to household\_picker

  Every API call receives:

  (user\_id, active\_household\_id)

  AND validates:

  is user a member of this household?

  AND

  does user have required role?

  ## **1.7. Navigation System (Entry → Dashboard)** {#1.7.-navigation-system-(entry-→-dashboard)}

* After household is selected → **Dashboard**

* Dashboard displays tabs based on:

  * Permissions

  * Premium status

  * Household type (solo vs joint)

**Example conditional UI logic:**

* **Menu Sets tab** → show only if household has premium

* **Shopping Checklist (multi-user color-coded)** → premium only

* **Member management** → admin only

  ## **1.8. Settings Module** {#1.8.-settings-module}

Settings contain:

* Profile

* Premium subscription

* Household management

* Notifications

* App preferences

* Log out

Developers implement as:

* /settings/profile

* /settings/household

* /settings/subscription

* /settings/preferences

  ## **1.9. General Module Summary** {#1.9.-general-module-summary}

The general module establishes:

**✔ User identity**

**✔ Premium status**

**✔ Household eligibility rules**

**✔ Membership roles & permissions**

**✔ Active household context**

**✔ Secure authentication**

**✔ Navigation to all functional modules**

This is the backbone of the entire system.

# **2\. RECIPES MODULE** {#2.-recipes-module}

![A screenshot of a computer screenAI-generated content may be incorrect.][image2]

## **2.1 Purpose** {#2.1-purpose}

The **Recipes Module** is the entry point for creating, viewing, saving, and discovering recipes.  
It is the structural backbone for:

* Calendar scheduling

* Pantry deduction

* Shopping list generation

* Menu sets

Recipes contain the ingredient data that powers the entire food lifecycle.

## **2.2 Navigation Structure** {#2.2-navigation-structure}

When the user selects **Recipes** from the main Dashboard, they are taken to a **two-tab interface**:

**Tab 1: My Recipes**

Contains:

* Recipes created by the user

* Recipes created by other household members (if joint)

* Saved/local copies of public recipes

* Private and Public recipes owned by the user

**Tab 2: Discover**

Contains:

* All **public recipes** made by any user across the system

* Trending, most viewed tags, most interacted authors, etc.

* Premium-enabled filters

  ## **2.3 Time Tags** {#2.3-time-tags}

Time Tags represent **meal times of day**:

* Breakfast

* Brunch

* Lunch

* Dinner

* Snack

They help with filtering, meal scheduling, menu set generation, and recipe discovery.

---

## **2.4 Recipe Creation Options** {#2.4-recipe-creation-options}

A user can add a recipe in two ways:

---

**2.4.1 Option A — Fill-In (Manual Creation)**

Fields in the manual entry form:

1. **Name**

2. **Default Serving Size**

3. **Time Tags** (Breakfast/Lunch/etc.)

4. **Recipe Tags** (Cuisine, diet, category)

5. **Description**

6. **Ingredients**

   * Ingredient Name → tied to **Ingredient Dictionary** (yellow module)

   * Quantity

   * Unit

   * Preparation notes

   * Shelf life (optional)

7. **Instructions**

8. **Dish Image (Optional)**

9. **Location** (auto defaults to user)

10. **Price Estimate** (manual input, premium can enhance)

11. **YouTube Embed** (optional)

12. **Access Type**

    * Private

    * Public

13. **Monetization** (premium authors only)

    * Free

    * Paid

Saving pushes ingredient names into the **Ingredient Dictionary** for Pantry integration.

**2.4.2 Option B — Paste & Parse (Premium)**

The Parse feature is a powerful tool designed to work with **external AI systems** (e.g., "format this recipe in the parse format").

**✔ It accepts multiple recipes at once**

If the AI outputs three recipes in parse format, the user can paste all of them and create all three in one import action.

**✔ Provides a standardized “Parse Format” template**

The Parse view shows users the exact structure required to bulk-import recipes.

**Example Parse Format Template (Developers should display this):**

\=== RECIPE START \===

Name: Fried Chicken

Servings: 4

Time Tags: Lunch, Dinner

Recipe Tags: Chicken, Fried, Comfort Food

Price Estimate: 250

Ingredients:

\- Chicken Thighs | 1 kg | pcs

\- Flour | 2 cups | cup

\- Salt | 1 tbsp | tbsp

\- Oil | 500 ml | ml

Instructions:

1\. Mix flour and salt.

2\. Coat chicken.

3\. Fry until golden.

YouTube: https://youtu.be/example

Access: Private

\=== RECIPE END \===

Users can paste multiple:

\=== RECIPE START \===

...

\=== RECIPE END \===

\=== RECIPE START \===

...

\=== RECIPE END \===

**Behind the scenes:**

* System splits recipes by START/END markers

* Parses fields

* Creates multiple recipe entries

* Adds missing ingredients to Ingredient Dictionary

  ## **2.5 Listed Recipe Overview (Venn Diagram Explanation)** {#2.5-listed-recipe-overview-(venn-diagram-explanation)}

Your diagram shows **private vs public recipe card differences** using a Venn diagram.

**Shared Middle Fields (shown on ALL recipe cards)**

* Name

* Dish image

* Location

* Time Tags (meal times)

* Recipe Tags

* Description

**Left Circle \= Private Recipe Extras**

Displayed **only** when recipe.visibility \= “private”

* Edit

* Delete

* Unsave (if it's a local copy)

* No social metrics (likes/comments hidden)

These are visible in **My Recipes** when:

* The recipe is private

* The user owns it

* Or belongs to the household it was created in

**Right Circle \= Public Recipe Extras**

Displayed **only** when recipe.visibility \= “public”:

* Price Estimate prominently

* Save / Unsave

* Like button / Like count

* Comment icon / Comment count

These appear mainly under **Discover**.

## **2.6 Save → Local Copy Behavior** {#2.6-save-→-local-copy-behavior}

Saving a public recipe:

* Creates a **local copy**

* Places it inside **My Recipes**

* Local copy is editable

* Does NOT modify the original author’s recipe

* Deleting the local copy does NOT delete the original

* Editing the local copy does NOT update the original

  ## **2.7 Closer Look (Detailed Recipe View)** {#2.7-closer-look-(detailed-recipe-view)}

Opening a recipe from the list shows:

* Name

* Author

* Default Serving Size

* Adjust Serving Size (slider or numerical)

* Adjusted ingredients list (scaled)

* Price Estimate

* Time Tags

* Recipe Tags

* Description

* Full instructions

* YouTube Embed

* Buttons:

  * Edit (if user owns it)

  * Delete (if user owns it)

  * Save/Unsave (if public)

  * Like/Comment (if public)

This is also the view used by the **Calendar / Schedule** module when picking a recipe for a meal.

## **2.8 Premium Search Features** {#2.8-premium-search-features}

Premium users unlock the **Servings \+ Price Estimate filter combination**.

**Why it's premium**

It requires price normalization and ingredient dictionary lookups.

**2.8.1 How the Premium Search Works**

Users can filter public recipes with:

**Budget \+ Target Servings**

Example search:

“Recipes under **₱500** for **8 servings**”

This filter only appears if:

* User is premium

* User fills BOTH fields

**2.8.2 How Price Normalization Works**

When a public recipe has:

* Price Estimate: ₱250

* Default Servings: 4

Then:

**Price per serving \= 250 / 4 \= ₱62.50**

If user searches:  
**₱500 for 8 servings**

Compute:

Adjusted Price \= price\_per\_serving × target\_servings  
Adjusted Price \= 62.50 × 8 \= 500

If adjusted price \<= budget → include in results.

This requires backend preprocessing.

**2.8.3 Important Developer Rule**

All public recipes MUST declare:

* Price estimate

* Default serving size

If missing:

* They are excluded from price/servings search

* OR normalized using fallback rules (optional)

  ## **2.9 Data Structures (Updated)** {#2.9-data-structures-(updated)}

**Recipe**

id

author\_user\_id

household\_id

name

description

dish\_image\_url

default\_serving\_size

meal\_time\_tags\[\]          // breakfast, lunch, etc

recipe\_tags\[\]

price\_estimate

location

youtube\_embed\_url

visibility (private/public)

monetization (free/paid)

created\_at

updated\_at

**SavedRecipe**

id

user\_id

household\_id

source\_recipe\_id

local\_recipe\_id

**RecipeIngredient**

id

recipe\_id

ingredient\_id

quantity

unit

description

## **2.10 Integration with Ingredient Dictionary (Yellow)** {#2.10-integration-with-ingredient-dictionary-(yellow)}

Every ingredient entered or parsed is:

* Matched against Ingredient Dictionary

* If not found, auto-added

* Used for:

  * Pantry

  * Shopping lists

  * Price estimation

  * Leftovers

  * Meal deduction

This is why the diagram draws a yellow connection.

## **2.11 Permissions (Role-based)** {#2.11-permissions-(role-based)}

| Role | Create | Edit | Delete | Comment | Save Public | Like |
| :---- | :---- | :---- | :---- | :---- | :---- | :---- |
| Admin | Yes | Yes | Yes | Yes | Yes | Yes |
| Cook | Yes | Yes | Yes | Yes | Yes | Yes |
| Shopper | No | No | No | Yes | Yes | Yes |
| Member | No | No | No | Yes | Yes | Yes |

Solo user \= all roles.

## **2.12 Summary** {#2.12-summary}

This rewritten Recipes Module:

* Fully matches your diagram

* Includes My Recipes & Discover tabs

* Includes the AI-oriented multi-recipe parse format

* Integrates Ingredient Dictionary

* Adds premium search-by-servings+budget logic

* Clarifies public vs private recipe card behavior

* Includes time-of-day tags correctly

* Explains local copy saving behavior

* Establishes complete data & role behavior

# **3\. CALENDAR / SCHEDULING MODULE** {#3.-calendar-/-scheduling-module}

## **3.1 Purpose** {#3.1-purpose}

The **Calendar Module** is where:

* Meals are scheduled on specific dates

* Serving sizes are determined

* Dishes are marked as *cooked*, *leftover*, or *waste*

* Color-coded day states visually show planning status

* Pantry deductions and shopping needs are driven

It is the **central coordinator** between:

* Recipes (what to cook)

* Pantry (what you have)

* Shopping (what you must buy)

* Menu Sets (repeated plans)

  ## **3.2 Calendar Views & Navigation (User Narrative)** {#3.2-calendar-views-&-navigation-(user-narrative)}

When the user taps **Calendar** from the main Dashboard:

1. They see a **month view** by default (Calendar View: A Month)

2. They can toggle between:

   * Month view

   * Week view (and possibly day view later)

Each date cell shows:

* A **list of recipe names** scheduled that day

* Color label indicating status (explained below)

* Optional icons (shopping, leftovers, etc.)

Tapping a date:

* Opens a “Dish in Date” view showing all meals/dishes for that day.

* From there, user can:

  * See recipe overview

  * Adjust serving size (if allowed)

  * Mark dish states (done, not yet done, leftover, cancelled)

  * Jump into full recipe “Closer Look”

---

## **3.3 Color & Label System for Dates** {#3.3-color-&-label-system-for-dates}

Each calendar date is visually encoded.

**Colors:**

* **Green** – Planned & ingredients available

* **Red** – Unplanned OR missing ingredients / cooking problem

* **Blue** – Shopping schedule day

* **Yellow** – Days where scheduled shopping date has passed **without shopping**

**Labels:**

* **Ended dates** – Past days; can show spoilage/waste

* **Approaching / Current dates** – Emphasized for immediate attention

**Leftover & Waste indicators:**

* Extra marking if:

  * Leftovers scheduled to be eaten

  * Leftovers discarded or marked as waste

  ## **3.4 Meal Structure: Meal Modes, Meals Per Day, Dishes Per Meal** {#3.4-meal-structure:-meal-modes,-meals-per-day,-dishes-per-meal}

The calendar lets users define **how many meals happen in a day** and **what kind of meals they are**.

**3.4.1 Meal Modes**

A “Meal Mode” is a named configuration such as:

* “Weekday Workday”

* “Weekend”

* “High-Meal-Prep”

* etc.

When setting a **Meal Schedule**, user can:

1. Set default **Meal Mode Name**

2. Set **Number of Meals per Day** (e.g., 3 meals/day)

3. Set **Number of Dishes per Meal** (e.g., 1–4 dishes)

4. Apply this configuration over:

   * Specific days

   * A date range

   * Whole week/month

Later, menu sets can overlay on this.

## **3.5 Default Serving Logic** {#3.5-default-serving-logic}

This is critical and drives both scheduling **and** shopping.

**3.5.1 Calendar Default Servings**

Inside the Calendar’s **Settings / Set Defaults**, user can define:

* **Default Serving Size** (per person count or portion count)

* Meal Mode \+ number of meals/dishes per day

**Rule:**

When a recipe is scheduled onto the calendar, if a **calendar default serving** is set, the recipe’s serving size for that scheduled instance is **auto-adjusted** to match that default.

Example:

* Calendar default serving: 4

* Recipe default serving: 2

* User schedules recipe → scheduled instance will use serving\_size \= 4  
  (ingredients scaled ×2)

This scaled serving is what:

* Shows in the “Dish in Date” view

* Feeds into Shopping List calculations

* Drives Pantry deductions when cooked

**3.5.2 If No Calendar Default is Set**

If the user doesn’t set any default in the calendar, then **each scheduled recipe uses its own recipe default serving size** (defined by the author in the recipe module).

So:

* No default set → scheduled\_serving\_size \= recipe.default\_serving\_size

* Later user can still manually adjust that particular scheduled instance if desired.

Developers: scheduled meals must always store an explicit serving\_size value so the shopping engine has a concrete number, even if it's just copied from the recipe.

## **3.6 Dish Lifecycle (Per Scheduled Meal)** {#3.6-dish-lifecycle-(per-scheduled-meal)}

Each scheduled dish (a **MealScheduleEntry**) goes through states:

1. **Scheduled (Not yet done)**

   * Appears in calendar with its set serving size.

2. **Done Cooking**

   * Triggers pantry deductions based on:

     * Recipe ingredients

     * Serving size (calendar default or manual override)

3. **Leftover** (optional step)

   * User can mark some or all portions as leftover

   * Creates leftover entries in Pantry

   * Allows leftover scheduling on future dates

4. **Consumed / Waste**

   * Leftovers either get:

     * Scheduled to eat (consumed)

     * Marked as waste (spoiled / discarded)

5. **Cancelled** (alternate path)

   * User can cancel the dish

   * Depending on logic:

     * It might free associated ingredients

     * It might push schedule forward (if part of a menu mode)

**Developer recommendation:**

Represent dish state as:

state: scheduled | cooked | leftover | cancelled

marking: none | leftover\_scheduled | waste | unused

## **3.7 Dish-in-Date Flow (Daily View)** {#3.7-dish-in-date-flow-(daily-view)}

When a date is tapped:

1. Show a list of all dishes scheduled for that day.

2. For each dish, display a **scaled Recipe Overview**:

   * Recipe Name

   * Time Tags (meal-time)

   * Recipe Tags

   * Adjusted Serving Size

   * Price estimate (if available)

   * Current state (not done, done, leftover, cancelled)

3. Actions per dish:

   * **View Closer Look** (full recipe detail)

   * **Change Scheduled Dish** (swap recipe)

   * **Change Serving Size**

   * **Mark as Done Cooking**

   * **Mark as “Cook Next” (reschedule)**

   * **Cancel Schedule**

   * **Schedule leftover** (when applicable)

   ## **3.8 Leftovers & Waste Handling** {#3.8-leftovers-&-waste-handling}

**Scheduling Leftovers**

If a dish generates leftovers:

* Calendar displays suggestion: “Schedule leftover for \[future date\]”

* User can pick a date to eat leftover portions

* Serving size for leftover dish \= leftover portion count

If leftovers are **not** consumed by a “safe-by” date:

* The system can:

  * Mark them as **waste**

  * Show that waste in Calendar and Pantry metrics

  ## **3.9 Meal Merging (Premium)** {#3.9-meal-merging-(premium)}

Your diagram includes **meal merging**, e.g.:

“1 dish for 2 meals” → automatically adjusts serving to twice default

**Examples:**

* User chooses to merge **Lunch \+ Dinner** into one cooking event.

* They indicate a merging pattern like 2:1 (two meals into one dish).

**Effect:**

* A single dish is scheduled for one time in the day

* serving\_size \= default\_serving \* number\_of\_meals\_merged

* Shopping list and pantry use the multiplied serving size

Merging is a **premium feature**, controlled by a flag.

**3.10 Calendar Defaults & Shopping List Integration**

The calendar is responsible for **driving shopping needs**.

**3.10.1 Stock-Based Scheduling**

For each future date:

* Take all MealScheduleEntry items

* For each:

  * Get recipe ingredients

  * Scale by serving\_size (calendar default or recipe default)

* Aggregate all ingredients across the shopping cycle range

* Subtract current pantry inventory

* Result \= ingredients to buy

**Key point with your clarification:**

The **serving size used in these calculations is the calendar-adjusted serving**, not the recipe’s default, *unless* there is no calendar default set.

So the shopping engine always uses:

if (calendar\_default\_serving exists):

    scheduled\_serving\_size \= calendar\_default

else:

    scheduled\_serving\_size \= recipe.default\_serving\_size

// \+ any per-meal manual override

## **3.11 Date Planning Labels (Spoilage & Leftovers)** {#3.11-date-planning-labels-(spoilage-&-leftovers)}

Your indigo diagram specifies markings for:

* **Spoilage**: ingredients or leftovers passed safe date → mark day as having wastage.

* **Scheduled to eat leftovers**: indicates leftover reuse (green \+ leftover icon).

* **Waste / discarded**: leftover not consumed, user marks as waste.

* **No markings**: default / nothing special.

These labels tie back to **Pantry Metrics** and to user feedback (e.g., “You wasted X ingredients this week”).

## **3.12 Data Model (Developers)** {#3.12-data-model-(developers)}

**3.12.1 MealScheduleEntry**

MealScheduleEntry

\-----------------

id

household\_id

date                       // YYYY-MM-DD

meal\_slot                  // e.g., "breakfast", "lunch", "dinner", "snack", or custom index

recipe\_id

serving\_size               // explicit numeric value (after applying defaults/overrides)

state                      // scheduled | cooked | leftover | cancelled

marking                    // none | leftover\_scheduled | waste | unused

linked\_leftover\_id (nullable)

**3.12.2 DaySettings (Defaults)**

DaySettings

\-----------

id

household\_id

date\_range\_start

date\_range\_end

default\_serving\_size       // calendar default

meals\_per\_day

dishes\_per\_meal

meal\_mode\_name

is\_active

**3.12.3 LeftoverEntry (optional struct or reuse PantryItem)**

Either:

* Use PantryItem with a flag is\_leftover \= true, or

* Make a LeftoverEntry linking to Pantry.

  ## **3.13 Role Permissions (Calendar)** {#3.13-role-permissions-(calendar)}

* **Admin**

  * Full access: configure defaults, meal modes, schedule/remove dishes, override serving, mark cooked/leftover/waste.

* **Cook**

  * Can schedule meals, mark cooked, change servings, handle leftovers.

* **Shopper**

  * Read-only view of calendar (to understand upcoming meals)

  * Can’t change schedule but can see which meals are driving shopping.

* **Member**

  * Read-only view.

Solo user gets all functional powers.

## **3.14 Calendar → Pantry → Shopping Interaction Summary** {#3.14-calendar-→-pantry-→-shopping-interaction-summary}

1. **Scheduling**

   * Calendar creates MealScheduleEntries with specific serving sizes.

2. **Shopping generation**

   * Shopping Engine looks at upcoming MealScheduleEntries for a date range.

   * Uses serving\_size × recipe ingredients to compute needed quantities.

   * Subtracts pantry stock.

3. **Cooking**

   * When user marks “Done Cooking”, Calendar calls Pantry service:

     * Deduct ingredients accordingly.

   * If ingredients are missing at cook time, Calendar may trigger:

     * **Emergency shopping** notification

     * Mark date red

     * Maybe create an immediate special shopping list.

4. **Leftovers**

   * Represented as pantry items or leftover entries.

   * Future MealScheduleEntries can reference leftovers to avoid buying new ingredients.

   ## **3.15 Emergency Shopping Triggers (High-Level)** {#3.15-emergency-shopping-triggers-(high-level)}

* If a cooking event finds necessary ingredients unfilled:

  * Calendar marks that day red.

  * Optionally:

    * Creates “Emergency Shopping List” for those missing items.

    * Sends notifications to household members with role Shopper.

  * If user declines emergency shopping:

    * Dish may be marked cancelled or rescheduled.

  ## **3.16 Summary** {#3.16-summary}

The Calendar Module:

* Provides visual planning for all meals.

* Uses **calendar defaults** for serving sizes where set, falling back to recipe defaults where not.

* Drives shopping lists and pantry updates using those serving sizes.

* Manages dish lifecycle (scheduled → cooked → leftover → waste).

* Coordinates leftover scheduling and spoilage marking.

* Supports meal merging logic for premium users.

* Encodes planning status with color-coded days.

* Strictly respects household roles and membership.

# **4\. SHOPPING LIST MODULE** {#4.-shopping-list-module}

## **4.1 Purpose** {#4.1-purpose}

The **Shopping List Module** turns planned meals (Calendar) \+ current stocks (Pantry) into:

* Concrete shopping lists

* For specific shopping dates (scheduled)

* Or immediate trips (“Shop Now”)

It also:

* Handles partial shopping (only buying some of what's planned)

* Updates scheduled shopping lists when items are pre-bought

* Manages substitutions

* Feeds purchases back into Pantry

* Triggers Suggested Shopping when ingredients are missing

It is tightly connected to:

* **Calendar** (which meals are coming)

* **Pantry** (what is already in stock)

* **Recipe / Ingredient Dictionary** (what is needed and in what units)

* **Household roles** (who shops, who just watches)

  ## **4.2 Entry Points: How Users Get Into Shopping** {#4.2-entry-points:-how-users-get-into-shopping}

From the main Dashboard, tapping **Shopping List** opens a view with:

1. **Upcoming Scheduled Shopping Dates** (from calendar planning)

2. A button: **Shop Now**

3. Past shopping sessions (history / completed lists)

The user can:

* Tap a specific scheduled shopping date → open that Scheduled Shopping List

* Tap **Shop Now** → generate an on-demand list for a chosen date range

  ## **4.3 Types of Shopping Lists** {#4.3-types-of-shopping-lists}

We’ll treat them as different type values of the same entity.

**1\. Scheduled Shopping List**

* Generated in advance, based on:

  * All meals between shopping\_date and the next scheduled shopping date

* Each scheduled shopping day has its own list

**2\. Shop Now List**

* Generated on the fly

* User chooses:

  * Number of days ahead to cover (e.g., “next 3 days”)

  * Or a date range

* Includes ingredients needed for those meals

* Can partially or fully fulfill future scheduled shopping lists

**3\. Suggested Shopping List**

* Generated when the system detects:

  * Future meals won’t have enough ingredients due to:

    * Missing items not bought previously

    * Spoilage

    * Extra meals added later

**4\. Emergency Shopping List (optional / future)**

* Generated when:

  * User tries to cook but ingredients are missing right now

All of these are structurally the same, with different origin and behavior rules.

## **4.4 Data Model** {#4.4-data-model}

**4.4.1 ShoppingList**

ShoppingList

\------------

id

household\_id

type            // scheduled | shop\_now | suggested | emergency

shopping\_date   // target date of the trip

generated\_for\_range\_start  // YYYY-MM-DD (calendar range)

generated\_for\_range\_end    // YYYY-MM-DD

status          // pending | completed | cancelled

origin\_id       // optional reference (e.g., scheduled date or generator batch)

created\_at

updated\_at

**4.4.2 ShoppingListItem**

ShoppingListItem

\----------------

id

shopping\_list\_id

ingredient\_id

quantity\_needed       // total required amount

unit

status                // unchecked | bought | substituted | unavailable | skipped

substitute\_ingredient\_id (nullable)

substitute\_quantity (nullable)

substitute\_unit (nullable)

source\_meal\_links\[\]   // links to MealScheduleEntries / date+meal references

source\_meal\_links is important: it lets us know *which future days / meals* this item was for so we can partially satisfy those lists later.

## **4.5 How Lists Are Generated** {#4.5-how-lists-are-generated}

**4.5.1 From Calendar (Core Logic)**

For a given date range \[start, end\] (shopping cycle):

1. Collect all **MealScheduleEntries** within that range.

2. For each, retrieve:

   * recipe\_id

   * serving\_size (calendar default or recipe default, plus any overrides)

3. For each recipe:

   * Get all RecipeIngredients

   * Scale each by serving\_size / default\_serving\_size

4. Aggregate same ingredients across all meals:

   * Sum quantities (normalize units if necessary via Ingredient Dictionary)

5. Subtract pantry stock:

   * If pantry already has enough of an ingredient, exclude from the list

   * If partial, only list the deficit

Result: a list of ingredients the household needs to acquire for that range.

This logic is used both for **Scheduled** and **Shop Now** lists, just with different ranges.

## **4.6 Scheduled Shopping Lists** {#4.6-scheduled-shopping-lists}

A **Scheduled Shopping List** is tied to a shopping date (blue in the calendar).

**Generation:**

* When a schedule is set (e.g., “We shop every Saturday”), a Scheduled Shopping List is generated:

  * start \= last\_shopping\_date \+ 1

  * end \= this\_shopping\_date

* User can open that list, review it, and edit before shopping.

These lists are the “canonical” plans for future shopping.

## **4.7 Shop Now (Your New Behavior)** {#4.7-shop-now-(your-new-behavior)}

This is where your special logic comes in.

**4.7.1 How Shop Now Works (Narrative)**

User taps **Shop Now**:

1. App asks:

   * “For how many days do you want to shop?”  
     OR

   * “Pick a date range to cover.”

2. System generates a **Shop Now List** using the same logic as a scheduled list, but for \[today, chosen\_end\].

3. This list may overlap with days that already have **Scheduled Shopping Lists** created.

4. User goes to the store with this Shop Now list.

**4.7.2 Partial Ticking & Confirmation**

In the Shop Now list, the user might:

* Buy *some* items

* Skip others (too expensive, not available yet, etc.)

They tick what they **actually bought**.

When they tap **Done Shopping** on the Shop Now list:

Two things happen:

1. **Pantry Update**

   * For each item with status \= bought or substituted:

     * Add those ingredients to Pantry.

   * For unavailable items:

     * Pantry unchanged.

2. **Scheduled List Adjustment (Important)**  
   This is the behavior you described:

   * The system knows which future meals and scheduled lists those items were originally for through source\_meal\_links.

   * For every ShoppingListItem marked bought:

     * Find all **Scheduled Shopping Lists** whose source\_meal\_links refer to that ingredient & those dates.

     * **Deduct the bought quantity from those scheduled lists.**

   * If entire quantity for that ingredient and date range is now satisfied:

     * Remove that ingredient from the future scheduled lists.

   * If only partially satisfied:

     * Future lists only show remaining deficit.

The items **not bought** remain scheduled:

“and still schedules the items not yet on the indicated schedules.”

That means:

* If you didn’t buy them now → they **stay** in the future scheduled lists unchanged.

  * The scheduled system still expects them to be bought on the planned shopping day.

**4.7.3 Developer Perspective**

When finalizing a Shop Now list:

for each item in shopNowList.items:

    if item.status in \['bought', 'substituted'\]:

        add\_to\_pantry(item or substitute)

        for each source\_link in item.source\_meal\_links:

            locate scheduled shopping lists generated for that range

            reduce quantity\_needed for that ingredient in those lists

            if reduced\_to\_zero:

                remove that item from that scheduled list

    else:

        // 'unchecked', 'unavailable', 'skipped'

        // no pantry change, no scheduled list change

The critical point: **Shop Now can fulfill part of future plans**, but does not eliminate future lists entirely—only adjusts them.

## **4.8 Substitution Logic (And Local Recipe Adjustment)** {#4.8-substitution-logic-(and-local-recipe-adjustment)}

When an item can’t be found, user can mark it as **Substituted**:

* Choose a replacement ingredient from the dictionary.

* Input replacement quantity & unit.

* That substitution:

1. Is applied to **Pantry** as the ingredient actually bought.

2. Is recorded as a **per-meal override** (not in My Recipes):

   * When those source\_meal\_links meals are cooked,

   * The calendar uses MealIngredientOverride for those meals:

     * “Use ingredient B instead of A for this meal instance only.”

This ensures:

* The base recipe in “My Recipes” remains unchanged.

* Only the scheduled instance reflects the substitution.

  ## **4.9 Checklist Behavior (In-Store Flow)** {#4.9-checklist-behavior-(in-store-flow)}

On any shopping list (Scheduled or Shop Now):

* Items are shown as a checklist.

* Each household member can see the same shared list (in joint households).

* In premium households, you could show:

  * Per-member color-coded ticks (who picked what).

For each item row:

* Ingredient name

* Needed quantity/unit

* Check/toggle status:

  * Unchecked

  * Bought

  * Substituted

  * Unavailable

  ## **4.10 Suggested Shopping Lists** {#4.10-suggested-shopping-lists}

If:

* Meals are approaching

* Pantry is missing key ingredients

* These ingredients were not purchased as expected

* OR they were removed from a previous shopping list

The system can create a **Suggested Shopping List**:

* Type: suggested

* Range: nearest meal dates that need that ingredient

* Status: pending

* User can: 

* Accept → goes through checklist flow

* Ignore / delete

This helps recover from missed shopping or partial shopping.

## **4.11 Role Permissions (Shopping)** {#4.11-role-permissions-(shopping)}

* **Admin**

  * Full access to all lists: generate, edit, finalize, delete.

* **Shopper**

  * Full access to checklist behavior (tick, substitutes, confirm).

  * Can initiate Shop Now.

* **Cook**

  * View lists (to know what’s coming).

* **Member**

  * View only.

Solo user \= all powers.

## **4.12 Data Flow Recap** {#4.12-data-flow-recap}

1. **Calendar** → knows what needs to be cooked, when, and in what serving size.

2. **Shopping Engine** → looks at future meals & pantry → generates needed ingredients.

3. **Scheduled Lists** → plan future trips.

4. **Shop Now** → optional early/extra trips that can partially cover future needs.

5. **Shop Now Confirmation**:

   * Adds bought items to pantry.

   * Deducts those items from future scheduled lists, keeping non-bought items intact.

6. **Cooking** → uses pantry & possible substitutions; triggers actual deductions.

7. **Suggested Lists** → patch missed or partially handled needs.

   ## **4.13 Developer Endpoints (Suggested)** {#4.13-developer-endpoints-(suggested)}

* POST /shopping/generate

  * body: type (scheduled/shop\_now/suggested), date range

* GET /shopping/lists

* GET /shopping/lists/:id

* PUT /shopping/lists/:id/items/:itemId

  * update status, substitution info

* POST /shopping/lists/:id/complete

  * triggers:

    * Pantry updates

    * Scheduled list adjustments (in case of Shop Now)

* DELETE /shopping/lists/:id

  ## **4.14 Summary** {#4.14-summary}

The Shopping List Module:

* Converts scheduling \+ pantry into actionable shopping checklists.

* Supports **scheduled** and **on-demand (Shop Now)** shopping.

* Allows partial buying today to reduce what’s needed on future scheduled days.

* Maintains pending items for future shopping when not purchased now.

* Handles substitutions in a way that:

  * Updates pantry to what was actually bought

  * Locally alters dishes in the calendar but **not** base recipes

* Integrates with joint households, roles, and premium behaviors.

# **5\. PANTRY & INGREDIENT DICTIONARY MODULE** {#5.-pantry-&-ingredient-dictionary-module}

## **5.1 Purpose** {#5.1-purpose}

The **Pantry Module** is the system’s live view of **what the household currently has**:

* Food ingredients

* Bulk items (oil, rice, flour, spices, etc.)

* Non-food consumables (foil, detergent, tissue, etc.)

* Leftovers

It powers:

* Shopping list generation (what’s missing)

* Calendar cooking deductions

* Spoilage & waste tracking

* Bulk purchase reminders

* “Days left” estimates (premium)

* Ingredient standardization for recipes

It is tightly coupled with the **Ingredient Dictionary** (yellow), which is the canonical index of all ingredients used by:

* Recipes

* Pantry

* Shopping

  ## **5.2 Main Concepts** {#5.2-main-concepts}

The yellow cluster is actually **two intertwined subsystems**:

1. **Pantry Inventory**

   * What the household currently owns

   * Food, bulk, non-food, leftovers

2. **Ingredient Dictionary**

   * Canonical list of all ingredients

   * Standardized units, shelf life, categories, price hints

   ## **5.3 Pantry UI Structure (User Narrative)** {#5.3-pantry-ui-structure-(user-narrative)}

When user taps **Pantry** from the main Dashboard, they see:

**Sections:**

1. **Food Pantry**

   * Standard ingredients (tomatoes, eggs, sugar, etc.)

   * Leftovers (flagged items)

2. **Bulk Pantry** (premium-heavy)

   * Large-volume, slow-changing items:

     * Oil, rice, sugar, spices, etc.

3. **Non-Food Pantry**

   * Foil, wrap, dish soap, tissue, detergent, etc.

4. **Metrics / Insights** (premium)

   * Approx. “days left” per item

   * Recently wasted items

   * Items likely to run out before next shopping day

   * Recommended “Bulk Foods to Purchase” list

Each item has:

* Name (from Ingredient Dictionary)

* Quantity \+ unit

* Last updated / last purchase date

* (Optional) “Est. days remaining” or “buy every X days” (premium)

  ## **5.4 Ingredient Dictionary (Core Yellow Block)** {#5.4-ingredient-dictionary-(core-yellow-block)}

The **Ingredient Dictionary** is a shared knowledge base of ingredients.  
Recipes, Pantry, and Shopping all reference it.

**Fields (Conceptual)**

IngredientDictionary

\--------------------

id

name                    // "Tomato", "All-purpose flour"

default\_unit            // e.g. "g", "ml", "piece"

category                // e.g. "Produce", "Spice", "Non-Food"

default\_shelf\_life\_days // typical shelf life

is\_bulk\_candidate       // bool

is\_non\_food             // bool

standard\_units\[\]        // e.g. \["g","kg"\], \["ml","L"\]

default\_purchase\_interval\_days (nullable)

price\_per\_unit\_hint (nullable, future)

**How it’s used:**

* When creating/editing recipes → ingredients are linked or created here.

* When adding items to pantry → must choose from this dictionary (or create new).

* When generating shopping lists → items are grouped by ingredient\_id.

* When computing shelf-life & spoilage → uses default\_shelf\_life\_days.

Any new ingredient name from recipes or shopping should either:

* Map to an existing dictionary entry, or

* Create a new one (with minimal fields, improved later).

  ## **5.5 PantryItem Structure (What’s in stock)** {#5.5-pantryitem-structure-(what’s-in-stock)}

Represents the actual inventory for a household.

PantryItem

\----------

id

household\_id

ingredient\_id        // FK \-\> IngredientDictionary

quantity

unit

is\_bulk              // bool

is\_non\_food          // bool

is\_leftover          // bool

related\_recipe\_id    // nullable (for leftovers)

leftover\_servings    // nullable (if is\_leftover)

created\_at

updated\_at

last\_purchase\_date   // last time this ingredient was added

estimated\_empty\_date // premium, optional

**Notes:**

* **is\_leftover** marks items derived from cooked meals.

* **related\_recipe\_id** helps show “This leftover came from Spaghetti Bolognese.”

* Bulk / non-food are determined via dictionary \+ user confirmation.

  ## **5.6 How Pantry Gets Updated** {#5.6-how-pantry-gets-updated}

Pantry changes mainly through **three flows**:

1. **Shopping Completion**

2. **Cooking Completion**

3. **Manual Adjustments**

**5.6.1 From Shopping Completion**

From a **ShoppingList** (scheduled or Shop Now):

For each item with status \= bought or substituted:

1. Add to Pantry:

   * Increase quantity of corresponding PantryItem

   * Or create new one if none exists

2. Update:

   * last\_purchase\_date \= now()

   * For bulk/non-food items:

     * Update consumption metrics (see 5.8)

If substituted:

* Use substitute\_ingredient\_id and substitute\_quantity instead.

**5.6.2 From Cooking (Calendar)**

When user marks a dish as **Done Cooking**:

1. System loads recipe \+ scaled ingredients for that meal.

2. For each ingredient:

   * Find PantryItem(s) with matching ingredient\_id.

   * Deduct quantity, consuming from oldest entries first (if multiple).

3. If a PantryItem’s quantity \<= 0:

   * Set to zero or remove entry.

If a required ingredient is missing:

* Calendar/Shopping may trigger Emergency or Suggested shopping.

* That meal might be flagged as problematic (red).

**5.6.3 From Manual Adjustments**

User can manually:

* Add item (e.g., gifted food, random purchase not via app).

* Adjust quantity (e.g., “We used some oil that wasn’t in a recipe”).

* Mark item as waste/spoiled.

Manual waste or adjustments should still be logged for metrics.

## **5.7 Waste & Spoilage Tracking** {#5.7-waste-&-spoilage-tracking}

We want to track **waste events** for analytics.

WasteEvent

\----------

id

household\_id

pantry\_item\_id

ingredient\_id

quantity

unit

reason         // spoiled | expired | discarded | other

date

When user marks something as:

* “Spoiled” / “Discarded” / “Expired”:

Actions:

1. Reduce / remove PantryItem quantity.

2. Log a WasteEvent.

3. Optionally:

   * Show waste stats in metrics.

Calendar may show:

* A waste icon or color indicator on the date this was marked.

  ## **5.8 Bulk Pantry (Premium-heavy)** {#5.8-bulk-pantry-(premium-heavy)}

Bulk items (oil, rice, sugar, flour, etc.) have different behavior:

* They’re rarely directly tied to a single meal.

* They’re slowly consumed across many recipes.

* They’re often underestimated or overbought.

We keep **extra info** for them (premium):

BulkStatus

\----------

id

household\_id

ingredient\_id

last\_purchase\_date

estimated\_consumption\_rate\_per\_day   // computed

estimated\_empty\_date

recommended\_purchase\_interval\_days   // learned from history

**How this works:**

1. Whenever a bulk ingredient is **deducted** due to cooking:

   * Log a usage amount.

2. Use usage history to approximate:

   * consumption\_rate \= total\_used / days\_observed

3. From that and current PantryItem.quantity:

   * estimated\_empty\_date \= today \+ quantity / consumption\_rate

4. From purchase history:

   * recommended\_purchase\_interval\_days may be inferred.

This allows the system to:

* Warn: “You’ll likely run out of oil before your next shopping day.”

* Auto-add bulk items to upcoming shopping lists (premium behavior).

  ## **5.9 Purchase History** {#5.9-purchase-history}

To support all analytics, we track purchases.

PurchaseHistory

\---------------

id

household\_id

ingredient\_id

quantity

unit

purchase\_date

source\_shopping\_list\_id

is\_bulk

is\_non\_food

Used for:

* Estimating consumption patterns

* Determining when to suggest replenishment

* Showing “You last bought rice 45 days ago”

  ## **5.10 Leftovers in Pantry** {#5.10-leftovers-in-pantry}

When Calendar marks a dish as **produced leftovers**:

* A PantryItem is created with:

  * is\_leftover \= true

  * related\_recipe\_id \= recipe\_id

  * leftover\_servings \= X

  * quantity / unit can be generic (e.g., 3 servings, or estimated grams)

Leftovers are subject to:

* A **shorter shelf life** (based on recipe or ingredient rules).

* Spoilage and waste actions if not scheduled for consumption in time.

Leftovers can be:

* Selected by Calendar to be eaten on future dates.

* Deducted from pantry when done.

  ## **5.11 UI Flows (Pantry Screen)** {#5.11-ui-flows-(pantry-screen)}

**5.11.1 Food Pantry View**

Columns:

* Ingredient Name

* Quantity & Unit

* Grouping by category (“Produce”, “Meat”, “Spices”, etc.)

* Warning if near 0 or near spoilage (premium)

Actions:

* Edit Quantity

* Mark as Waste

* View Ingredient Details (from dictionary)

**5.11.2 Bulk & Non-Food View**

List items:

* Ingredient Name (“Cooking Oil”, “Laundry Detergent”)

* Estimated days left (premium)

* Last purchased date

* “Buy every X days” suggestion (premium)

Actions:

* Update quantity

* Mark as fully used

* Mark as waste (e.g. product spoiled)

* Add to “Bulk Foods to Purchase” list

**5.11.3 Bulk Foods to Purchase List (Premium Highlight)**

This is a separate view showing:

* Bulk & non-food items that:

  * Are predicted to run out soon, or

  * Hit the recommended purchase interval.

User can:

* Add them to next shopping list with one tap.

* Manually mark “Not needed this time.”

  ## **5.12 Role Permissions (Pantry)** {#5.12-role-permissions-(pantry)}

* **Admin**

  * Full access: add/edit/remove, mark waste, view metrics, manage bulk predictions.

* **Cook**

  * Can mark ingredients consumed (if manual).

  * Can mark leftovers created.

  * Can adjust some quantities.

* **Shopper**

  * Can verify that purchased items are added correctly.

  * Can adjust quantities if physical purchase differed from planned.

* **Member**

  * Read-only.

Solo user \= all powers.

## **5.13 Interactions With Other Modules** {#5.13-interactions-with-other-modules}

**5.13.1 With Recipes**

* RecipeIngredient references IngredientDictionary entries.

* Pantry uses the same ingredients → consistent stock & usage.

**5.13.2 With Calendar**

* When a meal is cooked:

  * Deduct PantryItem quantities.

  * Create leftovers if flagged.

  * Missing ingredients \= problem state.

* Leftover scheduling:

  * Calendar uses leftovers as a special “recipe source” item.

**5.13.3 With Shopping**

* Shopping uses Pantry to compute deficits.

* Completing shopping adds items to Pantry.

* Shop Now partial purchases reduce future scheduled lists and update Pantry.

**5.13.4 With Premium Logic**

Premium users & their households get:

* “Days until empty” for bulk items.

* Bulk / non-food suggestions.

* Automated “Bulk Foods to Purchase” list.

* Waste analytics & possible recommendations.

  ## **5.14 Summary** {#5.14-summary}

The Pantry & Ingredient Dictionary Module:

* Defines a **canonical vocabulary** of ingredients.

* Tracks all ingredient and inventory levels per household.

* Records purchases, usage, leftovers, and waste.

* Drives shopping lists and cooking deductions.

* Provides advanced insights for premium users:

  * Predictions

  * Bulk timing

  * Consumption rates

  * Waste tracking

It is the **inventory brain** of your system, with the Ingredient Dictionary as its spine.

# **6\. MENU SETS MODULE** {#6.-menu-sets-module}

## **6.1 Purpose** {#6.1-purpose}

**Menu Sets** are **reusable meal-plan templates**.

They let users:

* Design a reusable plan for several days (e.g., 3-day, 7-day, 30-day)

* Reuse previous real calendar weeks as templates

* Apply those templates onto future dates on the Calendar

* Automatically fill in meals for a range—like “apply this 7-day set to the next 21 days”

Menu Sets are:

* **Premium features** (green)

* Built *on top of* Recipes \+ Calendar rules

* A powerful time-saver and the “wow” feature for serious planners

  ## **6.2 How Users See Menu Sets (Narrative)** {#6.2-how-users-see-menu-sets-(narrative)}

From the Dashboard, user taps **Menu Sets** (only visible if household has premium).

They see:

1. A list of existing Menu Sets (templates)

2. Buttons:

   * **Create Menu Set**

   * **Create from Past Calendar**

3. For each Menu Set:

   * Name (e.g., “Workweek Light,” “Keto Week,” “Budget 500/week”)

   * Duration (e.g., 7 days, 3 days)

   * Quick preview (e.g., “Mon: 3 meals, Tue: 2 meals…”)

   * Actions:

     * View / Edit

     * Apply to Calendar

     * Duplicate

     * Delete

   ## **6.3 Anatomy of a Menu Set** {#6.3-anatomy-of-a-menu-set}

Think of a Menu Set as a **mini-calendar template** with:

* A specific number of days (e.g., 7\)

* Each day having:

  * One or more meal slots (Breakfast, Lunch, Dinner, Snack)

  * In each slot: one or more dishes (recipes)

It does **NOT** store servings or quantities directly, because we rely on:

* Calendar defaults (if set), or

* Recipe default serving size if no calendar default

So a Menu Set is mostly **structure \+ recipe references**.

**6.3.1 Data Model (Conceptual)**

MenuSet

\-------

id

household\_id

name

description

length\_in\_days         // e.g. 3, 7, 14

created\_by\_user\_id

created\_at

updated\_at

is\_public\_template (future, maybe)

MenuSetDay

\----------

id

menu\_set\_id

day\_index              // 0 to length\_in\_days-1

label                  // e.g. "Day 1", "Monday" (optional)

MenuSetEntry

\------------

id

menu\_set\_day\_id

meal\_slot              // e.g. "breakfast", "lunch", "dinner", "snack", or "custom"

recipe\_id

order\_in\_slot          // if multiple dishes in same meal

Optionally, you can add flags like “preferred servings”, but base version should use normal calendar rules for servings.

## **6.4 Creating a Menu Set** {#6.4-creating-a-menu-set}

There are **two main ways** to create a Menu Set:

**6.4.1 Create From Scratch**

User taps **Create Menu Set**:

1. Chooses:

   * Menu Set Name

   * Length in days (e.g., 7-day plan)

2. Enters the **Menu Set Editor**, which looks like a mini-calendar:

   * Day 1, Day 2, … Day N

   * For each day:

     * Add meal slots (Breakfast, Lunch, Dinner, Snack)

     * Add one or more recipes into each slot

3. They can:

   * Drag recipes into slots (optional UX)

   * Remove or swap recipes

   * Change the order of dishes

   * Rename days (e.g., “Monday”, “Workout Day,” etc.)

4. Save:

   * Creates MenuSet \+ MenuSetDay \+ MenuSetEntry records.

**6.4.2 Create From Past Calendar**

User taps **“Create from Past Calendar”**:

1. Selects a date range from the actual Calendar:

   * e.g., “Last Week”, “This Month”, or manually pick Start \+ End.

2. System analyzes Calendar:

   * Collects all MealScheduleEntries in that range.

   * Normalizes them into day-based structure:

     * Day 1 → all meals for first date

     * Day 2 → all meals for next date

     * etc.

3. User can:

   * Name the new Menu Set.

   * Review the auto-generated structure.

   * Edit any day/meal before saving.

This is powerful because:

It lets users **promote a successful real-world week** into a reusable template in seconds.

## **6.5 Viewing & Editing Menu Sets** {#6.5-viewing-&-editing-menu-sets}

Opening a Menu Set shows:

* A horizontal row of days (Day 1..Day N), or

* A familiar mini-calendar-style view

For each day:

* Shows meal slots and the recipes in each slot

* Allows:

  * Adding/removing recipes

  * Moving recipes between days or slots

  * Duplicating a day

  * Clearing a day

  ## **6.6 Applying a Menu Set to the Calendar** {#6.6-applying-a-menu-set-to-the-calendar}

This is where green magic happens.

User clicks **“Apply to Calendar”** on a Menu Set:

1. Choose:

   * Start date (e.g., next Monday)

   * End date OR number of cycles (e.g., “Apply twice”)

2. Decide:

   * Override existing meals?

   * Or only fill empty slots?

The system will:

* “Lay” the Menu Set onto the Calendar date range, cycling through its days.

**6.6.1 Modulo Application**

If:

* Menu Set has 7 days

* User applies it to a 21-day date range

Then:

* Day 1 → Start date

* Day 2 → Start+1

* …

* Day 7 → Start+6

* Day 1 again → Start+7

* etc.

In other words:

calendar\_day\_index \= (date\_index\_from\_start mod length\_in\_days)

**6.6.2 What Gets Created on the Calendar**

For every MenuSetEntry:

* A corresponding MealScheduleEntry is created with:

  * date \= actual calendar date in range

  * meal\_slot \= breakfast, lunch, etc.

  * recipe\_id \= referenced recipe

  * serving\_size:

**Very important:**  
Serving size follows global rule:

if calendar\_default\_serving\_size exists:

    serving\_size \= calendar\_default\_serving\_size

else:

    serving\_size \= recipe.default\_serving\_size

Menu Set **doesn’t override serving size itself** unless you later extend it to.

This means:

* Menu Sets focus on **what** is cooked, and **when**.

* The Calendar (and its defaults) decides **how much** is cooked.

**6.6.3 Overriding Existing Meals**

When applying, user can choose:

* **Replace mode**:

  * Clear existing meals in the range and apply the Menu Set.

* **Fill mode**:

  * Only add Menu Set dishes to empty slots, leaving existing dishes untouched.

Developers can implement this with:

for each date in \[start, end\]:

   for each slot in menuSetDay:

       if mode \== 'replace' or (mode \== 'fill' and no existing meal in that slot):

           create MealScheduleEntry

## **6.7 Editing After Application** {#6.7-editing-after-application}

Once applied:

* Meals appear in the main Calendar as normal scheduled meals.

* User can still:

  * Change recipes per day

  * Adjust serving sizes

  * Cancel or reschedule individual meals

These edits:

* Do **not** automatically change the Menu Set template.

* They modify only the **actual calendar instances**.

If the user wants to update the template itself:

* They must edit the **Menu Set** directly under the Menu Sets tab.

  ## **6.8 Role Permissions (Menu Sets)** {#6.8-role-permissions-(menu-sets)}

* **Admin**

  * Full access: create, edit, delete, apply, create-from-past.

* **Cook**

  * Can create and edit Menu Sets.

  * Can apply Menu Sets to the Calendar.

* **Shopper**

  * Read-only view of Menu Sets (to understand upcoming patterns).

* **Member**

  * Read-only, if at all.

Solo user \= all powers.

Menu Sets are **premium**, so:

* Only premium households see the Menu Sets tab.

* Only premium users can create/apply Menu Sets.

* Free users in a premium household can *benefit from* the resulting Calendar planning.

  ## **6.9 Integration with Other Modules** {#6.9-integration-with-other-modules}

**6.9.1 With Recipes**

* MenuSetEntry references recipe\_id.

* Changing a recipe’s details:

  * Affects future applications of the Menu Set.

  * Does not retroactively change already applied schedules.

**6.9.2 With Calendar**

* Menu Sets generate **many MealScheduleEntries at once**.

* They rely on Calendar defaults & rules for:

  * Serving size

  * Meal slots

  * Shopping integration

  * Color status (red/green/yellow/blue)

**6.9.3 With Shopping**

* Once applied, Menu Set meals flow naturally into:

  * **Shopping list generation** (via calendar → shopping).

* Menu Sets are great for:

  * Weekly routines

  * Bulk planning before big trips (e.g., “Apply 2-week menu set before grocery haul”)

**6.9.4 With Pantry**

* Because Menu Sets drive Calendar, they indirectly drive:

  * Pantry deductions

  * Bulk consumption patterns

  * Waste/surplus risks

Premium insights could later show:

“This menu set tends to cause you to waste X amount of ingredient Y—consider swapping one dish.”

## **6.10 Developer Endpoints (Suggested)** {#6.10-developer-endpoints-(suggested)}

* GET /menu\_sets

* POST /menu\_sets // create from scratch

* POST /menu\_sets/from-calendar // create from past range

* GET /menu\_sets/:id

* PUT /menu\_sets/:id

* DELETE /menu\_sets/:id

* POST /menu\_sets/:id/apply

  * body: { start\_date, end\_date, mode }

  ## **6.11 Summary** {#6.11-summary}

The **Menu Sets Module**:

* Lets users define reusable, multi-day meal plans.

* Allows creation from scratch or based on past real weeks.

* Applies templates onto real calendar dates in cycles.

* Relies on Calendar defaults to determine servings.

* Does not override Pantry or Shopping logic—rather, it **automates** the creation of scheduled meals.

* Is a key **premium differentiator**, offering powerful time-saving automation to the household.

# **7\. SYSTEM INTERACTIONS (FULL ECOSYSTEM OVERVIEW)** {#7.-system-interactions-(full-ecosystem-overview)}

This section explains **how all major modules work together**—not individually, but as a coordinated ecosystem.

It is the “mental model” developers must hold while implementing any part of the system.

## **7.1 High-Level Flow Overview** {#7.1-high-level-flow-overview}

At its core, the system functions in a continuous loop:

1. **User creates/selects recipes**

2. **User schedules meals on the calendar**

3. **Calendar generates ingredient needs**

4. **Shopping lists are generated**

5. **User shops and confirms purchases**

6. **Pantry updates based on purchases and cooking**

7. **Leftovers and spoilage appear in calendar & pantry**

8. **Shopping and menu recommendations adapt automatically**

Menu Sets serve as a **batch tool** that fills the Calendar with recipes in reusable patterns.

This loop repeats indefinitely as the user cooks, shops, and plans.

Let’s break it down in detail.

## **7.2 Ingredient Dictionary as the Core Reference Spine (Yellow)** {#7.2-ingredient-dictionary-as-the-core-reference-spine-(yellow)}

Everything depends on a consistent, shared vocabulary of ingredients.

* Every RecipeIngredient references a canonical **Ingredient Dictionary entry**

* Pantry stocks reference the same dictionary

* Shopping list items reference the same dictionary

* Bulk & non-food tracking uses the dictionary

* Substitutions replace one dictionary entry with another

The dictionary ensures:

✔ Unit normalization  
✔ Consistent names  
✔ Accurate shopping aggregation  
✔ Pantry deductions and spoilage tracking  
✔ Bulk consumption prediction

**Yellow is the backbone of the entire system.**

## **7.3 Recipes → Dictionary → Pantry (Before Scheduling)** {#7.3-recipes-→-dictionary-→-pantry-(before-scheduling)}

When a user creates a recipe (manual or parsed):

* All ingredients are recorded in the Ingredient Dictionary

* Pantry is NOT yet affected

* Shopping is NOT yet affected

* Calendar is NOT yet affected

The recipe merely becomes **available for scheduling**.

When the user saves a public recipe:

* A local, private copy is created

* Dictionary is updated with missing ingredients

* No calendar or pantry changes yet

  ## **7.4 Calendar as the “Meal Brain” (Indigo)** {#7.4-calendar-as-the-“meal-brain”-(indigo)}

The Calendar determines:

* **What** is cooked

* **When** it is cooked

* **How much** is cooked (via serving size rules)

When a recipe is placed on a date:

1. Serving size is assigned:

2. if calendar\_default\_serving exists:

3.     use calendar\_default\_serving

4. else:

5.     use recipe.default\_serving\_size

6. Calendar stores a **MealScheduleEntry**

7. These entries directly feed:

   * Shopping list generation

   * Pantry deduction

   * Leftover production

   * Spoilage tracking

   * Date labels (green/red/yellow/blue)

8. Editing or cancelling a scheduled dish updates all downstream systems.

Calendar is the **central scheduler** of the food ecosystem.

## **7.5 Calendar → Shopping (Indigo → Teal)** {#7.5-calendar-→-shopping-(indigo-→-teal)}

When a shopping list is generated (scheduled, shop now, or suggested), the system:

1. Collects all upcoming meals between two dates

2. Loads their recipes and serving sizes

3. Scales ingredient requirements

4. Aggregates ingredients

5. Subtracts what is already in the Pantry

6. Outputs deficits as ShoppingListItems

This is done for:

* Weekly shopping cycles

* Shop Now lists

* Suggested emergency lists

* Bulk replenishment (premium)

Shopping lists ALWAYS reflect **calendar plans minus current stock**.

## **7.6 Shopping → Pantry Updates (Teal → Yellow)** {#7.6-shopping-→-pantry-updates-(teal-→-yellow)}

When the user **confirms shopping**, marking items as:

* Bought

* Substituted

* Unavailable

The system:

**1\. Updates Pantry**

* Bought/substituted → add to pantry

* Unavailable → no change

**2\. Updates Scheduled Shopping Lists (Unique Feature)**

Shop Now lists **partially fulfill** future scheduled shopping lists.

For each ingredient bought now:

* The system finds all future scheduled shopping lists that expected that ingredient

* Deducts the purchased quantity

* Removes the item entirely if fully satisfied

* Leaves whatever remains for the future shopping trip

This is a key feature:

**Shopping early reduces future shopping, but only for items actually purchased.**

## **7.7 Cooking → Pantry Deductions (Indigo → Yellow)** {#7.7-cooking-→-pantry-deductions-(indigo-→-yellow)}

When a user marks a scheduled meal as **Done Cooking**:

1. Calendar pulls recipe ingredients

2. Scales them to serving size

3. Deducts from Pantry

4. Creates leftovers if applicable

5. Marks missing ingredients (if any) as a problem state

6. May trigger suggested or emergency shopping

The Calendar is effectively “consuming” Pantry ingredients.

**This deduction is the core of inventory accuracy.**

## **7.8 Leftovers → Calendar & Pantry (Yellow ↔ Indigo)** {#7.8-leftovers-→-calendar-&-pantry-(yellow-↔-indigo)}

When leftovers are created:

* They become PantryItems with:

  * is\_leftover \= true

  * leftover\_servings

  * related\_recipe\_id

* The user can later schedule leftovers in the Calendar just like a recipe

* When leftovers are consumed:

  * Pantry deducts leftover servings

* Unused leftovers eventually spoil:

  * Calendar marks spoilage

  * Pantry logs WasteEvent

Leftovers connect the **real cooking world** back into the calendar & inventory system.

---

## **7.9 Spoilage, Waste & Warnings (Yellow ↔ Indigo)** {#7.9-spoilage,-waste-&-warnings-(yellow-↔-indigo)}

When pantry items (food or leftover) spoil:

* Pantry marks them as waste

* Calendar marks the date with a spoilage indicator

* System can suggest shopping or recipe adjustments

* Waste metrics (premium) help users improve planning

* Bulk predictions update based on waste events

  ## **7.10 Menu Sets as the Automation Layer (Green)** {#7.10-menu-sets-as-the-automation-layer-(green)}

Menu Sets bridge the gap between user planning and the Calendar.

Users create or reuse a Menu Set:

* As a predefined sequence of meals

* For 3, 5, 7, 14, 30 days

* From scratch or by copying a past real week

* Premium feature

When applying a Menu Set:

* It fills the Calendar for a selected date range

* Uses cyclic application (modulo day index)

* Uses Calendar serving defaults

* Generates MANY MealScheduleEntries at once

* Directly affects future Shopping Lists

* Directly affects Pantry & leftovers (once cooked)

Menu Sets amplify user planning power:

**Plan once → reuse forever → automate future shopping → improve pantry efficiency**

## **7.11 Household System Integration (General)** {#7.11-household-system-integration-(general)}

All interactions respect household structure:

* **Only one household for free users**

  * A solo household

  * Max 1 user

* **Joint household (max 6 members)** requires:

  * At least 1 premium user

  * All others can be free users

Roles affect permissions throughout the system:

| Role | Recipes | Calendar | Shopping | Pantry | Menu Sets |
| :---- | :---- | :---- | :---- | :---- | :---- |
| Admin | Full | Full | Full | Full | Full |
| Cook | Create/Edit | Full | Limited | Moderate | Full |
| Shopper | Read | Limited | Full | Inventory updates | View |
| Member | Read | View | View | View | View |

Solo users \= Admin of their own household.

## **7.12 Summary of System Flow (Step-by-Step)** {#7.12-summary-of-system-flow-(step-by-step)}

Here’s the full flow in human-readable form:

**1\. Recipes created / saved**

* Ingredients → Ingredient Dictionary

* Ready for scheduling

**2\. Calendar schedules meals**

* Assigns serving sizes

* Sets cooking tasks for future dates

* Drives color-coded planning

**3\. Calendar tells Shopping what ingredients are needed**

* Upcoming meals → required ingredients

* Pantry stocks are deducted

* Shopping lists show deficits

**4\. User shops**

* Buys items from scheduled or Shop Now list

* Pantry is updated

* Future scheduled shopping lists shrink accordingly

**5\. User cooks meals**

* Ingredients deducted from pantry

* Leftovers stored

* Spoilage logged

**6\. Menu Sets enrich the Calendar**

* Fills future date ranges with structured meal plans

* Enables repeated habits

* Triggers future shopping lists

**7\. Pantry evolves over time**

* Purchases → inventory increase

* Cooking → inventory decrease

* Waste → inventory decrease \+ stats

* Bulk items → consumption predictions

**8\. The whole system loops continuously**

Everything remains synchronized across:

* Calendar

* Recipes

* Shopping

* Pantry

* Menu Sets

* Ingredient Dictionary

  ## **7.13 Visualization Summary** {#7.13-visualization-summary}

If we simplify the entire ecosystem:

\[Recipes\]  

    ↓ ingredients  

\[Ingredient Dictionary\] ←→ \[Pantry\] ←→ \[Shopping\]

    ↓                                ↑

\[Calendar\] ←— uses recipes —→ triggers shopping

    ↑                               ↓

\[Menu Sets\] —— fill → Calendar ——→ Pantry deductions

Or in a clearer hierarchy:

Menu Sets → Calendar → Shopping → Pantry → Calendar → Shopping → Pantry

        ↘ Recipes ↔ Ingredient Dictionary ↗

This is the **core loop**.

## **7.14 Developer Takeaway** {#7.14-developer-takeaway}

If developers remember only one thing:

**The Calendar controls everything downstream.**  
**Recipes define what is needed.**  
**The Pantry is the single source of truth for inventory.**  
**Shopping and Menu Sets are tools for updating the Calendar and Pantry.**

Everything else is just detail.

[image1]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAnAAAAHtCAYAAACZA0OjAACAAElEQVR4XuydB3wcxfXHz7Ys27Ksfr3YptnYkmXTOy7UhE4gQBJaCCWAgUD+ECD0alMCAQy4UEPoPZRAwJTQW2ih2iZA6LYpCYRA+H/f6vbYe9dPd7Jkv+/n8zQzv5mdnd2723na3Znx+QzDMAzDMAzDMAzDMJYGotHoWvF4/PxYLHacWCQSOZXwHLSZ2BXYddht2K2SJu8MyozR9RiGYRiGYRg9AM7bClorFrYdpzXDMAzDMAyjyoTD4ce1ViyxWOw+rRmGYRiGYRhVBifsfK3lgrKbqfSL3nQ2otHo+lrLBnV9pzXDMAzDMAwjCzhYr3jTOFIXBoPBGgnJO1m0eDz+c+KXYb/xlkXPcLooMziRSDzD9md7ddKnkLc54WUS9+YZhmEYhmEYJYAz9Yk3jVP2i1AoNJRwOnn74nQNT5bbOxKJrIHVumVx1L6j3Jrfb+3zBQBtMTaBbbZzdeK/lJD6xDGcEQ6HxxAeh239/daGYRiGYRhV4Mnllhs8b5VVtl4wfvzeCzo6TpjX2TmH+C0LOjvvmd/Z+QjpZwhfWjBhwmvzxo9fQN67hB+jf4j+Dvam5JN+lm3mEr/5rfHjj57X0dGh99UTdOc9Npyv97xpnLJ2b5q6p3jTLuiDJWT7Rp1nGIZhGIZRUXDGvtVapcGxe0pr1aSpqUlLRSN34LTmpbW1dZjf76/XuoZ6+mV7HGsYhmEYhtFt5q+44gCtVZrXm5sHaq3a4DydE4vFniP8HXYRdjnpawhvwi6Nd80RdzrhCUk7OWaDDgzDMAzD6O28NX78CK1Vi/mdncO0tqSwO2OGYRiGYfRZ5k+YsKnWqsU/xo4dorUlQSwWexhbW+uGYRiGYRh9gvmdndtqTbNg3LjVFnR23u7V5o8fv5I3/eaoUQVfOnsnGu2vtSVBJBLZKBwOj29ra2vVeYZhGIZhGL2eeePHT9SaBidvEg7cBW92dOy/QOITJqz4+tixHa+0t8fnjRt3wnujR9dQ5n69neb5CROq/q5dIXDcVpMwGo3KdB8f6nzDMAzDMIxez/z29pjWqsX88eMHaW1JEQqFlteaYRiGYRhGn2BBZ2dYa9Xi9Y6OXjOIIRqNxrVmGIZhGIbRJ3h77NjI0z5fP61XgwXt7b3mnTO/3x/SmmEYhmEYRp+hmPfXustbnZ17a21JEo1GW7RmGIZhGIbR53hj3LjWN/PYGx0drfPGjWtpTyTu/3D8+GZfJPLhp+PHN77e3t6iTcqKvTl27PJvYXpfFaYfDtkeWqwE4XB4Zeo+SOuGYRiGYRh9hlgs9hdvOhQKbYiTs0TnVKNN72itklD/NK0ZhmEYhmH0enBiHtGaF/I/1VpPUW0HKxKJHKs1wzAMwzCMXktbW1tDPB5/RevZSD5uPErr1Yb2Xak1gbasGQqFRkgcJ+z/VLY4fttrLRuUO1NrhmEYhmEYvRIco7txgjq0XggcnuO0Vk0SicQNWhNw2jolpD0vcyyzk/EbkktpnU3+zoQXc4xbktWfMo+nVZCEMsdrzTAMwzAMo1eBI3NpOBwuetQoDs6LEuIIvS3h8OHDh+IcbUj6qVAo1C5aMBhsTJb9obwzhxVceqtYaO/FWssF7cg5mTBtrtWaQJtP1JphGIZhGEavIZFIfKe1QuCovYAdgSP1NA7b6sR3wOk5UvII/yAhztHG6JviQK0mozqx27D102sqD+o5SWuVhGPo8cfChmEYhmEYBcFJmYHzdpvWK4Xf7+8fDoershIDDtzftVZJqP9srRmGYRiGYSwx4vH4IOw7HKysjw8rCQ7caJzEeRIPhUIVXcoKBzTD+eSY6rHWSCQSwuLse3nKjSI+EqcsSjwATbW1tTkfq1LsZMoHtG4YhmEYhtHj4LTdhwNzPeEDOq/asN9ncIy2Yd+v67zuMHLkSBmIkNdWWGEFmfT3pzhl/ZuamgY0NDTUDB8+vAZHbqBr5A2sr68f4OuhJcYMwzAMwzAKkkgkvsFJ+Z/WexocqsU4UyW/c9cdwuHwijiQ/9K6YRiGYRhGjxIMBhu0lgscpq9wnBZgzsS8hANxaLJaIBCo09tXEvZxuNyFw6H8WudVC/b5cjI8TmUZhmEYhlFt6IDPxQ6j84+Gw+FRxNfIYqtgo3ESYliC+Eu6nlKgjo2lDuxx4o8T/hW7n/jd2K3Eb06G9ybznvLYc9iL2CvitGDzib+TtLexf2D/RL9D7zcXOGMy4nMvrSfpV1tbK07Y4BEjRtRls1AoNHjQoEE1UlZv7EL9o7FbtF4MMokux3MDFpXPyWscK3J8DOEahBsSboq+NeG2YmgS/gBtMuG6tGG8bCPbwj7E39T7Kwa2f4zt145EIlvoPMMwDMMwqgyOSb3WiiFa5ohFHIoee9RXrMOEE3Oj1qoBTs+9WisGHOtttVZJOE87aa0YOJ77tWYYhmEYRi8Gp+dVrRVDY2PjSK1VCxyTotbe5Fhu1Vo1iEQiq2itGNiuLCe7WDhPzuoKPYk48hzXRK1XmtbWVrk7+bHWDcMwDKOvk5r2gg51n3A4vK4304VO8CaV/tybTmora00TDAZX1Vqx4Gj8Umv5oPyubpy2yWPI99B28ZYR0Iu6Uyew/VZaK5ZEIlHWhLvsM+u7eaFQaJzWyoFzc5fWikQeG5dMd+/CxspY0YFt/qE1wzAMw1ha6B8IBEbT2c2ik53l9/ujIra2tg7B+ZiNI3GGWzCaHPVI+AN5Dw3HzO/m5YPym2hN09zcPIg27EvZc3BSprS1tcVwLifhXDaQbpYy5P8EbSW9rRfyd6Bt8yj7geukUec2HMtJ1DMAG4o+NZZl7jOBczGSvCfY5sfYr0UjPJltzkY/WNLs4zfJUN4n2ydZ5rhUJR7Qx2qtGKg373JZnHt5F24njmd52jaTtqzPudpZ8lpaWgLk7YGW0+nhfHyFvStx2ijvIc5KxscQ/7HEBw4cOID4/pwTv0wPwr4meOsoFrYt+hywvw7aPo19rSj7k+PiWOWlP2fNVtp3BCbvaIb1ttngnES0ZhiGYRhLDXSIeR0jgU70C8p9R8cv9iDpm7Dz0I4UBwe7NtY1MOFVwn8ny8ljs8m6Lhc64+2w63AYnVGbbHc19lOckIRbhvQDlLkw1jXAYSbxnG1lX9tL2L9/f3E+rpJ26TJCLMcdKOqeKCEdv0xgO0Li4kwQb2ebawgbqHN7tBhld0S7lrLD0bK+G0ZeTGvFQP2tWhPY/0bs03GwKDOWNrxAehf08ZgMzNiPfcqgk2vyjbAl/49aqxbs6yOt5ULOM8ewPbYZ5/SKpLYZx7IS35EQ34t+1DeR/A69bTYo+x+tGYZhGMYyBR3qa940nePHOAtBr5YNOt/xWqsW0Swv59PujJUSaPufteaFNg/UWjkMHz68XAfOuetYLTj+i7RWLdjXzVrrDpybFq3lAufvQq0ZhmEYRp8kXuYKAjhHf9NaMUSLeIRaKdjXuVrLBufAWZaq2iQSiSu1Vgwcx1CtVRKOv6x2lQMO3G5a6yk4jwdpzTAMwzD6JKFQKEAH/p08Aox2veuVZuTtTqe7H87H3qR3SWpzdT3FIvvSWrVgX0VN28ExbaO1asB5vE9rxRCJRH6ntUpCu3LNgVdx+B7t4cbZ78p8Rv9Cu5j4bOKXcaxXEl7NZ3Id+i3lGHXdiF1KHddgv/Ds77du3DAMwzCWWujwin48VQp00Pdgj2JPYX/H3sDmY29h72Ifs+/FhJ9gC7FF2KfYZ9i/MFkFQULRpIwMUpBtpa6nMZnod5rebz7o6NvZ7h3Cx3ACnsKexJ7wmKSfw17GZNWDV7E3xdju9VjXxMLu5MKvYa8m2/OCpMn/g5TB5up9F4J9NMS6Jid+Ans8R/u0Sb6US5lsTz0ycbKc+0ewtznetfT+qgnt2N2Ni5P1fU51iHpGLrPvM715hmEYhrFUQgcb0lpPIg6H1qoFnfsXWssHjsEhWisGzumMZPiNzisE2xT1CJByo7TWW+A8px6h0s6yzmEptLS0pN5f5PvUY+/6GYZhGMYSJRwOF5zbrVrgJF2stWqAI/Eddo/W80HbNtJaMUQikQnsawFW0nx4OB/fYc9qPRvRIkdlLgk4hr049jjnYU3CtHcUY8nBFORdyzF8TXr5pH6cW4btnXn4KCMjbqdhMqXLdDc/H5S7TmuGYRiGsdRBhycd6Ryt9xTs/zCtVRr28Xq0yCW3vLBN2Xe5cIrXwhF5ibBd52VDHsOyv/mJROItnZcNjmkVtilrkt1ioP7Nqf9T2nMyjlTeOepcZIQy28mj4L3Z9st411x6zt1IF9L3YLdzrL+Ld026vBw2Du20pqamIVKG9Mbs81w5f6Jjx6Otjf0JO5q8tEESjY2NqfNAXt7RxoZhGIaxVEAnuUTmzaKjdTpdOudtZU4znV9pOM5SO/YBra2tRU0emw+Oby6OzYpa90IZZ+UImcwYh+k5na9JOj6rDBo0qJ/O6y58FjKJcepRM+nByXAnbP/vS2ZC/hpyF5FjOJRjnprUTtLlKg3nwnH8BPb/mDfPMAzDMIzKU4vz0k5nv7rOqCR06quyn5JGoca7BkmUNf2Khnoe1JomFAptJyFlj9F5GhyWNbFFWu8u7PtNnMi889FxXjKWV8NJ25Rtv2tqanIcSuL7uXm087TvS1YHHMbUcmPsu6ypbwzDMAyj11JTUzOopaUliMOUMdGti9/vb6IT7JE5w3AGnqGDr/ojVPbztdYKwTbryeM9rZcL5/Qizm2j1l3Y1wKt5cPrJFUCvhNFTzNCW51HqoQH0Y5TdD4OlXd92mdw8PQkyf04FwPIG0jeIPY9GBtCfXWy9BlhPed/GHn1lBmKDZEyaLL8mizx1d+tiDJ17C81bQ3bvuHGDcMwDKPPI46ZG6eTuxjbhc7wbjrAjBf1IyWsZdkd2I88PnWWiaoWgUBgoHYycAT+gibTbTyKPZK0v2IPK3soaQ9i92P3su1dhLcT3oLdwXmcK2WJvx0MBgd496Oh7PNYhuOFFm9sbJRtZTmwD1R2P5yXZpyUUCGjHYFBgwY5jzy9UP/G5Dlri2aD+gd50zhIYyh/rFdT5H1063XgehrO34daMwzDMIw+S1NTU2q6EDr03UkPJpQBDPviRG1Gh/1bOvJtk/kVXxCc+u+Kd80L9yTxlwnn0dHLvGcLsDdiXXOsyXxqz8S6nClxqoqaUiMf+o5MvIqTDHM8i7WmoT0vc1w/9WqkHaejmm3jM049ZtSw/7T90o47aedefB9komfH+eUfgOWJr+Ep8+n3W6SzJB042viZ1gzDMAyjz0IHvrXWhgwZIguFD5M4HbITJsl7h6VU6NDL7lRp1/laKwU69JLmfusOtPUPWssG5f4RCoUcZ4hwpcGDB9dJnM/i2/SSlSMYDOZ8bF5XV5caBCDQvhbO22Da1ipx0fTdRfJzzh/odeD43jWLg0j5zdDlTmIlrEWMOhup/wDvvtGWyKAcwzAMw6gadG6jtZYNOsWi34cqBn2Hx4X2OCMUcRLelxAnIWPKDfJKmrvNS2tra0JrGtrWqrVc4NDknbaDtt6qtVyw33extbDU6Fh9By4cDu/OObrTq1Em5k3TJsfZJkyb6oNyZ2Mpp4vPNO7GZfQq9f7aTVeaRPo7cDnfP6R9eQdMFAv7e88Tz/pdMwzDMIylCjrRNen8HceJTn0drKDTUyrZHDictSHoR2AnRpMjKon7dTm0sldqoDP/r9bYb9pAAo7/WZybndnP2YSrBAKBQZSJko5jMgfafk0gZXGofi4h+s2Uk8EeaY4udV3vTRdCHDbqSI3A1c4H+duTvyvn53ra4UxpQhs6+Lwi6I6zKG1Mlj2dMs5dVMr/DDue9FC3LrajSPzP8a73/54nfFv2pz8btP29dy3JT02BQh1pTiLtSHssy3bt7HN36v6Jq7H93RKi/SmZPpQy7ZTdAu1fbjnqWhdtExmRTDiZMmsmy59FehvSIfISpA/m81mO9HJs77w/ifayW48+h4ZhGIZhlIl2EkqBbfPOi0anPooO/jdumk79db/f7zgujY2N3sfC4iREmpubg15NWH755ftTh/P+3+DBg2vY5++pt788dqauYdQ5UfLQG0QnHE35Ua7uQvpSbzofbD9fQup60HVuqul8cOxp58KFdqztTdOWZ2mTvId4t5wT0ocRPw/bEHPmdnMhLevEyuoRMvfbx5is4XoZ+l2cu4eIy5q3D7vlOXdbodfJ41jq3ir6/WPYfuI4SyQ5OnUt8lbw5Dt3EmWwBdoPqKMNG9PW1uYM2JB9J8tl3MU0DMMwDKNMtAMXS949KgY65+e1JlDHpXTWjXTq7lQfzqNEOvgDyRtEB78G8dXp5GWuuYuw1Uh3Eh4bU3fONN5pKkpB9qO1bFDuNm+a43iatl1eTQcOB6noR8XdheNZxPmfInGO6V6dX4hIiaOg2cc/3Lg5cIZhGIZRIbQDRyfrLN0VDAZHEr9cHg9iO+LEyLQmq3nLoj3iTXcX6n9Fa5WCY3k77nnvzAUnM21QCA6inhdNtv0SR6Rqgxio+0WtuciIZK0Vgs9lC625JDzvwHFcD3nzsiGfMQ5mDd+HGj6fb9nGGflKWC/njvyc8+cJ5KceoZoDZxiGYRgVIlenSse7txuPJRcrp6zznplHf92bzgcOQMb7ezhLDcmo41iRXlX2S731hM3sz4/TECUcQXpF9DE4DZ2kO0hvi41Ck8d5IwkT8i5WW1tb44gRI+rERo4cKRPPSp5zjHJ3jfSxlNsn1Qifr5b6JtG+oex/LfKCLS0tcmdwHexItxDbvYXz802s6xHmk2wjj1fvJH53vOv9tduw67HrsGtzmOTJlC0PU5dMxyLx+zxtyYD9Znw+aGv7/f4w2z9ImzMeO1PnJ1pz8TpwbJ93EAr521DX/7G/8whvIpyBzUE/A9udz6LgwJuY5zF7Ne9iGoZhGMYyBZ3wpjgtT9PRioMk62VuTkf7IzHSP8P2QjuAjnsPwh2wDXF2QqQPHDJkSM6Rn+SfQb0ylcSlxM9hP84ITeI3x5IrFcS7Xu6Xl+1lFv9D0yooANteoTVN3DPNCfvdijY4722Jo+bqseTgjObmZrnDtBzpH0iabWXCXCfuIu3FXpI452BUY2NjvTffhXP3tNZ6Co5zN1/SIc6GcuB+5s2rBuzjfjduDpxhGIax1ECH24BT8A4d3QK5W4Hdi12Ndjl2GXZpMrwSuxMnQ1YpmIfNT5ps9xZ571JdxuO/XFD+WxyZFbReKTiu0bI8VSAQkDnLVnUdOBf0lqamJnk0J6MnB5Bug9TIzELgDFytNQ3n6odaSyITJZ+oxWJgu+ns+3OOKWPuPhfyn9Fad+A4ZmktF7SrSR55ss3vdZ7gdeAEPiMZ1SsDHdKM74dr32L/xf6TtK+T6W+SeWL/85R3jDr/w2c+xrsvzl3GyGPDMAzD6HPQoV2stXLBGXJe7qfzfMyrsw9nOgg6alnP8u90rOt783sSOvTUfGfdheO8UWvZEGcEp8a5I8Xxy1211Ev1pdLa2upOBfKpODI634V95h2dWw6xIqZsoUzanT/SGRMlaweuJ6E9C7VmGIZhGH0KuWvmics7WY4DhpMwEGdM3sHaIVXY5zgN2wSDQWe+sWyQLx28O9pT5k1bIdY1wlPWCD1dFS+VskZ+amjHZVorFxyRtNGi+eAcXI2JY1v2KhZs72xLKHc65VjuI/54eqkuEjlG53YXPtP2eNco0uVdjc96ZewFuYPpLetC+VNoTypvCTtwZTvPhmEYhtErkMdMErrvZdG5nU1H/DSd8+6hUEge8Y0mfrR3G/RVKCcvzJ9Ahy3va+1CmeMJTxEHjnCVZF13yZ0nwsvIP0DqaWtrcwcMFEScAbZdE9uUfe1G3acS3iNOJNpGxNcjvp7eLh84pRmDGLoDbXAmoc1FQ0PDQNr4Z9orj53HxYsYcZkP6pE5146QOPVelwyl/oypODj3L2it0nBMa0Y965/mw+/3t9KmWyTOeZjnzSN9E3n3cxy3YzdifxRHG5tFfAb2e+JnEU7DziIuAxrkH4M5hFcSXkc7biF+p9TjGun7aOMo774o67w/aBiGYRh9FnGwtFYp6CiLWvezWKjvF3TI19NRR7w66aIfx1I2taRSJeD8zdUayLQWf6O9v9IZaN9orRTk+LHbcbjTBm6gTcbe9mq0LTV1Rm+Cdp7DeTgYO1XShGW9B5gLHLbU4JBs8NmkJg42DMMwjD5JNgcukmOd02Aw2CZ35bwa24+jQ8y4+yPQMd+gtXLAWXHmfZO20vkvZn9Pykvybj765O9L56XsR5e5YN+PeuI/on2vNzQ05JwzjXPbwXl5U+4ccRxz2eav2MNs9xDpa5J3lsTOT9oF2EXk3R7vGjxymK7ThXpkWa3UPHGkX/Xm9wZo33yOZW/sF562pj0a5xjlDusL4ogRHoPN5TuwFcfvnFf02Wy/eTL+GN/LsYTbRb+/I3metz6hpqYmNTAlpiZJNgzDMIw+RzYHzoVOcwO520OH53SWhDf6/f4V0B7H/iaOlXSudJhX04FuqbenzF+0Vg7U76x5SSgT2TrtZX9rk3anAdnYWz4XtLXi74Sx75eo92+0J7W2Zz7kfGmtFDjmtLVFNbRnb+wdiXOu3tT5vQXatjPnTB53fsf3KO2dSo7R+TzJXykQCIhzdhM2Ft2ZL07WmJWQc+nHTkZ37uQRTsOcx/cayg134/Eipn4xDMMwjF5NrBtrkHqQtT8zHlvROWd9ub4b1ND5fqlFufuitWzQuafNp9Yd2KfcQZP52HKuXpANym/vTVPH8fgvtTjGMg9cv9j3IzizDthg+4KPG6lzKvV8wvlfoPN6C7RtDzfOuXTXM60anJORbpxzeKY3zzAMwzD6HPEsKyDQ+Z/mTYuD4U0XC3U/qLVSkLbRuY9k/6sS7kwnLO9NPY++nzyuRJfHkZ3RLI/MNJTdSGulQh2b0Y4XvY9vacsb3jKFiKn3vWi7LOw+inp/SPxl4rLCwEz2lSCUQSJpozopl1qZIh+067Bsn21vgbbt7saDwWDGRMQc+6WcjzO8GumMCX/R5lL2Tq1rOI+plSL47jiDQAzDMAyjzxJNLpEkneDw4cPlxfiBdK4z6OR2a2trG0L8fUzmbjuQ0FkUnrKyGPydaLIklDMdBOk3hw4dKnfiXo0l7+pR/q+pHVUI6vw3TkzJ87jRzhlaK4Tf75fjuRaH7WSd58J5cqbzKBbaf5XWSoHt99VaLigrEy2nDWzoLdCu2z3JjLuNfF538DlP4hhukGXJSO9HWpzSfdj2Gj2aWZxecfAp85FXdxk0aFDqnxCp05tnGIZhGH0OOj6ZqsHpDOn81pWQjnAr7HLy2sLh8OqiEe4vd4mS26S974aDs2JyuzB2JGVPoMyJ1PuAt1wloN7PaMchWs9HMBhs1lo+qH9/juOq1tbWgnceYyWswypQ/hKVlqkxLvVqnL/U+1qaWJaRrbngOP5JeVnLdYktqZWLmGc0Luf6BG9ed6DejH8aAoFAmsMf78V3Jg3DMAyjaOj0Pteai+vUlUqswlOIuFDvQjr8P2s9H3TY/9SahnonS+fP8aYttVWImGeR9GJIJBK7e9Mcy1HUIQ7jHJKy3JcsPyXrmzahZ6yQwbEcq7VcUOffkuFK1OXEewu0KbXEFg7rWI7rQ9r4G+z/MLnTJiNVf0y4ObYetqo2yq2OTcS2oOxOhD/HDpI6yD8u3jWa9wvy0h47k57mTRuGYRhGn4VONELHdwB2NJ3etHjX9BUyQapMqPqHeNdo1Ifp/F7E3o13PVoVewP9JcKnsBuw06UTlTopd6t+h6u7xMu4e0I7MgZYCDhJw2JdI0iz5hdDvMTHxLRlptZKIabeT8wHbUtN70JcJl+u+Cjc7kCbenxFhFjXaiOGYRiGYRSCTvOaUCg01qvhMP4ikUh8S17ai+qVBudsijgKseRjStJyt+YOVaxsqKukO3DQX6bOYDuZiiVj8XZtUoayr2H/5RhKeiQdy/Jyf7yb7+BVGtrzFe10HsFXE1n+rRzn3zAMwzCWWXA+5F2sY8QhkTTxz7z5dKwXJgdQFAXb34MjlnrxnfpHeLIlfxNv2gV9sda6S7zEaUR6EtrmzJum4XxdrbUlDW1tiGYyQkYak7dOrGs5NZkoeU9MRiMfS94ZxI/BDqTsrmhbEl+X74asy5oCvVHvzzAMwzCMEqAz/aPW6HQfiXVNn/E8na901rIe66XocyWf9JG+rtGxt0qajrvF3Za8mdjpEmcbZ4oO0ltjT7plvKD/W2vlQl2X4pQ+Q3t+pPOWNLRtJCZrizqrE2g4V3dpzTAMwzAMIys4PDdrLRgMriQhzttE4jJlyRjiQ0SrqakZgBaXhdBx4F4RjfxTcZomSBztVeKD5K4LzsqGxEMQJX0PaWelhmpBOw7heB4nLOk9uJ6A8/IFbfuLOMY6T0hOEZN1CTTDMAzDMIw0cBpatdaHGYCT9FRTU1PRj3/LQeZBIxiAM7YejulOOIybE2ZdMsqFfHnkmHfRduodRJleu9yWYRiGYRh9gOHDh/txTibgqPwA2x7n4mfxrrU9D8VOQrsIh+laTBZ9vxI7EztC7rRhu2E/YvtNop5lk7Ihd+q0Vi7s/303Hg6HB+I4jcbkfaz7aedH5D9LfC7hnwlvw24ifhd5Cwn3omzAW5+Atir5/3XTbJOaciMf1Pd7jl0m7x0lacJndJlsUG621gzDMAzDMPKC4/EiTkTaKNXu0tjYKKso3E804+4Y+v5aKxccpm2p73PC3YPBYJ3OzwfH7bxcj7O2LvYW9fwlnnzPr7vgBG5EfTdqPRe0P2PEqmEYhmEYRlZwWL7QWiXBMYmwj7RBBqTP9abLgXr/RD27ab0c4l3z7N0tcep9C/uBLlMucvw4ckVNm0Ib7tOaYRiGYRg9AB12PTafTvsDwm/olL/CFpF+B3uZ+LPYR8RTIzmXFLRvutaykUgkamnv6rT70UgkcgLbPRoOh1chPEeXzQbbpjmJ1ONdh7Mk2PaYUChU0moN+eAYPtCa4E65UinYz66cs4JryHKu/qQ1wzAMwzCqDB1/1mkjNOLMaa2nkceGWqsWOH5buPF4GWu0cr52wwFyRstWAtrwodayEa/w5LMcR8F569jnE1ozDMMwDKOK0PkeLGE0Gl0JOw7HpUnSjY2NA3BAnKk5hFiJs/pXA9pwltaywTFtp7VSYV9TPfHHvXmFYP9vaK078Jmcr7V8sH+5K9ZP6+XC/i/UmoZzNFdrhmEYhmFUCTr7S5LhxaFQaB2cuKuxXwUCgTDhpXTezioFdNAPpm/ZY6QcEdrwa29GNmjztrR5BRnZyTHdQigLlv8Y60/6ZcIZaJP1dhrqOdqNs13Ry1/FPaNMKwH1Xe5N0/510C7watmg/Ts1NTWlVp/oLtRXcLAEbXtKa4ZhGIZhVIFiH43SgRc1xUSloX1eB+5sb14+ko8Sy14SieNNLQJPXa9683JR6UeJHO9CrYmjHfUMWiD9D2waznegtrZ2kLcsjuoa3nR3SZ7TvNC267VmGIZhGEaFwUnYj45ZViF4KHmH6u9ixF9IJBJPEH8AK+r9q2rQ2trqXcO0rDU53cfCSTKmCckGx36eG+dcFHz3jn1sqbXuwLGWvA5rIBDIeGxK2zOWIusO1Pe21jR8Xx7TmmEYhmEYyxYpBy6eZdqKcDgclBGmEseJ2jqpDcMBOiGpNUuIQ+ZMViuLnRMMaGtrq6NM6j03jdfxwSEp9Fg07c5Xd2F/u2vNheMZ48Ypdw7HMMmbnw2O5W9aKxd5PM05XFnrGtr2JuUatG4YhmEYRjegg/0vHfuvxIhPxRHYg/h22JSkTRYjb2Py5B2yPUkfWOnpKgrRr1+/AW48nuNdNNrmLLdFeHsoFJI1Tm/EDq2rq8uYvoM6fo39jPxzcUbGcWxZ52ajTGqiWuIZjzK9cE5e0Fp3oG0553XDKVqT/Dm06S7aLndHV8H+TPo40hePGDEiq9PEsRZ8f7BYiv0OxLoeAac+P8MwDMMwuk/G47ZiqfS7VQVIOQA4DgVHd+LEDMOJS92lKhf29agnnvMRsjiCWusOnNtfaa1Esg5c4BgO05oL+9wZB/Bk7DJJcw4P57jO1OVc6uvrB2otF9T5rNYUA4cPH97Y2trqp2w4GAwm2PfyOKqjJKTdCdHb2tr8pJsaGhoqerfTMAzDMPoUdIbyKFE67+XosM8krJU0zs8KdJht5N+BvhbpbQj3pEOdQufqTOxK/nhvXVXG68AV8y6avM+XdreJ9qe990b7nceq+aBManAH9b3rzfNCuVO01h2o759a09CerbRWDJyHnE7c4MGDXcdvIOWcc8jn7X13MA3aOU9ruaC+D4s5592khn2U/N6gYRiGYfQpXCeM8F462N9iv4t1rV4wnrjjIBDOSZaZTl5qLjCcpNXdeA/gdeByOlIutHM72jee8JKWlpYw4Tpy94Zj2QBzpkKJFbEYe9wzlxvbLfBkpWA/jhNcSbINhqC98pj7BKyTtuzPeTgHh9q5g0r5Kd6y8S5WSG63i8p7x5vuDrTjWK1lg33+3o3jEAZobx2fx1BvmSQDJV+LLjWgtWzQrtT+DMMwDGOpg87dmcC3WOiIQ574p3TEEz3Z1cTrwL3nzSiBkh8Xe50dztXr3jyXfHfmaOukWPIxJM7WWoFAoOC7YOwzq0OIU+IMziC/CbuC9MrUOTqpbUe6Xu6gjhw5sq6pqWkg+22XPLRZ3npcKN/CdlGJU2ZD2vo82yyvism8eTnndeN4inKoqOOXWmNfMj/fVZHkgAzKHOXmtba2yjJoJ9LGxwn/usIKK/QjfgRlRyS33ZX06W554mnOOOl/edOGYRiGsdRBx/1br8ndCzrTO+gknyFcjH1Hx/kvQplO5GIpQ/x42Zb04eTJ4Iav29ranEEEVcLrwGVdB9S9s1YIyq2vtVxwnKl9cZx/9+a5xNWi9144L08S9GPb3ShXs8kmznzIeaGcc8ezu+DcRbTmwjm4GRtO++5P3pk8hvhJbDOO83sHody1/CP63dgOxJ/WdbiQv7fWNGy/qtaSpJxqnLZhMc98f0lq/H557a1rgIpLKBTaGn0w+14vKaW98xcrYukvwzAMw1hmoaNcR0KcDnHwFtIJN6K9RVxGRkrnL47g3di9aPeLjvYw6cfEuSEtTuLzSXsB7RnsuVjmlB1eBy7rYALqdQZV0Ll3sP2vxbGgPXF8kenUfZU8fkN7E/utlEOXu2PStgPTa/oe8j7yxLPegSsHnI9sjw8dch2fEAwG3YEjrsPiODxNTU3izGwQ67qjWsxdvoq9J0Z7/6I1Dfub4MbDWdaGpe0jtJYLjrHg9CU4zBV7TGwYhmEYvR6cn2Hxrvff5F2xjbBVML8ulw061rHifGm9HGiDftG+4B04Ou1fYnJXaSRt3o/wONGJO06mrFKANhlnRx4xDsC5G0x5uUs1cOjQoc7gDU3MswoCRed781waGxsHe9Nss5o37UI7sj7K1HDsH2vNhbqvxgEanoz/Su6U4dQt179//0GEctyHSx7x9mjXmrbOI1ZNPMtqCpRfVc4L4RE6Lx/ZHE7qSBuhGks6+sn43nwWaXfUKO840TLq1NUoI06ufO5pzqoL21yKbeamqTe1Zi/6m27cMAzDMJZpBgwYIE6OfsSVBp35S25c3vnCUThWXkqncz1R7sDRKa9FfFM6WGftVcKpaMsT/hVLLZGF4+EsRF9XV9fKdg+yzRzqc5ws9qHvzhUF22+jtUJ471TFc7/8nzonHMMZ2PK092LMcUJjajQs6SuxGdjTq6++urzbdRJ1n0UoI373Qa/6+1vsI8OBQ5PJgPvThpnJ9KyGhoY05zQbfB65nCV5JPoIn+UhMc+cdnzeW5DeE30kJvMK7kV6I8kj/iu0tUlPoR2HItWQdh5Rk96D75KMYnXOd319fR15k2tqagZQfoycU3cf6LYKhGEYhrHsQMfnTBHiZeTIkak5t+hE15RQOmQ6U2eNUbSD5I4O9kN071qpXsdmSktLy3J03qNwpI5hW6dO4j+IJFdO8EI9e7DNyzgH32WxL6jHWXXBC/t3nITGxkZ3FGN/6pmJnS8JwuuSoTNwg/3+HNuVNuSc64w2pO6GEc/qOFLfbpwj51iJv9Hc3CyOy9duPu36BjtG4rW1tXWuTn0rUO7mcePGpc6TnEe0z910tWAfX2gtG7TnJq1pqOsPWhM4t0eS58yjR5jxGReC8/NDrRUL2xacK9AwDMMwlhrosH9CZzuCzlfeI3MexxH+ws2nY5Q7HV9R7i3CewOBQNq7XOKAeNMubJd6B6oYqPsKN862W1NvyqnBgcu4E9bQ0FDHNn/FZBqKKOVvaWpqclYjwNmTx4m3c0yy8sJIHLb1sa3QVke7Au087GJdp0A9qXfg2G9Wx4p6cr2gXxbR5OPEXJA/kfZuQ9vOIfydR99dQtp5MsclZfZF2yG1oQf0rAMyckFdw7Tmwrks6JxFPY86S4HPrlNrxcD+XtWaYRiGYSyz0DFehuMg9jc69Y+wu9y8WHIwAKFMAHs9ZW7EmbgZuwmTuNiH2A1ZTPJukm3Yx6WpHX5PSRP5sv/pWiuHuGcUajzHu2m092atdQec4gb2taLWNbW1tXKHMXWcra2t7vJZzh092rUj9fyO8G63jAfH8e7fv/9AHLAW6jmqpaVlCGXlDmwN6Uk4gb8aMWKEvCe4E/Vkff+PvKJGHlNfUXfTmpubG/h8myh/dqzrHb8hhPJ4/RH53unyucj1j4RhGEafgwthPRe1V7A/YLMwebR0AXY0dph0vlwkp3JBPoL48diZlLkY+yJ58S44ss3ou/B536A1gU5d3oFyPnu/359zRn6B78kjyfArnefCfm7TWpF4F7PPeDzGd/cw+f4qLef0FsU6HvH0eeCyro6Q69x1B+qcq7VqwDn6aSgUauF87M0+d+LzrkWbTFrm7pjZ1tYWJi13Y6/BQcxYviqew6nVsH3GXdNiiao53oqBdn2pNcMwjD5HtMAjmWLggr5zIBDI24Ebyy6J5MLmfEcGB4PBjXW+Cx15WXerGhsbUw4c3+eMdTVxQgbxHV2P+pvZv4ykvZj0oaT3wPEMkJYJYWUVif78MyODDJxBEtR1CXmXo22oqnQgL/WCfvIfmaywj6yjWMuFtp/gTYuTSFvPxYkKkuxH+vak7kxmS55zx05GxCZHkjoOKm3eJaYmayadcf56AvmO8NkUvLOYpB9laziW2gEDBsjo0qE1NTVDOC8ycXDOgTQct6ydmjEq1jAMo0/ChfN6rZVDPHNqB2MZJ5Z8dwzHwnGw+I7cm14iHcoXfCk+Gzho3hf9H/LmVZN4+lqor3jzvFDuM611F5yRPd24OKNYvTxmJpQ750+Q/yNMHjnLu3CpR6nDgDKv0qZDyLsf+yPbpdoe/X5JMJlgOG0lBdIHYNMkPnjwYOec49xmTIvC/mT0bGpZNcMwDKM6pM1SXi50CGdpzej90Hl/GfMsfN7U1DSora2tkY45iD5c7loQn0C4qmuS5vNuZ9sV6dBH4EBFRowY0dbY2OjMtUUZ+adAOvHRlEuNaCSe9+6H3EnSWjGMGjUq5cBRx53ePNI7e9Ma2ujMmyZQdi1vngvHm3VyWI7/YTfOsVVkjrtioa3naU3DsbnvvWWFOtL+eSN9fLRrqpPpfK5HEu4f7boLeQrnwFlWizJniaON9mfy/o/4VMJrol2L28urF9Plc/f7/XI30DAMw+hJYp45k7xwEc9YRNsl1zZG74bONs1paWlpafOmcxEIBHKOPBTo4N+IJNex5LtxZKSLrOt4usSSU3l0B44nrQ7acWty9YWdMHl8eDLf40vdfLS54nBQJk7o3EWW6Uxo6+bk/YRwO8Jj0UYTl7nHUuDApd7Zo8wT3jxNLMvcat2FOq9y4xxnKq4Je1Y3IN6BZZ00WBwwrbm4d1GLgXqyTqZsGIZhVJB+/fplDECQd0vcOB3Di1yQDyeUiUTXlYlVhwwZkjGBJ53ZPVoz+h507rvwOZ+AszIHc6b34DP38/lfIKsUEF5Nvtx92YSya7e1tQ2gnIxoTHtkRvoTvjep6Rrc9+DyQT1Xa61U2G/BfyRoS4YzQltzLrzOsbqPgNO2o57UC/TkPeDNywZl3tNad6Hd+0tIG+Wdvgv4PFZqBvZ1M3Ys2l6cV3kH8E7SN4hjiv2A8r+KeZYJ41j+58bJW0DeC266FOJFzA1nGIZhVIa0ZW2ywQW9gwtz6lFTNugAZGFuBzqILdjmcm9+scgL6XQe0uHUU4eMgEuQXhlnYXXSk6Jdi2cfT3uuI3yK8EO5uyEOQhb7Rh4RYp8lHQop+y5xWY9TbIHHXO0duYNAuIjtvsD+I52bWyf6x+SfTbvWoi2piVeXFTj+C7SWjZhnslqBc5X3/TchnucuUrGw31O1VgotLS1pn2kgEMj5Yj3tTU3yG80+HUcGtK/o6S6KgfoO8/v9Ia1rKHeG1lzI+0ZrHM++EsrvQOflgm121ZphGIZRPXLeeSgFOoGFXOxlEtcPcHRk8fF5Ese+xlzn53PCN+NdC5dfxgX/ZLZzRgMS3ybatcZmu7xv09zcnFq7sLdCW1fCzpZjczu8pQGO5Tit5SKWvAOkke+CG6e+x715uWCbkqeE0FCHM8FwNsg7F8c7RHtSL97T/ruw/ZJxZ54ziVPmF9imlE+tv6mh/PFunHJFDQaStUm921UCjutmOS6tFwNtyfo4lWOfSb3HaT0X1HOU1gzDMIzqkvEIlYvxrtjV9fX1GXm54GLvTD9A+BzW7alJ+iIc91N0fGtrvS/CccjC7+Jkb0t4JuFBhG3YNm1tba1Dgfgo9F9ic/X25HmXmTrZm5cLcbC0Vir5vnu0Y04yXMHVaOdLpA8m/BWhvO8m65DGiO+KXYJjdMD3NaQj27hx9pvzDpcmFArJwvLddla9sP/9qHOi1vNBeXHesk67Qd6mElLvHTpPQ5kHtWYYhmFUn4wLOB3TTDouZ81IOptwIBCQWdjH1NbWyrs1aYtvu6CnvQNH+aKdv6UJzlsDlnIQ+iJ8djJX2t85Dlm3c65opG8i3onJ4vGHU+Yg8sXRPzeWZQLe+PfzotVS7ti0zBxQzylaKxXadZLWqoW8KuDGE4lETscxF/ESHk8WC216W2vZiBW53qnAOc35/mLcVjUwDMPoG+DQNWtNiNs0IinoHLM6ub0RefyrNS/Nzc31WisE3wV5X9F5n43wbJ2vofyNElL2cM5dt+ZxiydXfBBwZpZLRvuFw+HUI3niMuq0xu/3yz5lcM4enAcZjOH8MyN3nkmnnPCWlpYm6r0N2939bCm7vJsvkJdzguJ80A55x7OsCYzzIZ9rMBjMWB2BY029q1oKtDE1ApfzN4L6F3rzDcMwjF4KHU3eQQx0DD/XWi7oACJ0eM/QCe7GdhV1/OhorhcnALtdjP38CbuDDierJfOdsp5tnqNde+m6l1Y45tU5F5djV2HXcPzXJ7rWH70Vuy0ZuiZp125P2p/kXEo+n+lZtbW1KceB8/gP777ywX73Z/u0lQGKxDs6tB/f1Saslvou4dhkkfqxtE2WgHpcBinQpqlh+RImJ6UV0E4MBALD0eR9TDHHQZPvR11d3cBIcgoUnKJEUk9zfEmXtSA72y2WkPplDrbdVXZ3GUj9X3KoQcJ5nIduTbbN9rLcXt7pUgzDMIwegoty2hqR5dLa2pp3XjAXOpMfs8+0tSZJf+5Nlwv1PKW17kB9v9NasdAhZ11+aVmC83cO58GZALYQOAaP4MD8n9aLIaoGkLDPldj3Nl6tEGwjvwNnEXcX6nVeI/DC93d52vo3rZcDbXw0i7YJlrqL2B1o5zGJrgE2P8VOoN4b5I6fLpcPtrmQOuTdTmcwB6G972YYhtEb4II8RWulwkW+qLssdCg5R6rFC8zSvyTg3CzTE5Li1JzA57KIz3exONnYV9h/kqEbl5UcvsA+pexCwj1kWzr9xzh/Ge/G5YKyh8Y9i8OXQjzHOqS0QRZdlzY+ybHMIP009jH2Gfal3J2Kd42cljL/ScZF+3eiawoZmTLmEdInYXdhn1LPjno/5cIxX6I1LzKhcPI85xxZ64Vy19FmOZbvsI0DgYBzZxKnM/UYnPYPIu9WjkXKfCXnIXk+5POTff0LOwrLuYpDTE0RYxiGYSxB6Eyu5cL8P/mPXSzZCcgFXTpv6Zjfw95P2j+T2t9HjBhRcB45gbKphb9zESvhThxlJ2mt0sSLGIGXDc5l1vcE+xLR5DtsAg5AxkAXTTAYTA1aEeeA79CL1HFvTK1Q8M5xvn6fTfMNWDTNN3Dh6b7axdN9tZ9M9w36brav9vApLaMWneqr/fg0X+3C03wDv5juqyG//6cnZQ600eCYOAvQLwk4xqIGDniR35jWisXv97dxbmU5s3HDhw8P63yNPC7WWneJ5hnYYBiGYfQS6KC6Nb0D2z+mtVzQMRxDZzwFhyAgdwfZdp1QKDSBPmgMHZY8GpNljiQuyyO1U+avhMd46yB/L/TfKO3XmCzwPdbVqFNmpN/HW84L9Za1ugRt6/Pvz3FebkmGO2DxhoaGWsLxSc0ZaIAj4Ux6y/HKGqmtnK81JM15Xp+4zAP4Oo5axV/QFz6e5jtSa+zvRPZ7IJ9ro86rJJyLgbGuO45/le+pzi8E272otWrC57FmPMddyu5And1e+swwDMOoInTO5bxY7kBHd63WCkEHLPNxFdxnS0tLI53IP2nf9joP/V30x8UhpK44ndgvsNWo+0ekxcH7gziE2J7EL491TZ3ijCQk7SyqTt4jyy23XMayYYWILgV34BKJxH0SirPB8UQ4b6twjn6PwzKB87S55KEfQf4LpH+YLDs9EAiEKCdLazlLMy2c5kt733HhdN8qaDmXW8Lhm7DodF/a6geLz/BlONmLp/kKTQ7cj/bV8B0ZxD8AQ2iPLAOWMto8lGMcRthIe2XFj9ZsJgMiyG+grnqpp6amxrnTyPmQfy7kLrRz7MXAuQtFuqZmyfvotNKwv69p/6paNwzDMJZy6AD21Fox0GnkXBy7EHR0G7F9zhnr6YR/q7VCUGdJc9Nx3M+0tbUNJlxd57mQJytMTCXcm/ZOFadG2o12uhj67whnoV1LKO8e3YM9nLQHsNsocxk2nfg02aY7j9cqRbwbk7PiqKzjxnHIsq4QgFM2F0duDWzWoum+yxaf7ntt0Wm+JuL34MBNw0E7DmevfeHpvusXnuY7J2P76b6i36+rFjircT5XP/aWzsvFkvhs+W5VdKS3YRiG0UegA9hda4WgUztEa6WCIzCSfe+s9Z4CJyY1Z5brMLa0tKSmU6EzzlhDslJw/j7VWk8ijqYn/sHAgQOdedQ4fhnFmPWdND6rzbFGzkuTq31yum9lb5lXJn4/5cdXuGA4bM7UFv+d7mv7vhTbnehLzbP25am+VH0uOHjdXvi+u/AZ3cl3tKh/bpqbm1spf0woFJJ1fk/Q+dVE/skQ07phGIaxFEPnLY+Kdpd4LM+C2C7yXpkvRwdfLnR8F2otG3SO3R5R64Xjfd+b5lx8JGEgEHCmxqBdRU2RUQ79+3unNut54l2T6zrrguKQrYjTsXZbW5sfR0TehZuDbYnN4PNem/M0jfhThKti+xB35kwTPj4l/XHox6f5Mh53fzbNlzHhbCEWnu4r+F2sNnV1dc4dXc7NeTpPIw5UNR3+bMjnotJxPq+cd5MNwzCMpQgu+j8p9g4cnX7Go65KQef3ktY0tPMtnLii5qMrBE5aRJwRNx1JjnKkHXPdO3M4KqnZ/SsNzoGWehSO0bkDyDFO1nmFiCWnEhEW5niEiiMX+HS6b4VPTvdtuXiab//Pp/kilL3ikxN9DR9P8122eLpv47fP8A0k/OMnZ/nqXz/VV+vdfuF033RveknD+cq7MgH5Peq8sb8vteZC3gVaMwzDMJZC6JCP5z/3jbTuBQdH7pIVdeeN+nbE1tI65H1HLZZclzMftFNm4O/E8Vgz1rXCwHja1oGNIb1SMBhcQRtlx5A/nu1WI74WoYxODeq6ZV3Y5BQr8j6bvNRfNS9r2LBhRZ3LajFu3Dg5359zHjbkWNfl/MhksEcSn044m/BSNHln70jCn2EbEE8Qnit36Nx6PjvTl7aCBw7Z/p9M8/1I4otO9QVw2iZj/1h4hm8Cjtx2i4/39f/uLl+/T6f5dls0zbeJlMPRSxtRLOD4Xam1JQ3fvd21tiTgO/qt1jSU6XXzLhqGYRgVho756XiBRavz5eMItNCpv0K0H/GXiV+NsUl8X8LXWlpalqfjXzB8+PC8j0DZttfcdaG9J40YMSJjhCptfJLjujjW9bi5X1NT05ABAwbIkkbXR5PvtbHtyXSgu8sUFDhqg+j4M2bHx1lcss9QK8SiM3w57wQVy8LTfBnvUy4+w/ey1noSPstnvelAIDCMz0z+GViRz1Oc1rQ7hi7xKi9FFS9wJ9BLvt+sYRiGsRSAM7IBndJorXuhM5inNRd3HdW2tjaZYuJsOrl16+vr5b2n/qTXlTycmonEZS3KGWkbeyC/6M6pmsgdJtpyNcec8biW4+qHvj35u2ETiZ+KszYgedwHtra2BjnGvbDZaHK3amfCY3U9S4sDJyyc5ntv4XTfy9jfsdcWTfO9v2i671PsC+zLxdN9XxP+F6fsK+L/Jv9z0h8QvrVYyndt9xzh49jTC8/wpTlPPU13HB+2rdq7e/Ey5mVjG1tVwTAMY2kE5+IzN46zkfcdt2g3pg0pBO0oOFVDc3NzPR3So9ht8a4pO8Rkmo6HcaLkLuKLhK9hb2HvYe9j/8DewF7GnuAY7pWOkG228taNdgh5Z+F4bUmes0ID8ZzLDXWXwYMHL9FHqEZuxHnXmhe+J1trzYW8A7TWXahzFA5/xuTFtPN88v4PcybijuWYToR/zmRev6XmHwbDMIxlHi74GS9eixOkNS9s83utdZdi7xJQLm3UaHfBQUt73MWxHTFhwgTZj7OMFw5fyaMnjb4PDtEzWuM7cWcgEHDuNPO9OQE7gu/LT3Q5ti15/sJ8tLS0xFtbW7M6X7TpUgljycm0adMVaQU8UCbvHXbDMAyjj8DFP+eL0Fzsn9KaFzqpQ7VWLrTjb1rLQ1aHivbKKgybat2FfWR9bBv3vE/E9jKpsLzDl3JQif/UjVeaYDA4UWtG74DvxdwsmkzoLO8+PozdKhrfmWt0OX4bzrx3lSIUCvm1Vi7hcHg9rRmGYRh9CDqi57SmcR/L5IJO7CitlQr7eFhrLq2trUVP4UFbfs4xXU+H+rBMD0K9d6Ed2tzc3EK4bSzHWq/of5WQbbOu50n+xVqrFOzzDa0ZvQM+mwzHrFgq7fTzO8iY5FhgP2tqrRAtwG9jBa0bhmEYfQA6p3e1lgvKfqA1L+TLMlQysW+p1IZCodRM/Lmg/jj1v+1LTjhbaaj+MTq0vC+st7W11dCGfRKJxC5J29ljOyXtxx7bUZmrS7md2ec+MjJV78foPcjdNq0Vi7yTprVuIneFR2mRNv5SQnlvE7utqalJ1mA9Bv1c7GRdnjKbBIPB5bRuGIZh9AFwIHKOJM0FncHdWtNQpuhHqpFIZDTmvJAdCARk1n9ZTBwpshLxTTGZekTWGZWBBrKe6CvSodL21LJXXii7vtZcwuHwalrzIg6c1gyD7+Igvhuf8E9GG9/BDUjvwPdsj3jXmriHEd+PuMyNtx1xWdO3A6e8CW0m8bV1fd2F34k/1yhx2pNayoz2nCIhbRjzfQnnd7DElqszDMMwukk8x3tgxcC2D2hNQ6dRcHADTtgqra2tWefP0tAxfUvHE9O6hnILxSmkjS/T4Q7p379/HdqWwWAwRJvexmRCXnmxPGMSYbZ5RGuG0Vvhu3yb1grBNmU/DjYMwzCWMLEcKxzIHQOcpPE4Po6jxMVephvISq46vFDfg1pzYT/raK1S0P4RtP2Apqamepy5vf1+/3DacgG2H3HnXbpYlkmCyX9Na4bRm4kWeOTvhe/8Ep1PzzAMw+gGXPBTj1i81NXVNZI3UeKEzThYccK1MGcKDQ2dgbPsUSHYPuMdO3ncNHTo0KxTIZQC9fxba1769euX890y2p8xpxta0Z2hYfQW+B38U2safodLdCULwzAMowJwMZ+vtVIIhUJrRCKRol+Axhl0FoYXEolERZ0kjmVPOrAzkzYdk/U6T8cZk1C0Gdg12N1eI/9GwtlShvgpHE9Y120YfQV+Y8vx2xqqdb7bm7p3nQ3DMIylAByfV7VWDHQGI7VWiEAg0NrU1JQxc7xhGJWlpaUl9Y8V/5xc4M0zDMMwlhJw4h7XWj5CoVBrJBIp2YFjP89iWUeNGoZRWXDc3sbe0bphGIaxFBGLxZ7WWjZw3gbhhO2q9WLA6TvIV6W52wzDSIffaU1TU1Od1g3DMIylBC70suRUmP/Wb9J5iv6U21iLpdDW1tbMfs7TumEYlcXv9xc1NY9hGIbRtxgof7KMuHR0TTgcHuFN44SVNRUB9XRqzTCMyhMIBGzQgmEYxtIGjttHOGELCQfrvObm5tZQKBRx05FIpMWb78L230iIU+Ys31MM0Wg05+LyhmFUjhVXXLF/U1NTxjQ5hmEYRh+F/8xlSaB3cN5yLhlF3gTsFsr9jmTOudrI/whnb5zWc0Gdv9CaYRiVh9/aXXGblNowDKN3E41GD08kEg9jD2EPYg8oE03yZB3RZ5qbm4fpOkqFDuJS6tqbUOZZ+0TnZ4N2dnu/hmEUht/luYMGDbJBDIZhGL0RHCf9DltJyALdWiuHcDg8GNuUTuPPOq9YOJYvtGYYRhfyvio2S15x4Hc7gd/LFaQ/lWsA4f/45+wb4l8n7b+STm7zHen5hPfI9mx7YCgUWrXFA7/dbbt7LTEMwzCKhAvxelorFS7yX2qtO9AJFP04NQs5H9UaxrIKv6k/aM0lGo3+huvAVVr3gnO2mdbyQZ3Xa80wDMOoIPw3fafWSgUHbqHWyoWOYrzWSoXOyt6RM4wi4Pf2Ywn5Df8ep2tsKBRaqaWlpZn47aIHAoFmtyzXikfRTyA8GIdvJ+I7u3ka6htKXVlHoxuGYRgVAGfnFq2VChfrz7RWLnQKu2itVOS9Oq0ZRjUYMGCADOa5j9/Ai4RPyyohfP/+RvxVwn+gf4B9hH2CLcI+xj7E3sPewd7C5mNvYq9jryVN4m9gL1HXE9R1gN53scSLe7d0gBvhGCayvwnezHKgjge1ZhiGYVQILrLdftRBJ/O51sqFzuN4rZUKx1RoMmHD6DZ8z35O0E/r1SIQCNTgjDl3xkohEon8QGs9AdeFWVozDMMwKgSd0HVZtGOyaGGtuVTSgaODcv5rx5F7O1s70Ed54qd681yo426tGUa1wEE62O/314RCoTVkQA/f26lJfUW+i36JNzc3O3MlJu8O95e5DLE1SB/q1kN8Ncqv0dTUNDAYDI4WjfSaElJ2b7cc9e7lxouBelO/GS+0eRh1/ZT8E9nPT8TEKcUOxI4g/VvXSIudwm/9NNKnEz+KNu2KXYztqOsW0JfTmmEYhlEhuBjfqDWhpaXF7XB2DIfD2xD+gk5lGBflE3VZLur/0lq50J5XJGR/5xL/WzL+MMEAwiPpJEO04VXaNIHO5xHJJz2dPOkQb0vWcX+qQsOoMnz3LuI7dwvfx//jexlNaldiJ0mc7+Vk8i5Jxqdiu5B3B+FJhKsn9bXk+43d2NjYKN/xHZL1TPN1ffc3TO6u5FHjlE9zpGhjLfX91at1l2Tb0x6Zst9uv89qGIZh5ICLbsY7cHQ27fhJcfLGJsskdBkvOHD/1lq5uA4cHdipdDQDsY7m5ma/dEK04zHSUwivw66nzKbs+3naewPx4ygzOVlH2dOQGEal4R+fMN/R1Kok3SWWuXRdXvTvl/Qp3nSl8Pv9dfJbdNP8Jrf05huGYRgVBGen4ChUyvxDa17iFZx7LZ58hKqhM1gDe1vr2aCDukNrhlFJ6urq6rWm4Z+NtVpbW9u8Gt9h966yrE6SwbBhwwpOg1PGHbiU80ib9vHmZYPyW1DuYpyxo4j/kLY+zj90I4m/pctqvM4l/1zt580zDMMwKkgxDlwhqKNio1Cp60itlQqdyDVaM4xKEgwGV9KawHfvKpydBpyfhDhvpOtiXe+TnUZ4udwxlnI4cr/FSdqRco6DR94Y7Jd+v9xsju+HXU466yCAbHfg0HK+b0ZewBO/x5tXTTgGefxrGIZhVAMussdprVSydSjlQl0555YqFjrHK7RmGJUE52uk1noK+b01Nzf3JzwMe4Tve7su40EGTLS6CeK/8WZqZAAFdXZr1OpQkJBry4U6zzAMw+hFcME/TWvlEolEnIlFuwPtyTurvGF0l7a2tqDWQqHQWlrDYdpKa8XCtpsHg8GMO2vuP0yEO2DPYTIAYh1sXWwSjtP+2NXYa9h/MFkGyzHyd1fVpUH+ehxHgH3/nPKvkz4Zm8Pv0k/4AfoTxFfR23lpaGhwHi9T3v6RMgzDqCZclMu+gyadgta6QzgcHsKF/4daLxa238TnmZTUMKpBXV3dMDce7xrJLSNF7+e3tAEOziFyh27w4MGNpE8gr584Y1KWMk8QP5D8EZIm/hdPPfKY9XDyjkiWnTFkyJBBlLmd+Exfcpm4mLrjnVw5IetUPpRdmfoa3DT72NObryHfWdeY7Y7FSc05dVAxUEfWEe6GYRhGBaEDWD+RSLzHBfxDbBH2GfZvtC/jXYtaf5romk1eZpEXe5dtMu44VAIu/LOwh6g/5YjRCfWjQ+k3ZswYb9EUtFEmOd2XznOEzjOMKuP9nqbumPEdficUCtW66aT2d09c5l67vqmpKfWI0wvf5Z+4cX4Lx5JeQeLagcsH263BbzU14IJ0SXPICewv5ayWQtxGgxuGYSxZuOiXvYyPYRiZ4BRtr7ViKcWBw4nahN+v806awLb7evPJWxFt62T8MJzJATidTWjO+2s4jRtJ6N6ZI6/N7/c3BwKBYWhyVzAn1PGE1gzDMIweJBwO23xOhlE6NThFO+DorNy/f/964lPlMSnOjzhIsqqBDBj4Nb+vII6STJZ9IGXO15VoqONbreVC6sVSDhzbZvwzRr47mbC0ZRXC31DOmYS4ra1tiM+zXBh5+1N+Q8Itae8+2JNunoY6XtCaYRiG0YNwsU7NAm8YRhfJ9y1z0tTU1BAMBuX9tOd8yffXhg4dKgME/ofjczF5I3CQ1pJls3Dqlkd7HafnTsIzVFVpNDQ0ZAygyAX1bYfDVeemiR/szde0tLQMaW1tde62FUPU85qDhn2/rjXDMAyjB6FDuYJOpscW7TaMvgDOyzS/319wOhF5z01r5UJdn2otH7RxJ36/KQeO7Q/z5mskHyfvICXXFEhnhbpe05phGIbRQ3Dx5zoc/yiWY1JRw1iWwUEakUgk5vP7eB97jfQrhH/HXuB38zDhXZjcVfsTeXdS9m7sduxm7HrsKuwayt4oOqHk30/4IPYo2z1L+CbhXGxlvf9CxLsWqZfHoG76cG++JhwOJ2QgEPuaQXvP4x+3AFqnPDqNJudXJCxqrkb2JXceDcMwjCUBF/IHuBD/m/BsnWcYRu9GnK1QKJRy4Egf5c0vBpy41FqqxAvdfUvlc914ypthGIZh9DBciP+nNcMwej/8dn/kdeD4R+y33vyktkBr2YglR6bmo7W1dbAbp/xj3jzDMAyjh0kkEkVPW2AYRu8BJ2pbmRzbTePQHevNF1ynLhKJnIjJHbuVotHoOS0tLTHSE3xdy3Fdy7b3k1eDJo9Xr8ZmqKp8jY2N3n097M0zDMMwKgwX5AhO2n5J25cL79HYRZi8m3M39kS8a1mef2KvYk9i93Hhv4zwBNmO0JmKwDCM3gNO1haBQMB7B+44T7YDDp77bt1Qfsc/xK5U+fFkdKBXz4a7DqpAPQ958wzDMIwKwgXdme+pEnDB/kBrhmEsOfh9rx9PH8QgS3uVBHXkXX7LS319vXfS4Ee9eYZhGEYF4YK+SGu54IK8nhvnP/ttJIxEIut4tB3cuGEYSx5+s6sEg8G8Dhxl5LHqIMJf8XvelnAEv+UTiN+JdbLNrlKO+EXURVb0lzIylXIPqqpk7rshY8aMcddstZUYDMMwqgUX5VvcOBfcXblYXy0rL3Ch7i8LbnOxvj2Zdzh5+0kcXcrtSV4b4fru9olEYrQbNwxjycPvdlQsfR64bA7cYn7Tw/g9+4nf50uuvMC1YWPK/wc7KRQKyQTEB0pefX19C9rr5N/LdlO8dVFuEDgjUbke2ChUwzCMasEF+yVPfCp2HBfq/RsbG2uJb078dMJDo10Tgh7NBXpzLtz7kt4Wm0Y8taYj8Q43bhjGkkfeb414VmLA8TrOk50Bv+mTtVYGzkjUuE3kaxiGUT24yD6rtXKhrtTjVMMwljxtbW2Dg8Gg9720tGlESM/EwUubmJff8URvOkl/9CYtZiMcDjv7o+7ndZ5hGIZRIbjIph6halpbW+W/919oPRdc4DfXmmEYSxZ+w/VunN/7b7x5OFtrySsRybx1+Q1fQnpV4rMTicRy0Wj0d8TPknzi97e0tAwPhUKroN1Evfv7/f6Ytz5B1oCVkDKP6DzDMAyjQnBRzrvCAhfrGGVk2hBZEuhoLto5R6Tl+M/dMIwlCL9Zx6ES+C0f6s2rBu6dOsI7dZ5hGIZRIbjIPq61bOC8nesrsIg1dW2mNcMwliz8dlvcOL/RAzz6r9x4NsLhcOqOOo5frn/cMuaG45++Vgmp/486zzAMw6gQXNCP1lq5UNdbWjMMY8mCI+V34zhie3niv08uXv8DkoMpdyF2t5svj06xjiFDhgyWwUzJbbZHm0N4qqyRig0nfiy2i7sdWpuEXA8yVmowDMMwKggX8X5cgPflwrwV4U8IJX4YF+CTsQuwlxKJxB+0oYsdyTaHkx6m6zUMY8nDbzPqxvmtzvTmVYPW1lbnkS3XhkN0nmEYhtGDcCH+vdYMw+gb8M/YSDfOb7nsdY2HDRuWmo5E4B+/vKNS2ddkrRmGYRg9iDlwhtF3SSQSK7lxeQTqzXPBybsSh2xtwh95tF2xrdFDkUhkJNeBlf1+vzxqnUw926JlvP9G3itunPLLefMMwzCMHoaL8iVaMwyjb4CzNcGb5vf8qTctUEYGKcldtQ1djXJnYxNDoVC76Ng+4uRR9myct6mtra2h72voAgcv4sbdOg3DMIwlAP9FX85F/DtCWWLHMIw+Br/dr7No/8XBqtV6ueDkrU59W3s10hmOomEYhtGDJBKJ74YPHx7XerHw3/rPcQIXYi/TcSzAPsQ+x76Vd3Jc44Iv9rXcISB8H5uHvYSdM2zYMGd9RsMwSoPfbkttbW2z1qtJS0tLau45wzAMYwkhzpXWSgGHbLbWSoU2nKQ1wzCKg9/PU/wOf671asA/W7KO8pFaNwzDMPoQ0Wh0rNbKpbW11e7CGUaZyHxuOHJ341y9x+/yWOKrYBPEIpHI+OHDh68sgxXC4XAkFAo1JxKJhlxGubCUZ9vxsj31bYTtTd3/JN2jd/sMwzAMBRfkzZMjzvYJBAJBnZ8NLt4vYK+wzYdc6D/FPtRlBPKf0loh6FhSo+kMwzAMwzAMBQ7WUVqLFbk0jjxylffmsLewjGkLyD8iGb7BfmZQ76befNJzvWkXyq6nNcMwDMMwDMPnOErvac0Fp+vVLNo+4rTheDnrJbL9r9084hNTBbtJS0tLvdYMwzAMwzCWeXDCbtGaJhKJ3I9j1oTT9jXxn+l8L9SXNgdVuTQ3N9uoNsMwDMMwDA3O2AFaywWO2WVaywVlr9RaqeAsfqw1wzAMwzCMZRqct1W1Vgi2uVFrhmEYhmEYRpUJBoPD4vH4BlqPxWJbNDc317hpymQMahBw4kLhcLhF64ZhGIZhGEaVSCQSqcWnvci7cNh+OGeJaDR6JPHbCcfocgJlMkaaGoZhGIZhGFUCx+xwrQk4ZY6zhtPmp8zq8Xh8eCgUWlGXE2QEqtYMwzAMwzCMKoKTdprWigXn7nmt5SI5N9wxOHyXsd2TxN/MZuS9jN1LuQtJH0f835FIxJbSMgzDMAzD8CKPS7VWCBysoldTwEl8X2slMkDe19OiYRiGYRjGMg1O3K1ay0UikfiG8pv5/f6BOg/Hbh0sbTHrSqyiEAqF/FozDMMwDMNY5sEpyzsxb1NTU104HN7Cq8l7cjhsP8OekMekhK9iM7D3KbtmssxW3m1cIpHIT8hLSBxnMO96q9Q1XGuGYRiGYRjLNGuuuWa/UCj0A4kPHz68U+fjbLXV1dVl3HHLBXWNlgEOgUBgh2AwOE7nu+A0rtvQ0BAivIp9nKXzXXAOI1ozDMMwDMNYpsHZ+tybDofDW3vyfujNK0CtFnDmhmqtVGhPm9YMwzAMwzCWaWKx2LZZtKexl7ReKm1tbctprVQSiUSz1gzDMAzDMJZZcNKqOpdbMBjcUmslMtDv92fc2TMMwzAMw1jmkNGkEg4dOrRe51WSaDQ6EidR5njbEdvONfQtsU2JT4pEIusSbye+AuE4SSe1a0Kh0Ka6TsMwDMMwjGUSnKOPcZjO1bphGIZhGIbRS8F5uxs7Lh6P5xz9aRiGYRiGYfQiIpHIfJy37r6fZhiGYRiG0eeRl+0botHoFjhH+8ViseOx6dj52KXoN2E34zxdLut9Ej+b8BTCowgPoIxMiivvhm0QCoU6/X7/SL2DSkH962rNMAzDMAxjmUImrtVaJcG5+0pr+cBJ3INtntR6LnDo1kkkEv/TumEYhmEYRlV4c/z4Hy8YP/6x+WKdnY/PGz/+8fkTJjxE/GFMwgewuRKn3FOUe4bwWdLPYS9gr7zZ2fkq9bwqmtQ1r6PjeL2ffITD4RatVRIcstW0lotgMFj2yFKcvqu1ZhiGYRiGUVFeW2mlqk3yOr+j4xit5WBAIBAYpsVs4FzVaa0YotHojlrLRXfvBuKMVu3RrWEYhmEYhu+tzs6pWqsUC8aNu01r2Rg8ePAQHLMGrbvEYrH/w6naPBKJzCA+w9VxykaTfh/9OcK8zmIikUhbSD4flL1La9S/i9ZyQdn1tWYYhmEYhlEx3ho37lqtuczv7Lz0zc7OgxaMGROX9ILx4zd9u7Nz+XkdHRPmjRvnPGacP3780elbfc/8ceOu11oucMIKrhaAY7SDDFCQeCgUCnuy+rN9K/lHerQ0yJ+stVzgLGa8L4dTd+jAgQNlP6tKmnBD2jBW4uzXWcjehe1X8aYNwzAMwzAqCk7a7Vpzmd/RcSxO22Hz2ttPWDBhwsrzOjvPxHGbjGN2KtvdQnrNBePGbaW3c1nQ2SmjRb/D6bpeRpI2NDQ06TI9BfsvesoPnLW0R6gcw3kcw8+x3YhfEA6H/dT3a5y4A9AOxTq95clbw5s2DMMwDMOoKG92dh6ltUqBo3fd0KFDB+D0iAP3U53vhfyq3rUq5b027cCVCscyRWuGYRiGYRgVY8GKK66gtUoxf+xYx5GJRqOO81bIMfL7/SGcnwOx32M35rFbsJk4ZSdS9xnYDOwytBvQriGchZ2LdqqUkbnh9L7y4bazoaFhoM7LB/v5WkL2vYPOMwzDMAzDqCgLJkz4aP748Yux9/LYP7EP5nd2fjxv/PiFb3Z2LlrQ2bmYbT+f19n5KXmLCD9Ce5/8f5KfNodaOBx23pnDuXkWx+pgb16psL04cfdpvVLgiP1LQpkMmP0chm1N+zdEqiPvDtInSH59fX1rJBIRp3ML7Bwcv6dFjxW422gYhrG00DF7Sm37rMlzOmZOPnnc7MmndMyefBHp67BbSN9Oem777ElPdsyZ9GT77Ml/6Zg9aVb77Cm7LDd7/f66LsMwejk4YOvi7Hyo9WLBQZpIHQdqvVJQ9z1aKwW2z/leoGEYxtJE+yVTNtNasbTPnJz2/rBhGCXQMWvy4x0XTdxp7JyJ246dM2kb/jvavn3OpB3bZ07apfOSjXYt0nbDdsf2wPbsnD3l32Mu3sAZLZqLsWPHFnykmgscuLIn2i2GctvlEo/Hq/ZY2jAMo7cx6pL1h7bPmpyaNqpzzsSi5uvsmDP5Aa0ZhlEk7RdPCmqtEoybM9l5DFkInJ33sL21no9wOFy1yYcF2jNPa8WCc7mN1gzDMHojXK+W53r3n2AwGItGow3EXym0ag3b/E5N49TFNb5+HbMn7dkxc4OVOy6ZVLfiRRuEO2ZO/tOY2RtOWGnWOjEpMnbWpNXbZ04+bOwFk9skPW7W5IfTKzEMo9uMnfn9HbTRMzdw5jtLsceqNWnpLHTO2aiku1hy1ysQCBScC07AgdtEa5VG2sOFbOVBgwal3tMYMGBAP9e8ZV1o1ySOIeeExIZhGEsaHLWVcdTe1bqGMq+5ca5tA3HcVuaa+EfCN6ljR8JuO18ds6c8pjXDMCrA2FmTN+E/pGtHXjCxfuzMiVd0zJ78yIrnT2ptnz1xdufFk4/umDnp7PZZk/bS2wnjL9/4vzJ1Bz/4M/mxy4jQq3QZjVxUuCj8WuteKOOsuEC92+AsLa/zK43f7x8i1tDQMJR9h7Aozl2UMCYmEwjrbQzDMHobXKtkLsuSBpCxzRiuc59zrU3N4ck1+g5vGZdxsyeXNNpfoE95SGuGYVSQ8OHr9B83Z8rOWnfIsVgW5eUOXA0//i+SjtwBukw2xIGjfMYAB7ZPcPFJeDVxrHp63VHa0aI1wzCWHYIHP3Rq4OD7hgcPfiAYmvpAInjQAyuFDnlwbMoOfnB0cOqDI0MHzo0EDn6kLZsFD35UzO/YIY/42WZ66JAHXtL7qgRcUy/g2rmTVyN9vDet4TqX8WoN9TwVCoWyXv9Wunhd56lMx6xJnfzjfxbO3MntMydP7Zg5+Rriz42dPXnW2Nkbrk368nGzJ+48btaUg6T8uNlT/pxeU8+wcJrvnUXTfCdL/JMzfFM+meYLSXzxGb5dFp7uc16DWTzNN2XR6b6JEpdw0ak+Z8AFZdo/Od232eLpXdt/N9tX8ImUYVSHa7P+HrtNx+wp37hxLhYLg8Fgfxyz6xOJxLek874nxkViiHcgAReO7Qly/UgGcLEpep3S7kJbltOaYRjLDoGDH7hba5UgcNADm2qtO3Cdncb1KutE7egfcD3ekvA32GNcQzdK6jtgf0nGT0nfqgvq/UxrAs7ZUCecNaV+7KwNBnTFN9x55QvXaBozY1JT+8xJg8dduEG8fcakhvbZU37o5M+e8oy3jmqD45bXcS3Ep6f5pC9KgWP3h4/O8/XH6bvIqxtGj9A+a8r5WusuK1+ydnPH7Mlvad0LF493xEnDsQvoPBfyv+IicpnWs0G5M7VWaWpra/tz8Vq1ra1tmM4zDGPZIHDIA7e68ZZf/rkuNPX+su+ctU59KPUfdPCQB53XQyoJ18Vvw+FwWfOtcY1+Xmtc/5anzjSnS9537pg9yXHYSmHsjHWbV750UlUHpOVi8Rm+cyVcNM13l4QLp/teX3SG79hPp/kcx3JxUnfyzvC9/dmpvpEfH+drwVE7/6uTfQNwBF9ZfLrvYurZ1y33/hG+rO9GG8ZSDReFXeQxq9zqJ5n6EaDldQI1bP++1ioN+/gzdoXWDcNYNgge/OAcCVsOfXhA8JC5R4amPviIf+oDpwSmPjih6cD7Vgwc9MClwYPnXtcy9aHRgalzZ7YeOHcttnHurpF3uFPJrx8bEDzooRXY5jc1xz3qOFjBgx4o6f20UgiFQqO5bs2PRCIl//PJdXg17D2f59pcKVpbW/vRrpIGvFWa/53vG7LoWF/G4LPFx/sGedP/z955gMdRXA983SRZVted2p2Ke5FONh2MsaWT6SVAIHQSIHRjm15DB1uSCx1s3cmm9w6mGTCmJUBIQoAkhCSUFALYsoG0f8r9f2/u9rw3V3SnZhvP7/veN7NvZmdny+28m51503WNFXVf9e+FVtx1xKjr9/bHYNikwZg7J2LMxQ2UTdVbZ8P+/dolT92esvrhRWYwGDYPyuesuk/XWdY36p1QOvuFSRJiwMV8DnWdumq8c1son/3STPec59VnRwFDcEBWcJF3LO/Xdl2v4w2vQvMPXd8fUKer5JOvru9LulqtJ3VdKsgfNyljfauVdHnFrnlW9F4aDANGxZyX/lN1xsueytNXexEJo+Ke88Io12kvT3bNeX7n8tNf2b3stJcOKpv90vfKZ798AP8+dyubs2qaa+7LW7lmrRov+/NSqnTNXjWu5JRVPfawjZH0hK4T+Pf4KT/yH/BvsoAXyxnEj9HzCOy/Wtd1B/t8RHkX1dTUeCsrKw+l/IvRLUNeRPeWQ95E9xryEHITcgHyQ+q2h8xOlf3hJcraUz+GwWDY/HF+Qk1G0dzVMZ8UC898LtkY3ijlc19O+D7rL2pra2VmfZy/TnQydCVqjPAuG5Aesuzs7EHy513X9xVdSca/fXW1VUhazD1d22btuHa+pTws/ONyS03oWDfP8n+1yKpcs9BK+EmaMi7RdQZDv4LR1S8/GIy7153bGDh78lJY6tQlgh/wp7pOJycnRyZEnGKl6AnjpROzVqpMjOD4YqTF/avanCgrK5OXnGoMOB85p+GReDaSI3HxXVdXV5f02hgMhp7DH96/WYcl/I/ZKyrmru7SdQMB78TFyP3e8BCWhPD+lvfLSomXlJS49fS+hGPtwrHeiMQn6Ok9BaMsqSeErnbrbuT2Ne3WpZHt975qs05lnyPXtluzCJvRPYYcunZB4gl15EnoUsuGa/wZ57WC9/dPCD9EPkY+ZVv86r2PPIvcs7m3UYYBpGLuqui6n2VzVm1bNnfV3c70THCf+pLPjhecsrqOh3N5TU3N35FfIe8h7yA/R34aeYhf4we6mvgLyHNsf+0sLxX8e1TGSirkn6RMlJB/dchHyAq225GFxK9Fbibe6U1zokR38MNLyxFxKvrzH6jBYOh/qoutf+m6jUF5eXkJ77a3eKd08G5S4/ackOZHQqTN1tMSUVlZWYC42WcO7+1+n3zAcY6i7s9zzD7x99nVZvV6jOG6xT37TMq53K/rbLj+0hlhx1P6QTUYYiifs/rhDfGXHmJ7sWv2qkPL5r50XsFpK7PK5r64rGL2quWS7jrtpR+4Zq9uKp/7knLKS74WCXNPfq2wbNYL48rmvHSBXZZ12gvRfynV4U+RP4+mpYAXw3a6TuDBvogfwbEul0utsUc+9UNC973YnGHIfzPHVINOeZEVke+bioqKGD9yqWD/03WdQDlH6zob0u7UdangGKt0HefV40/PicBAzfhzssFg6BUbvfcbo2cM76OYT7Jsx3wVYXst78grnLrucLvdtexzq/wxZn8PUusQGT+i/HWK8N6tKikpKWS3pOPGksExplLGh5T3IMf6sri4uH/8XSWh62orrq344kwra80Cayddb4OBuKOus+Fccnm3DyWci6iZrpzbC4MGDRrM+R2G7kFUstrFW9quBkNyMMZWqciu0hv3UrVr9ouuwlmvVmDMjayctdJVPntVnWvuajWeq2Tuc8MqZq/OLzr1RbWunXvuCyPK5q6eUHTsisHse2vJyS8XDzv0yfDYj22eTzhOoDv4oYpft0ZdL/CjPoEH/S3kWh70SwlHEsa5QWH/nQoKCmJmEGUKxt64qrAX8usLCwtL5WXIS1Fmcl1SHR5jN4g844m/ia6Ul9U2xBdpZUh++bGqa0F9t0enZi+RXxxHDmU7l/0+QZL6gCLPfslWnaDMlN9yqhO4AjAYDP0Dv7drdd1AQx2uLi0tTfj+5Z2m3GdgNHyhp6WCMmexb5Wu7wt4Rx7CuzXl50fqu5Y8MV9dxCBCN5T9P3Tqk7Gu3UroLxTD6/KuBdZeaxdannVt1gld7daf/z7fyiV8ek2r9egXV1l1km9tq/XY+qut7cmfcGIH5U/VdTbUMZ/6liDLeWefF2lbllD/GuLfQeaSZynv+q30fQ2GpJTPXaXGGqSi+OSnYv79lJ70cpyXbh3XKS/H/YPJBB7m5bouHdjvTV23seDHGbuGbAKo77HIVxiucdPYI4yQF9eoUaOy+ME/6vzHzIvgbKQD3XLyyD9WM4jWYNiI8Fs8X9cNJBw/6kA9GbxvDna73d2+w514E3zpkD+vvHPUCgb9Dcf/lXPbE/lCQvgTjJ+0jB4Mr5jVKGz+1m5l1Lv3r6usjJdPpJ5RtyNctyudaQZDjyk/fXXUYWFfUj73pW90XabwoP9T16WC/Ak9hG+K8ELaln/JLl3Py6hboy8TOE63M+YMBkPv4bfWqz+tvYXjp93bznumFqMi8fKIacLxzrDjvHt/RZkudB3OPOh2LS8vryFd/qiuzM/PLyac4cyTDtT10Uh4RVlZ2UjCP3jCw2SOJDxKz58OryZco2ID6+aEv5x83W4VrGuVb1Sp6Wq3GnSdDXW0h/5sTfwqrsErgwcP3uif2g2GPoUH+z5+lH+Xf4mR7SU1NTXdTVjI4odxiK7MBI75V13XG6j3GF2XJhl7NE9FddhvncFg6Gf4rW0UR67eJLP7R44cqSZVVVZW7iUh+V6MzaHqnJGz9EypqKjw67qeQN2TjuUlbRtdl4j17daBzu117dacrjbrvfVt1t1drVb52jZrqy75hNpmXf2r+VbO+vlWUSTf79CtIM+ENW3WPcTvW7fAehWDLWb4Dvqkw2Bon2xvAQ9zzR9H7hk+fHg+2wcSvw2jrhFRY8sNhs0KT3gK+6950STs1iftESTp+AteEnE9WT2BH9lofkzTCHfgeFOol4xTGKeL9JKRvhX13YHtqRHZOSLTSNtPLztdOKa4CXmaMu6hfPUCIX4kxxwrcTlWVWSihxyPPNMieQ5A1BqzhPNJMz1vBsMAwe+wFKnU9f0Nv/O/6zob0l4rLS2VyQXinuJ4JKjnEUg/yR6bmwr2v54yF+t6G8qZaMfJt8CZloBEY/Sif9TZ/0TkfeTF6rBj99esxPvIcT/SdYnAQDtI1zkJfdcatK7NukPi75yi4tFrsnZ+eFWGta1WtK3BmEu73fEmMbJTkPBcDYaEfDbfqlrfatV8Mc8a/fV8a3zXfKthzXxrB/5VzORBPuCrNuso/okc17XAOoR/LHsSTucfiI8fxaSueda4rxZZIz9rt6opo/qfV8T2IvFyaMToiI7xKikpGcqP8gHkF858iZDZTnacMo5wpqUzxsxgMBj6G95lA+46hGP+T9f1FN6tB2KgeXS9E4yQychK5FPk3uLiYi+73ERcJlgNoozpkg/dX9F9KO/8wYMHZ4vhiETXDCXtCLZfpv4y9ld6oT4QPfHoH/jhw4fLjM3/I0/cijzo+3Th+P8uSG/WcNdl4aW01iywPtHThK/arRN1nRNP+LOvTGwbV1ZWNlYmMMg1p32sEz0yXgw9jG71x91g6JZ/LrCq+CeR8oebKWvbrR/YcR7I2ySM9G79mu2o25JU8DC3eBNMZEAfwqirI+1dPc1gMBgGklyQ0BN2AzFg5OfnFyRzqMt7NqZniHflQkdcLfWVCNJSGkac412eyAozvM+vROxPl4PQL8LwKBffcy6XK0+uC+/pXDdQn0WkdyBqpqk38oXCG/li4GAIeWRt1I9kw5NkUhbp5+m6dOhaaH3HjsuM0a52q+7TxdagdfOtpmieNksteUa4z9pWa/KXbVatbK+db3m65lt1f55nDSPtja5wh8ZlhLsSquEyhBvcaKWJtGe6zmBIm68WWf3Si7Wrz7srP2D5B/WJ/LPQ01NRneHkBYPBYNgY8K6ajUHxKcZMLZLyE11fw3t1R44dN7MS3Y9IO5Hw4sj2PAyrkUSHof+Nll1cGg3jPJI6kGWfjD7nYcBFnfxyTbZ2pgkcK2pIOaGeaTnapT7dTihIRNcCS601+/W11uCvrrLyv5lvFX7TZpViqKnJJ18vsPI+vxwDrd3a5qtWK/fri60sDLeKrxZY7jXtVuH6VkuNJcRoU+Ozu1qtuesWWNtvOELmcH2+U1lZGecKy2BICx7WhP9yBB7US9a2W684dWvbrD87t5MRWhK73EhFRUW3LwEe5AX8iBM60DUYDIZNDd5XR2OQ/MfbR6u59ASOH+Ogl231KRLjQL2DMdDU+C0xMonHTQgrA12XDrJfdna2Ko/zV+0Iobg1sv14Sm/aDXZ+9KOQX9rbPQUDrqcTxHrMxxdZahKCDsZf1AUJbWn0XNOFNq/fV7QwfIvBSItxPutkTas1RUKMuCXr2q0HeFivI7yIB/WCdy+yhrH9qr6PzVcLE68Xl4xqs4SUwWDYzMBAOQaDYqOsYepEegF1XXdg0J2l69IFQ1DcgTyFyJ9uZbDxJ11WfziNd/lppE8jfhnX5mLkOOlpItwTg2Vv0pNOSOsOl8s1sri42DYaW/X0VNDWpfz0+ndtqXvauqhng675VsIJIE5oL2/RdQZDv7KuzVJjGvqaL7WJDMmQLnZ+0L/V9QaDwdBXSM8TDf4OGBGf8b75F/KPiPzTIaK3RYZ/JJN/O0T2+09NTc1/CP8r8Uhoi2wr4fiS3y5DjiH72vVQQjlvkG9PwhEYRNX6eaRCDCnOT/3p7g7yfi4hx4z7xJkIr2McnVBSUtLtF5VMoPy0/sDTXqjPnTIRDmNwlJ6eCPaRe//u14usy/U0J1+1WaPXtofHwAlr51uz1i+wDljbZr2NMXczcq8zv84XbVZCLwrdQd36ZRiTYQsAA26WrustXddY5WtbrW4Xdufl8RteOLvpeoPBYOgraCDvQLpdcWagoU5PVIddBskKKysiIr1assyVjFd7lviv9f26w9tNbxzHWO7cJv8DdXV1aoYlRlHCtZhzc3OHsN+vkHcxLn8ekZ8hbyM/Rd5C3ozIG4646CVd8kl+e18llPc8x39JP14qyH+z2+3u9rMv+Yop/0vOqUCMYz29r+lqt7pdV5Z7ugtyREQOoY7fxcAUN1HHsv0D6aVEtkfS8m1nMMiDd/n6duta/mFcK2FXm7WM+COyFlzXAusFwpfXLbB+jLzB9mvr26yXSF/Jv5UnkftIv5XwFnTXYRAuXHdF6s+n/Jikaz3lGp4Gg8HQWzxh/2fKb+KmRLVjyAjxec40gTqryQk08B/RuDfr6anAYPlhRUXFNuwXY+RQ1lfoYlZKcOKNrCtNfdLqxdtYcG6TndcvFeTr4npMkPjaNmudnm5DG6bWiE3E+kvD49zY/zTaxpv19O7g+Bl1UuTl5anxdjwDZ+ppBsNGJfLDixtIazAYDH0NRsmxdtzR6A/LysoSFxdF6Nw0lEmlpqZGPGEUDRo0KJdt9VXBm+bnvlRQrvLhRln3UIebJE6oPmtynBgnuGwnnLWZDMp5mTqrHjXiX8g1QN6PbCetu5wX0mnnaexsCZVeN1W9q8fetMOwcfN2HmHLWE2GLvHllFw+NfaP+3JrSGOw5Y/1wSbxE9djqM+w2traocgQEbbF3cj3qOtgrqMS4nFDdjCc1DqtYgRL+M2CsOPdLxZZrjVtVusX86wD7LxrW1XHxfK/tVte2f58vjVlXbv14/XzrekYbspf6bo26zriyi0W8dcx+qRz4yX2+1B0Xy62Eq4L64m4XqEeq6iTPe5wONu/9YSdI8f4oUPvQ6euJefWbU+jYQtHuseryqv+O3bs2NfHTRz36ZixY/5R46n5X6lV8nWelbNmmDXozznWsD/lWcP/lGsN+5Qn65MRVvZfXVZxV1117b8mbdWwfutdtvnLhPoJb42dMC7Ev7zoLCEeUPXjJdyJB3OjD/Y1GAxbDtJIOuIJne3yboo25AMFDfQaAjE82pHjkUORAPrtCK925mX7Ukd8NO/XQqdgFORVVFRkY5QqI8YT6XGUcWqk5bJPzGLtHONL53YiJi+bGbN4vBNf0K8WY28INHX7yVDwdbaknDyQDOr5J13XHd7I2D7Cn+tpwpr5YQOtr1nbbiV1qsz9UMuJUad53K+lhEswsMXtzFREnBxvRfhd9A8R3xuRiTFq0gQG3I9jS1PlrIyEhRDnw1V6Xtlf+a8zbAFUllaEHvvquT6Tc5dd9G+7bH6EuyOrediOcR7TYDAY+huvo7fMm8CAw8CRhvQs0q6Sbd5VV3jDS0+d5gnTru8zZsyYtDz3p4JjJHTHRMMeN/yEOl0bCb926jHaRlB/WUDeyzmMJj6aqHj2F+e5I5x5qx2r3nBOZzr/ZCeisXNm0nF0DcGmuxo6mp+rDzRP9wX89yjlDUMG+YJNcZ+C+wrOaw/O4RmnjvPd0bltU93NutZd7ZZa+aG3fHyR8hnX7VrTXO8Y58meDHpUyZvpBD/bZcwyPcHwLeX0m86JM8J6I7f99j710qwOr2H3enl5eZ/OWDIYDIZ08Dg83fMuinMQXhWBfPNKS0vV50I2ZRB5EQZCQncXo0eP7gsDLq2F78m3nfSYIX+mTo+LjvilLpcrruclE+TdrOuc+IItCf3aYbBNqO9oPrIh0LTXpI7pNb5g82RryahBIztnDq4PTFOrUvQFXHvlNNeG6yBjz6TH8knkZK7F/hiqwz3hdbRjJkGw/Y5zOxlrWi332jZrwroFiT99JgOjLeFzkQzqo8bgpUHccyUGHM9jQ0lJSRHlhI3lsH62hNxHX01NzUjSxIWJLGemjGjS1R8SwxbA/KcWxxhgB592aGjFP18M3fnRQ3HG2RlLzg2t+MeLoUfXPxu66+OH5SUQuot8sm3nueUXy9+IGG8/IOyTfzsGg8GQKZoBl/QzVyZQTlruK1Jh14v341LiMhNxd6SZeNxAe/Koz2mEMgRlUFlZWaUYnTk5OSPQ3Up0PsaMckUhdaOM42VNK4ygeuJJP5dWhz/jJmRy58yHdJ0w7qapSdfpzF6+YQH2+s7dMzKKdKh3zLrXmYBB8zdd52Rdu3V81wIrQKh6wtYusH6DEfe2Sltg/Wltu7VW6dusLxAVX9dmvWLH2fdg8n28pt3K+/xqq5j877P9SVeb9bx9DCceh6cF4ou4LzPtbe7bttyzq7iHUwivQ95DGux0zuVNOy7k5+fHGXmJoIyk/l0N3zIuvufKqPG17P27Vbj4xRtD16y+OXTQ7ENDZy05P3TYmUcp/RFnfz900KnfC/3o3isw4B4KzVuxKHTdq7eEjr3k+GgZC1+8Ie67vcFgMAw03gQTDmhEPTSYdU5BNVZ6Ogi384RdPezGvnsgzchUtqdg8Mjn1j7pZequB4z06JrRtgFHPZLOIJVxcLquOzgnmXkZN/hfaAz6n7Xjkzv2GOQLNF1c3zFj0ujl0/J8nTNLJgX9Y8bctP1gX3DGVr6l/jENS2ccLnkbAv7D64P+yeNunSFLd2WE1+EyhXjUrS71PBNJ6K/O7XbH3Q+Mnr/rOidfp+Hiqi/gHObLnwbqvretI36cM093sP9buo5nsNsePY7zI11n+JYy+5oz43raeiPXvnxzzFgNg8Fg2BjQkL2KARQzq3NTgcb5fep2MXITshJ5GuPjcjHuKioqlMNa6j+LbTXz0RN2iTKGBlwM0Br0I6vCY9/qKKua0ENYkUjIm9APHsdLaEhO7py54U/4wq0HYdAd4wu23NnQMWNK1S1bDfN1ND+A0bZtQ9C/rCHYfGhjoLmzoaN5l4Zgy3d8weZr6juar3EUZ1Va7uM4Viv1uAt5hTp9hHzM+YgvvCDx8wkP53x2I/w1+qixKj2MpNsTAVrZ3ov0o8QAZVt6ruRz4VC2lRHJcRK2P+vbwovOd7VbX65rt46WT6jfHGwN+nxh2CtCV5u1AzJzbbt19to26yjRrWmzosbXunnW0LWt1lHk+cv6BdZkymn5Yq41ZN0VVu76eVZdpOwXJKSOl3APlY7ziZaRKZxTWp+DnbCPenYMWwijR46OM8J6I4teuDHhS8FgMBgGEhozZYjQyB+BdCIvIj9D/oB0ISExYtKU/yH/RdTKC7ZQxlrCPxF+QGP9nlPQ/Qb5pDo8jk1WWrD3k3L08kNivJH/XWQldf9NbW1tIbo79PPqKzD6xCWHtoiUZsANINRliVxHDKBHZVtm0RJ3IcPdbncl12Iccrr0hJJ3lMvlkkH7g7h2su7qI7IP8fXOMqsjw3gw2tSkh7ULrM8wtA5b12o9hUG2t3we7Wq1DlG+T9usOZKHUDnS/bLVuuFvrZb0eA0ifyH6K9l3zroF1gz2fRAj8BTy3IOhpyaadC2w2qhbzGdm6rWrI74t53QodV+O7CQ6wrnssydpbq/j86lA3V9zbhsMyQgF3rkj1PneXaHAu7f//fbf3/feA1+ueOiRr59b+NjXK8969Jvnj3z062dmdn5w987XvrJk3/lPLz76sofnn3HpA1cvuvKRthVXP9r6h7Znrgnd+ONAqKK8Yr5euMFgMAw0tgG3OUMjfruu60siBmLMRLPGgP8uCScEphY2BmYmXEJqctB/oa7zdc64b/RNU+vGXrtDYUNH8/LGYPM4PU86YMicq+vSBQNOVrKIgfJWeLzefjOEU8EzGL1/++23nwq55hfbOuqb1B0Lhl2hrjMYDAaD4VsPjefrum5zo78NOEF6/pzbjYEWtVJOfWfLU41B/yc+tusDM4sbljXt0hDwnz050PJ9X9B/nC/Q9O6YwI4jiStnteR9ZtT1MzwNS/2rfcGmM+sDzerTZ6ZUp1ijtaioKAuD7E3pqSwsLIzxcSdgECV0I9K1YMPs0a5W61lk1ZfzrcFrHOt2r2mLrrqg1qH9648SjxFc1269tq7Vyl8338rparN2juoXWL905hM4lyaew56MUYyOQzQYDAaDYYuCRnCz/wRVHRkD159wnXaorKzcxd7GYEu4BuukTr9yzD55aVPMwu0Ya0mXmMK4i07I6A1lZWVe6jkPOQzj7WzRER6m50P3sa4T1keMMgHjbTGG16MYYvuvbbdmYbD9Enl07QLrEpXebhWocL41dv1V1tbkuwED8NO1rZY6f7bP7Zpnndh1lZXP/lGnuRhwP7HjOlVVVVLvFu7ntsh0ZCrbO4oQn8J5bU18F+K75ufnG9dbBoPBYNhysQ04GsbnMABk+aKoyLiqiooKWalgBPE8Gs588pd4wwP/PWzXEI4kHFMdHnsVI6SJ49zampqaSkJxqFsQKU/KHktZypcZeWVs2zae8PJP+xAX324ik8k3A4k63ZV6oh/vdcyerR4AA07gOP91bjcGWkK+Dr9ywD4xsHXupBt3KW5ctmvFmFtm1k5a2jKufkmTb1JwRv24zubRE5f5vY1LppeOu60hOivUF2g+pjHY8n8Tl80o3lBq+nC91BJVmeJyuWKMy4EEw+96XWcwGAwGgyFDHAbcgH+Oqo58+szJyVHe8ZNBHX/viH8koUxosHUDZcAJ3ohT3PLy8piVHAYKzv9Izvcle0IH8pwYsxLXJ3w4hf2+QUK1tbUpl8rqarPOWrfAunTtAuvor9os9Xm3a4F10dp2S41JW9dq3by2NbxgPcbYtejVMmBr26wfrGuz1OLypE+jjO9L/N/tVt7a+dZ30e0fPoLBYDAYDIZeYxtwNPL/0dP6G469TMLi4uKU458wTqKzJjFWfiOhZsAlXBWhr6msrBzKsZow3gqoh3JsSyizZw9CDqROJ6US8p7AOe9P3l2Jv1tRUTFZP0YqqkAMNQLprUzoFNeGPMfrOoPBYDAYDN8SMAReldBpEA0UHLNTwtzc3OF6mhOMHacBp8aebQwDTuD4n8qxCVdz7d7V05NB/iokxkkt2y86t5PB+Y2KGG7KrQb7Pabn0SHPQbquO+qDzdv7ljaXNgZnlPmC08unLG8uY9s18ZZprglLmwvHBlvy65ZMzZ24fLuc6jtbsmvafVnea7Yd5lrUlD2hc7ucCTfunDvx+qYR45ftlle/bHrB+EBzUcOyluJJnc0lkwMzS31L/C4pz7e0yVXfMd3dEJjubuyUbaTTX9oYaCmZEmwubljiL/J1Tiuq7/AXT+hgv45mV/2yae6Gpc1TG5e1xKybajAYDAbDFoltwGEg/FFP6288EW/4FRUVKQekY4xEDTTiymeZZsAtt+MDQeSz5cPU/3RbR/wgdFH3HBhb4pNtDOfWgn536jvSk2CVARkLqOtsKisrZTC/GG5RowVd0tmnNhxvf451INKkpyWjMeiPuu2waQg276vruqNh6bQyDK59dL2TxiXTt9V16VLf0XSkrrMpKirq0VhCg8FgMBg2O2wDjnAaDf/nyNo05QuMi8+QPxP/FPk4TfkE+aPXMQmBY8+lnK+R/4jBgvwDWUOevzrzCWz/TsKNacAJHPN1DKtoLxfnsE9JSUmeJ7y4+tMR3YHEnyfv54QTqPsFhE9tKEWdzxTntkCe8XJ+7J+vp6UD+1/Pvnvo+lQ0LGm+QNdhiK1s6PA/Uh9o/mzSnU35DcGW00SPsdfqC/rvtvM1BlpumhTwj1f7dPpvGt8xbfzkQNOO9cGWuNm1vs7mk3yBpnHs/6uGQMupEZ3yizqhc/poX7A5ug/lLrHjNvVLmxIafxhvaa2B2t+43W6XrjMYDAaDoc+xDbjNBYwh5QJDM+DUWDonjcGWpJ+ERx5vDRlzqy/bE9h9eFSCuw8vPcEaquf1BWbGlI3BdQjHm0V4h7MHzmbEiNRzG9gnJgNlTXPExWBtdab3lEw/idcH/GfoOpvJHU0H2PHGDr/ytFvf0bxj/ZLR8derY0bUMTGG2k61104b5ky3Ia3bT7y+QHwPIMZks67jup0lYUVFRSnXTy2JVl5eXkZ8OzsPRu0oOy6QdrAjPtWZlg7cx6h7FvaPuohB/7gdNxgMBoOh39jcDDhPZBaq9NTZOuJqLJ1NfaBp95rgVtHPso0d03IbOqeXqY0bYxdqbwg2/0JCX9B/o62rDzYfuCHHBjiOuED5oyey/ibxS7Usoiu1HKs2VFZWFo0aNUr/RBx1fktZ21SHex+vc2ZIF7kOyE8RWTdWliT7EyI9nL9DPozo34nkEVmHoRM1XmwwltQMUieTOqbHOQFOhq9zRnR2qy/YdKgzrS/xLY13fMx53iAh51WI4SrLiB2Rm5s7hHON5uU6v4KcTNq5WVlZxcQb7TT2EXc4AfLLurGruWfZhOoZIEn80N3tcrnEObKsQXsGIkvNzUXUmETKPIO48m9HmHBVDoPBYDAY+hTdgGO7i4Zsvtvtji5RRKP0QSk4820saKTF59wPZYF6W1etGXA+R4+RUN/hV2PtfAH/ivrlu6iFzOUTINv3E8703TM9i/htDR3+y63nfEMaAv4nnftXWiXHSQNfXFw8mMY66sxXrpOEpD3BdbtXHP1Svyriz4leeoGId+Tn55cSH03+N9meQx7l7Dayr6wj2iNkjJyuSwfqcY+uw5C9WkIMpLoJNzWpsWS+YPNiCeuX7DLMt7RFuU/RmXxrUwnX7RWJey/OHtwQbHmb66fcvjQEN3zubAw2q97KhlumqXVQud57Nt48ow7DsaMh0HRQQ9CvVodoXD6tkP3/ND4wLWbB+bEL/Tnjl06t8nU0R1d1sOF8luq6jQXPxyJdZzAYDAZDn6MbcBFdJzIXIy4LY6NcFhdHZur5NhUwgoJlZWWFOTk5ajZr4/KZRzjTGwMtqtetMehXoa9jRjGGxge+O3eqrr65Ide3zD9oUmDn8vqOFvX5LV047lW6LlO4ziN1XbpgLOxux6nLckdSFMqPWzMVXdwkg8Zgy1UNy1p+wDX4cWNH0y8xouZjZF3m6/A/2Bjwv++7xX9aY0fzI/XLdyrl2j01rtOfN/qG7bN9nf5T6oMt0fLqO5rPwdj7BXmDBe275Lovs9TYtElB/9kYa29M7JjR4lvadIOvo+VwX7BpCfn3wXh8piHQ/Hx9x8xtMahbuU+3j+ZeZPMAAIAASURBVL1uxzKO/3vq9VD9zTsXYQDuPjnQ/Gl9sGmbDbUOw7mrdWl7CgagMl5teNZrnduZwL4xZRkMBoPB0C8kMuA2N2iAOySkIb9Bxn41dLZ8T88jTAo0q96fTKnv2D7hgukcTw3q1ykoKEi7t5L6RnvjMgVjIWrMcA0m5OXlDefY8qnvae6r+nxI/CIJ2f4pEojs9117PxsMNtXbJozrbIoZL7YpgVEXN7EBQ/YyO8753sP2vshh8umac1a9iVyf5aQd4thnhvjhI/0B4vLZ1Uf8lkgZC5Hj0W1bUlJSyvWSmcTRFSTINwJZgRxfVFQ0xPkbkn3tuMFgMBgM/UZvDbhhw4ZllZaWylJbhTR0ssyWG6Okgm2i3hoazlEcQ8YYVdJgSlpCY0hgnzyn6Ok6lHk48gbHuN0TnkWrVmTwBcMD7Z3UB/wH+AItV48NThvh62j6oegwWo5uDMxUA90bO5rGTVwyvcLX4Y8zbipu3F6t+6nD8eLGrVGP71Gffaj/zUgTeX5HuAf68/W8Aml1ui5duJ71ui4dqMsJuk6oXzZzXEOwucMXbGprCPrbfMHmdq6RxBf5gi0LGyXe0XI11/cK0i4m30X1nf7zfYHmczGaz0F/Cdf5rIZgy5m+jpYz2Pd09p3bsKxlTmOgZQ5lzCbPXPY9vV7yBP1nNS7zn02+cxs7/OcTXuALzLwII+3ixs6WKyZ3+K8iPo/jtHLv2olHezw5hzqubQfyJtcwbmKDkJWVNYy0a3W9DWXEjAXkviUb+xjX68ezrv4kUH4+dYjO+CUe93naYDAYDIY+x2nA0SjNsuNDhw4dRFpWeXn5cFk2irR8p4iBhQEhPRG5GGXD0eW4XK7sESNGDEMvg/QHH3HEEdbvfqe8fsRBo3ib2+1W64ISf4/yEg6Yp/wDSIsusk4DeRf5xZFutJeI7es5foW9Pbmj6Tt2XJgUnFGCIfGr+g7/WcT3xhD4cdm12w9vCLS8jBFxf/3Spu0xKk71dbbMa+hsTrrYug7H/bOuE6iLOi+uW3SJMM4jrvePc7hJ12WKXAtkOzESKe8wjnMy4YWEreguIO1Uto9ke19CWSD+ISRmjKATT3h2ZeqptBsZnhtl3EfOT30+pd5qSa9ukM+5MqFk2MiRI2V4QDbP7HD+gAwvLi7OLSwsVCJx0ZWVleVQrtxDmUkrz3RKVyVc30bq0+MxjQaDwWAwpI1twNHw3KenoVOD8W1ooKILsduQ50wxxnS9UF9fH51tmQgMPzUDlAZTuaOgLpfH5ggjBp4YKjTYcT0hAmlB5zYG2XYYZGn5UGtc6n/fue3r8P/Tub3dNbkJ3WDYcOxPhg8fnrC3EEMuzx6Xp8N++3M9ozNfewL7j6WcazAU+2xxegyaUu7LJm2E1NbWFkivL+d+pZ5mw7Mkn0+H8MwMkz8iSE5JSUkBUoUBOBrjrQHZhvSduI67kD4DkR7T6einEd+RcGvu4SQMuVFcl3JC8fOXzXGz0A8l7xAMwZRGncFgMBgM/YJtwBF+pqfRQL0sn4oIX6TBdMnnIuQ1GsCwSw7LGkTa3TRo5yPtxKdhjOUQ3k95dxCXWZgB9p1IetxnO3SrHJsyw3N7jIc70b9CGY97IgPw5RiOfHHoBlyEQY0B/5e+QMtXvmDL3xo7W/7ZGGz5P1/Q/6/GQIsSX6f/n5OD/i8bgv6fY/Ctrg+0vNkQbP5DQ8D/D4R9/P83MTAzYx9h/Y1cf7nGiHKE25fItdd1mxLyXOk6g8FgMBi2OGwDLh3HrzTue9TW1nox6jx6mhXxfVZSUmIPGo/OkBQwzhqc20J1kp47m4qKCuXVHkPlV3qakyQGXFqUl5e7dd2mBuc/afjw4dKLVBZZoeEUPc+WANfhGl1nMBgMBsMWCcbAaxKmY8D1NRhev5SQhll3dBsD6f/TdU56Y8Bx/gN+3pnAuT2DwXww4To9LRWc167s8yzXbnlEbkba0F1CeAFyFnlmE56E/JD4iYSzSJ9L/Bziku9apNMb7mV9iPBJwhcc8rz9/PQnHDelCxuM8ISfsA0Gg8Fg+NaSiQFXUVExKuKQVtYpvQE5BnmnqqrqcIyM/dGfQVwtMVQd+3k0IeyrlsViH2XAsc/9lHMq22Mi6cplBPrfbNgrnt4YcJx3AfvHrUe6KcD5y/jCryXOdZdlop7V8ySCfJN1XXe43e4cx2ZKg1qn2rEqRndI3oj8LyJqW56/VMJzqhz96qCPuXeUdWFBQUFlJC3qXiSSpmYCE3KJvFG3KZlAmdExjdQrZrJMMniejWsRg8FgMPQttgFHg/aBnpaAoTLAmwbwEdkYNmyYjIFrRzeeUGaKyoBxNZOVbbU+ZSoo50sJp0zZ0Aaz/5EEwz0RP2aRfHGLojvpjQFHPa9HEk+V7Qe23nprZSxT59tt4VyXIzehX8z2POpzCYasjCuUnrJLkauJL0RuQJZG9nuKfY7Syxe8mn868i3EiCDwqMkipJew/zjC7dC5kRNKSkpk7GIBcgJpMktzUFlZmXJ8zP0tZf+3ZfZnba3ycdujgfuUO0NTxa2lmorqBIYihm2TrqOu0qP4Xc7lHNlmv3PR7ca2WiGCsJX0ZYR7Ej4j21zvBzyR9U0574noHmS/Owl/bkWWPiP9FPI1EN6KnFdUVDScPN8hz1P2sdE/gb7Q43Ab4+3lZBWDwWAwGOLwOD6BYUCotR17Aw1l2oP+adiUPzb2UQ5mk0G+ibrOSXUSA47zESesCX24OWH//+i6ZGDMFFBmQpcn6cC5vKDregqGQjGGV1xdqiM9TTbc44eRWVznM8U4EUMwYtzITMrr0d+JHEge+awqbka2Jbze4zCiiV+A3Ej+scgvSktLnUutXWDHU0G+HSSkHOU/j3C8hFzPOBcriSD/3zlnmQUq7lCORt5GPtTz6XBcn65jP3Xd7DoIPC9xPbEYiDIOUxmyNtQ34fPIcbi8ZS5CZ2+m5L/QuW0wGAwGQ69xGnACjc8EGrLq/hQaNPWJywkNXxF1GUfD6id5X8LtqEuiyRJx6AYcxsgmOzGBc4z6tItsn1UdXiP1WsTDOT/N+St3KsTFKfA5nE+TbBOPW3AegzK67BP5v0/ea6oHeCYp1U5rSTHqpf4gUE/pDTuK/aQ3axvih5D2AOeieujE9yCGmnwyPoD00+yJJjWOz/ykqfPmWqk/DGyf5HK5Yq5tJlRH/Mk5yc2NdSHjGB7wtK0jrnrXCKMzpYlvb8cFzuFHzm2DwWAwGHoNjcvrum5zgwYz2oNHQ362I55WbxfX4GAMgeh6ntXa7Nji4uJoLxdpynddJP6yHU8X6tSobQ/HMBjH8feivL0jOlnGSeXzRnzvUQcv9XzXua/AfjuhfxmRBd0Hsy3fSpPOUsUYUitPpAPlTOf471Q7JlCgu9+Zh/SrMJziZhgngn1VD1wiSItbpF7HacDZcJ22lZB6/B2ZwPY86vvb0tJS8dm2SyRtP0RWxlhdUlLiJi73UGb1HoQMRX7hjazi4Q2vKStOrJ+x3eWgewN5nXsgvbnDKP9WynocnYe4esaIi8Pk/cQ/HfW8i/2rZNyipBFXS70ZDAaDwdBneBwGHA1QnDPf/oTG7x8SYnQkXZGAhlIMm5SfyaqTfEKtqKioQ5RDX8pZzHEaCe/mPFutsA+7iyWNa3BIxFgJkP5byutg+xbyq8kAhFvbZVY7xuORR8rJCPZP+xNzOlDnuIXpxZiIhNnUMUD4AOcwLaI7A5klekf+B9k+WRzbyjbx0chWXIsJhPdR588JD0fk2ig/bMRllqo4wI3z75cK9l+JgfP3iHyDfI2sR75A/kL6B8i7lP1Twtco/33ifya+Xi9LoI5bSeiJ/RR6qNexUoe4o6kIIz28M5BdZXwfBtoIcbRMXHr71Odib9jnoUxsObCurk6t0oDuYeR4dI2UIeNA92L7Lq7puMLCQrXaBtu7oa8kXOmNDA0gfFxC9ptv18VgMBgMhj7BEzHgaAgv1ZIk7Y9Dhw6NfkYijz4IXRqpZhrChGOCuoPyT4qEHTSUWTR091JedEksG283Eyyqkxhw/Q31/pOu6w7OZWf2u1fiRUVFCZes8iaYIck+N2Eg7M65isEgKwycKHq7p86Jd4D9pVUnmFzQUzIty+VyydJtGa1EwTVLupRYX0PdEt5jg8FgMBh6BYbBjyWkUYvz6k+aWqSbcDbp52IYnEFclh56ArF7HvalkSoVo8Qbdi1yMbI3DbF8BjxDesHYfkeMEvLEDLgnzyWR8kdHyhK/YxdjEJagk6WmrqaM072OWX6J0A046WpxbqcDZewfCZ906jn+js5tJ5WVlfaKFGnDeY1iP+m9+h3xheXl5dMJZbzfl4StnHsN4WLCOsJltrHHPuNlQD0yCd33MVyUk+MqxzqxNqNGjZLeReVypK6uzmVLTU2Nm3IqysrKvOxXS57R6MZR3iS2G9iewvnvJD1UiHx2PJBQVuI4HDmK+MHklfFr2xOX3qxy4uL2ZU+9Dj2F8hdw++ImZqSCfWTR+h9Sl1OIix+7M9mWSRdXyXOHLCF+G/KAPEvIauRttt9FfsF5vMX2K4QvSjrho97wSheSXz6XKpE4chtyO9t3EIosI//NlDPfG/ajJ651TiWcRXiEXleDIW14gDrOv/2SP595y3mhs5ZeECtL4uW0xWfI9PZ/6+UYDIZvJ56IAce74nA9rTdQboxBiOGwq3Nb4F1zkYQ02PV6muCJ+PGibtFB44mo1gy42tpa9emzIrKSQyS+NeWdjlxBeY9aEdcQNuivQ+pJO0saasq8kkb6u4TfoJ/D/uOJ31dSUjLabphJX+4sIx3YN6E/M8qK+0yMoVWbk5OTdBYt9bqc8mIMzt7gdYwf3BjwjJxJHY4V40hPMxi2OB768qnQY189l5E88c3zoe+e8r05elkGg+Hbh8OAS6sXpby8PCMnr6mojri7wFBJ6XiWfM/rOiekd+q6PqBbH2Uct0f+49jvS673f5D/IlFntrbIYH0RXU9ekf/JftWR8YOC9Cw5y+8pGE736LqBRgw4XWcwbJHoxtnjX68MBd+9Mxz/ZqUKH1n3TJwRV+muyGgcgsFg2Dyh8f+JhDSc4kA3JdLbU1lZeQThYgw59emO/U/BAMtHN4f4yaS7MQTENcQ8fX8djJDzJKyoqFBuF9hHZgVOILyAcqZUbXCfsdKxWxxpGnDqk286FBYW9pmRmimcf8r1YZPBtYqbzCBwbSdS5rZco2lc1xbiu4mQf1dkd4mj35VwJtJCvJlwKqFcf5nEIH7jkrplIX0X8sln3SnIVuSdLNvsPwqpQFzoK5CR3NNJ+v465Os3A87lcmVxPfI5RhF1KaaexfK5lme5hHqWYjRLfcUJbx5hNs9BTC+twTCgPLru2RjD7JL7rgy1r7wu1PHL20OXPTgvFPjlHaFbfro8zoDjkTYGnMGwBeCJGHA0ZvvqaYmggZZxUYfRwA2iEfSxv8zcnC5pxOsRGRd1AnJ/UVFRygaQPO0SUo6aSQiDpVGNGAUnlZaWKoeobKdcQqo7A46yxA+XqsuQIUNUmeiisxYFGvLhg8Hepm47IBOGDx+eQ/nF0sg78wvV/TB5gnqpcYG9QK2SwDVVMyH7Ck+C2abeNIx+He7pMAz+pMY01/QQXZcByXpNh/Asyjg5cR2SLcZZXl5elujcbvdQ6iPPRo9Wl9Dh/HK59sr1i8GQETyYMk7jd8ha5K1Hup75n26cpSMVLtMDZzBsCdgGnMD7Q627OVDYjTV1+EpPc0J6SgPNacBVO5ys2tCgKvcYgoy3wyiThnsy57scw6yChn0YofS8qB4iyshnn53EnpN9s7KypPFXRqoT8kc/Y/YV1KNK12XIUOp/HvXeS0/whldRuJJ6T/ZsWPIsZhUMzlPchdgGdRR0yqeZTU1NTdzsSsq6gOtbo+t1OMaduk7gGBdR9wuQ70qc8ur0PKmgXHEHo1y7EMbMjGY7brZuIjjmMCTpJ2nKOSiB7gznNvsvc24btgB48D386MbzMOyM7IeIF+6jeBi+x4Mp663tyfYe5NmZ7XpELfvBfsPQSTf4v9nnd+ibyPeFpD2y9umwUbb+udA9nz4SZ6jd/9kTcTplwJUaA85g2BLgnfGGc7usrKyQd4iXd0o1ocyOPMAbnt33I8J2dEuqHet4OuQ2p5C3k7wLCC9ETkYOQZpcLlfSGaIcU47rxYiRmZh7IHsWFxen7MUTOF7GDSbHKaB+E5y62tratJ3cbopwvZ6qq6uTz3/HIQkXWpe1niQk7/elB5Vr9wzG2BjRsc8RXJNz0Y+N3UulxS1HpUNZd1Lug+w/EdlbZhNT3tWRHq4ocmzndjKd4MnACS51lNnL4qPtZuoi68p+wPNWS/g5zxRq78tI9B6jl8/8Wej+Qqjc5bC/9ADLEl0yq1T5cfNuWMtUjLs20p/kWZF1f/eR60LZM/Ly8mQYgVopg/CWSH7Dpow3PDX+Wm52vVPQjefBHU28xinoxcFgnNNKfkBrdV068CPZAQMuZlyB84fwSFd4fFvnr+8O7XH0PqEbfxIIHTLn8NAJ808NHXL64aEbXu8IHXHu0aGH1jwVuuKR1ui4uEpjwBkMWwQezYDjPSWuFV7gPfUG8V8hHyIfIX9E/oL+r4RfIGuQrohIXByxSpo4Y/0T+T4l/ENk/9+w/S7hm96wC4dnkd8OGTIk+smStDORe5B3KOcJwiXkEXnGWb9EVGsGnKyX6Y141pdjUp5axJz477zhxlriK5DPJC7vZcnD+1S89w8i/irhDEkjfj/55kbijyOv8W6PLpvUV3C86PqZxGPW3swU6it1PFjX9wbqJD2W4lpEXJEkXekhHahfnHsNdOqzI+Hr1F2toCBwvEUbcqWGfdNaU7Uy4tS4v6DOcctyGTYxeKCbnNvctG7/KdpUOdbqoxzlZwgrvqw6MqjXxptikWBPeHFhl/zL1dNsHvjrk8oge+Jvz6tQDLVrX7lFTWaQbTHYRGTm6ZK3N4yFqyqvMgacwbAF4DTg+DN4jDOtv/FGxsDxDnvP1okRtSFHmOpuFpvXDbjNFenx5H70iXHIdUxpwHnjx69Jj1KcYWVDfvvTblw7x7GOJV2tE5qAmPVEBfJKfnHTEuCY14mRzj1U95246Godea/YsGdqeH69ElKufKVKa3mvTKFu1+o6HfJ8K57HbzU8cN/YcTG+kGYeNulSlX8BOcOGDbPXQbtNfpjkX2LnJ89Djrj6wRLeTl71QiPcTf6JoJN16B5mO0j8HvmcwLbMpCmXB6m0tDSlB/TqUm/c51FbHl4T62Lkwc/Dxt7jGHNZ1tC0FpE2GAybN04DLhHy3rHj5P2kpKQkZiwUuk4a8LjxUDakxSzsraGMAY7xa96Re5O3mvLO1TOh30/XOfm2GHCc50Jd11O4juoTqtxfRBwwP04bZX8qvdgTHqJTQBtit1N7eCNjv7gXx4gB6A07tVW9bSNHjowzrAWXyzWYfaX3UjofZF3RvXlG5LOlfMY8XXrTaK92k7ykqU+M6G+IKcRSdRqu6wRvxMhPB8pXM6PZ5xMJa2pqfs6xxE1OtHczkr6K+paRf0fql02+BYSy5Jo9kUEcId+HHBrJL8uvPUMe8RN44dChQ+UcXmL7IMRPObIG62/s8klL2qli2ETgJn1qx/kNJB3XwQ1vtrQZLuiec8TjFijuS6jnpa6C0mCBlfe8O9e1FvnGnef6F/If9wjXPyrdld9Uuio+zrNyO3gIj9b3NxgM315ofN7UdTbV4bFsz9AAb8O7YS/yXul2u3PZFjcTahA8unfy8/NV4078avSnsN9DnvBYpGfKysom1tbWDpEGkTJiBuiTR/USic8z0k9kv+eRm8h2PGl3ET+ZULzfJ+vdUbD/JmPAlWaXyHWRQe3yGVAmA4xD5A9x6RBrcEnx4CL5g188zLIktKVQpMJdcaEdj4jKi8gMWBExtsQ5sZQn5cpn3sOzrEFtpXklMZMsuGbHObedyD3Sdd1h36t0qE5gUGMwyQLxaokw7m9crxo6WXnjHPLISh4XEco4vtP1fKnAmIxblcJKMLuUcuWr11COGTPjtSritkbD/pMR02PJdnRfMYzZt5FzVJ9wvQmGSRk2MXhI/6htV9pxbmBKP0LVjplSPKhRy50HMGZ6NQ+E6hI2GAyG/iCVAddTeL/JBIg6p06MO+e2QJ69JeR9mfATKfuogfOJGnwnGHDLdd3G4OA5h33i/Kqhu3FSXzi+Xhkn4ovTjj/05Yq4fZKVec+fHg3r1j+rhslUVVSq9VFtuH7RNqk3iOsPjPY4g9CbYrZmMtjnBO5nwt42QZ4dXZcu7Pq2rhtoODcxuA2bOjwsajAsLw+Zfn6dM42HdCuMr5FOnUC+KyPpK2wd5agFkcm/NfE3+aGMJ/1Ub7ibW8ZE/NzOy8OxPdtnSZzwKltvMBgMPSFTA87bh0s38c5TY52ow+t6mhPeiykHsm8qBtwNP+5QBtVRFx4TOmjWIaGFL9wQNcycRtiKf67aMA6Z8NYP7g09+fcX1PbhZxylQnvccniMcjiv6K57dUk0fujpR6r0BSuvUzqqkPHXnLy8PPFzV8Q1lLVSxZlt0YgRI2I+OQ4k1CUtdx82PDvSJl6I3Dxq1CjVW0Y7KcumTeH58vG8ipNhWe9VJhWq/xZIOXnkfItob0dgoMqkkZSdLskoLi7OohwpTz6jJlwSzrAJUh121SHdwnsjUS/YPDBt3MhxPDzHk2fJ8OHDR5C+tLy8vBK9MurQv+DIrz7FEqqxCOSRcSCL2BaXIuJ4UMa/tUgaZciPzR6z0IgkXSfPYDAYusOTgQHHe0gN4Ca8HZE/kEPFoJPGkneTx+12i8Pb7XmHzeA99Zq2eyJUo0kZaqUFwg+RiYiMpfop5XxP9MRTrtNKA3qrrtsYLH7ppqiRdk7nRWqc8U1vBEPHXXGSMtDEWNt5z11C9//lsVDne3eGjj7v2NAZt5wbuu3D+0Inzpul9jto9qGhw886KvTkP14IzXtqcaiusDp0PYbhHX94IHTZ/VeHJm8/OXT9a0uVUbfHoXuFbv/w/tCNHEP25WJGx2VvjkjPHM/N3i6XK6N2jeclyH736nqDISkRA65H8MBF/3ESj/awGQwGw0CSiQGXLhhUKVdOsKmOuJMgTDnrXf4A6zonm4oBd/WKhW84e9oGWoqs3C/1OnUH1/Zvum5jQnt4KIbcVF2fDG+CWarypQr9KzVhty+PE3+C83yc5+wxW9BJ+DDhg8j9yH1s343cmURkTGZCYd87OabEZX9dxDWOU+4VoT73iUSO/YDUA/3D1FfqJX+KTG9ef8JF/rOEXOjZeloyvBGv14TRHjh5sDbkiIVj7DdixAj1L5VwiMx+6SkNgeaoN/K+wtfp75H/OoPBsGnA++ctO877ZjVyPo1RJXr5YlDJtqxlmS9LTaUj5B1RWVkpw0rkc5zMlpeyqpBatsdQnqytKb1sHZImx83OzpaePPExV4NUI+JgdifCccjxlCcTwZJCuT1aP7SvufrJ9rt1oypjiXxabXv6GvWZ1P6UasvC52+Ixm/9zb0xaVThr3qduoN73OftQm+o7saYt5FnRdcJPFOX67p04Dr0ePkrnvuEfvuoy666LhlVmtsTT3i1jJ2dOkMfwoP2uYRc5FZEzVDhJhyCXv2jJfyjGGyESwl3Fj1if4KI+pJBl3DGSkV4EeIDyfs84SXIg3qeTKgP+K/Xdb3F19n3RqHBYBg4PA4DbnMFA66D9+SdiDgDbszJyenReKbecuNbnR/bxlTg3TtCt7y9XI1Ze/CLFaEjz/2+0s+5/uzQnX94MHTnRw+Gjrn0eIywe0L+77SEtttl+9B9nz0eCvzydpXvxp8EQw+vfUY5Wj/tujNDCyPj3Jb/6p7QnBvPDj22/tkYYy5iwP1ar1MqPBEfpJsV93gHeQorU66YwXPwW11XVFSkJk7I51lphzn3ucgF5FUrGtF2q2FQpJXl5+dHfdfJGDnylUtchggQb8jLy4txm1NeXu6SMewco4j0x0RHeICElL8V8YlVjrV3yWuP1bsf2YX0bci3HDnXG/ZaIfs/Zec39ANc4Nt1Xbpww2Msdh6anzm3E+FJstQI+yqfN93hC/rn6LreMik4vcf/WgwGw8bnW2LA3VZXVyc+Mj+kAWwlvJSGUSZ7Dehg/Msfaf2706ASn5qJJjHYztOVI3XSZHzbnR89pGaYSlzlcewn+nv+GFkKEcPtoS+fYvvR0F0fPxRT7lBrUNyf/HGjx7553CUn/unYS0744rhLTlh/9HnH/PPwc47+r0yAOOT0I/6395H7hg48+eD/fue4A/5vj0P3+ttuh+z55b7HfueTYy8+/qMia8Tzenm9oTHYvKhxaVPUSa8wccHOgxsCTdkNt84c3tjhz/Mt8xdODvrz6jtn5jbcvnv22I6pcY6DfYHmveo7mpKOk+MZEB9tsurRAp5vmRB4L9tPE7+4Kuzkdxpt8HAx+om3oJ8mxlxk38uls4XtQsKDCJcjD5aUlMhqSnd4IuMxCe9HlJsT7DZZvqwNeZI88511YXueHM/exng7k3ziKkWWmJP4OeSRlUnkc+oq+QNCuVcQj/OHaOhjqtPs7rUpLS2VzwgJZ1xxY2WJmZCUaYts25Jomxv9X72cZNR3NCecteoLNv/bjvMDUv8abBo6d4px2qkz5Zbd435cBoNh80E34GhsxOlrzOLxvG9ilutz4na7d9B1Aw3vwuV2nIZ5dFlZWdTpbOSz7gdIi9fhlLg/qBzqvlwZXV/Lp1BdRL9BnG5EeiLhcjaU/cBfn4hri/Y6ap8YA++RdZG1sTOQw846Mq7cnlK/zB9dIkvwBf2PSIgB94RT3xDwx/i0S0RDsCWtMeiyHivPhBhjPT4PMcpou2PGL3kSOJw2bAHwMPzN241jSicYfD1+8Jw0BJuDus5z7XZDGoMz6xuCTZc0BJrf9wWa9uNHNQtD7ov6zuk7+QL+YEPQf2NDZ/O6ibdPU4sgO5m0bGZSD+wGg2HTx6NNYsCAk16Ho3lHncW76rWSkhJZrs8rPQ9iBDn2U5+eNgWoS3SVm3ThD3Md+83lPBdKjwfnuNEN0Z5C/RMOjxHj7qrHF4QWPH996II7LgstXHlDaNGqG5XfuNOuOUP17M1/apHyQyf62393f+j4K09Wn2wfXvt0aN/jD1Bj8PRye0pjoCXql64+ML2CtubJho7p9YRXNXT4357c2XKrr9Pvp616lbbnmvqOGdMaA/7FxJvGdU6vcxQlvXkfOredcD3Ol3uq6wsKCpx+VpWDX+7/Bw6dbP9OQp6HuHVV+T1El8B04g17njhB1wvUYycJi4qKZKmyMvLuYacRN47zNze4afOQvyJqgeXu4KH5hLxpzepKBT+ChGPtekN9wJ+0G9tgMGz68AfxK123uUHjKSsY9Jry8nKZbHEschsin7Zm6nk2ZTBKL5GwrKxMOZOVnrnLH5ofan1qcej0G89R7kcOO/MoZaiJ0Sbp+594UOiOPzwYOrltdujws48Off/CY5VRd3bgQmXUifuT2KP0nPqluyRdsShTGoP+qCN97tWeyFne8AoL6jMoz8Qh6G4llDXGf0J4InrlTNoFbB9NIGPWfkn6Y2LwkX4l8mtkG7bFnZdyVEyoOlxqa2ttB8SDudbRMW1V4ZVDdme/i5BWWx9JU2Pa0LdXVFTIZB01scHtdo+mjJ3Z74fI1VJf0WNkyufYqJFn2PSwLf999YREkG+VrusJDUH/abqut/BvyXidNhg2Y3i/fK3rNjeqMnA7kSlcHxci612+TkN/Do1wdDzTpgp1fVFC9Xk1wWfRTETG6enl95QJgeZtdV1PaQy2fMR5TufeV2FYZXOPXtHzGLZgeC7UYsCZwAN1FTJX1yeisLAwYXesDg/mybquJ9R3+NVCwn2JL9iy2Q+ANhi2ZHi/HKTrNieo/0bpJcOYkwHoZ/O+X1ReXr5JLnmoG3Aydk5Wgbj0vqvU2DlxGhwdU5fAeBORyRZ6uT3F19ESc6/qg371ubK4fXDWxI5t8iYumb6dr7NZ9UT5OppVz1VDoGX3MYFdR4y9f1TMGDRf0J/RjFvuVdxqHuiiPbfOcZQa4qxf1rbtM/gTELfEWWlpqaxxa+gruLl323Fu7tbONGH06NEJB/CT9xe6Lhk8GOoB1nG5XENk+jJllXjD05Dl27lMYZaFpBMeNx341/K/ycGm0Q0dzY2+Dv+UxqB/e34IO08O+HdvDLQcMTnoP3Zyp//4yZ0z56A/r7Gz5XL2ubwx4D/H1+k/FTm8MdA8vTEwY0pDh/9X1v1Wzx3TGQyGTQLeLZuUM9dM4B35sa7bGJSVlRVyHU+hPssIb6ypqUk68WOg0A0zZax9szJ05HnfDz267pnQviccoD6RXv/aktCshXPVqhEyPi7GgOvDMXANwZn+mO1A8xOTljTXWPOnDJ60ZMb0ho6W02iXbmoMNE1rCDTdhfHWVL10myENQf8Jkzqad3fu6ws2Kz+saSD+CfOrqqpaKysrS7g/7aKM9Kw+JS49aFcPJi6fMZXzXPnsiu4o8o4h3UMo4+nUlzO2D6Q8aYvPLRfLnXtN/nz0qsOH7VkScv9Hom8iHEboR8Rx712RPAH0VeK0V9yPkHYFx1isamvoc7K58KXIYVz4/bjgoxDpus1n+3niU0tKSqKznrxprhXoycABcDpw3Dt0XU/goUqr/gaD4dsDDcgi5CJdvynC+3YodX2Kd7AaIL6pw7u5mff9LYTXEB6vp/cXR19wTFyPWio5sS28nJdTZGycXm5P8QVb/lJ905SUPvoaAjMTOuh1gpG3jy/g/66uFzCu9tJ1PCejItFBPDfRiTg26JoiUWWkOeGe1Ulo+25z4g13rsRMfmH7Muc2hn02xz9f4rStEyzHmqscN/o5njxx501Zx+k6Qy8YOnRowoePm/tDO85NWi0hN+dhJKmRRpp60CIDGb8vccLow0d6dIktcULIDY6Z8Un6PjxAhfY2D27cA9ATKPdpXWcwGLYoBtfX1w/qa6HcQbwfB7nd7kHDhg0blJWVpXRyvO7E5XINGjlyZFwDuzkyePBgMSTG8/5+nPe/LKPUpOfpK7bfbccPrn3lllDbM9e8e8l9V51+1rLzDjv6kuP2PmD2QVtvPXPbCZNbpozf+7h9J81Zes4uZ3Ve8MOzAucvPf/2Sz5rXbE4dNSPjunz8ZGNweaRDZ3+8bb4Ai0TGwLN9fWBFl9D0D8Z42yryZ0zt2noaNmqIeBvbAw0N/g6mif5As0TJH89MnFpcyr/o4O9aY4vT4E8Z0MKCgqyeO5yaH9zCwsL83h282mjC2lri8rLy4sxzkpILxWRuPTMoZeJEeK2pIA/GiN41sUXoTgGjjMAU8H+t1NeSjdehn6AC/+uuP5wSnXYr9sabuwvebhWEbYTRt16cKP284YdAUb/UXrD09v3Zr/n+JHnsn0aRtz2PCjyObWV+DT2G0n8OslP3iZ7397gjSwsbTAYDIaBg3c6r/tqcT77EGHarqYMvYfrHbOUVV/AfYz57GvYyHjDrj8GYVCpiQVexyBIGx6EHzviXyIJp07zY/2BrusNGHMeXfdtgest/2pKuhPuh3zqlini20pcL8dgMBg2N3iXPcw7TdqS7WU8l55u6B1c39t0XV9Be9Tn7rsMaYDREGc9czNOKyoqyiKsk21+UCdqWSTPH3RdMsh7LA/PeH6UsoCzy+12j8jOzs4tLi7OKS8vF6eDw/Ly8obk5+fHiOjJK9/Wc2Uf9i+nLv/Ty08Gx3qN85tAuAfHUQ56qUuQ7dezsrJUV6/UCZ048KxHv4RjdcSW0r9wzOUc06frM4Xrcq+uMxgMhs2ZkpKSHN7NR8g7m7C1tLTUGHYZwnU7jzZmrK7vS7gv4sC3luMkXAnJ0E/ww+jR4E1u1gxd11uoyxG6rjdg1MwvKysbQrnPET+dOqueRB6yWbJGnJ2PdLXgL0arjNmIm4bdX2BcKmeHBoPBYEgPMRZ4h+/Ke/tO5AqXy7XR/XRSjyNpQ84m/BFtyNWESwkfIZSxf9JpILo51PvKIUOGDOjatRzzyIqKijzavHF6Wl/CceQL0oOcZ9wECkM/MmjQIHuSwDAeuv2QKxGZ8hsVbo4sEt9vPxRu+l3c/Nd0fX+Ql5fn5px+xDltVL9G1OFtXdcbOJ9+6yI3GAyGTRz5s74eeUpP6C9osz7XdenAfs/ouv5CvirR5mXp+u6orKyUlR9WYiCPJtyf9up8rm0n4UuEHxH+H/K/mpqaz0n/rbRn6F8j/jLxV5E3ib+P7s/IvxBZ13wN4c+QhxEZB3kCIm5XRrD9jl4Hw2YCNztYVlZWxYMmM1n6FR6U3yJP8GD3qPexr6AOx+i63sA17NJ1BoPBsKVSXl7eyHv2Id71l2OQjNbT+wOOp/ypYpgoJ7xi8CAxvkTJk7FB5YT9ayl/NKEXA6oMcXF+MkZafLcpQVeMjqgaO+2RrAR1hDIpUIyyMUive+U4t7Sd83K8vXWdE6+2RJdhM4KHrcwem9af8BDN5EF5tKKiIs5x8UDicbhT6Qs4p7SdKxsMBsOWSJV8egl7OLiBcIye3lN4n19DmyKG0SPIfG9k0gDhvRyrT4ccyZhxXddTXC5XjOuuVNBGT0Z8iDL8OM8i4mJM3i/bBTBq1CgZ166QT7fi/Fniubm5yohlWx2Pa7K9nc+Ga9Wm6wybCdzQRl3XX4jbE1030HC+h+o6gYf4HX4Qu/LPZjU/jt2IH0f8Uz2fDnk+0XUGg8Fg6B7ex4VIk7x/ee8erKf3N263O2Mfp9T1OtqHi506zuFw6h+3Hiv5OjH8ZBiUrMrwEfnUMpe0G2m3u+yzJ5KFTJOJhqWlpaonkTJWSIjBtjN1eo/oYNIKOM7WyHTqo4y3kpISOfZMjLjoGHQnpJ2r677VcLH+JYYP4Xgu0hQuwB7E98dAEa/YW4s+IhO4yK2EfTruqi+RB0/XZQLnezNypK7vKVzPg+Q7v67vKyg76hg5FZzTEu7b0Tz0jeXl5R55yeh5BMr7o64zGAwGQ8/hfbsD798PkN30NCe8f9USUglI+bmU9/s8XQcjaH+mUeZxYhAhq6jHYgykmHVWSX8UveoNI88BSBPlyYoIgwmXky5LWyljlPgjBOKk9xnkSZfLNT6y3y4bSux7KD/tlU+wW/p0WNEmDRfmtAQ65fA2BYO44bW60gk3ukeTCdjvHR6wEl3vhBtUaQt1FfcdteynvslTr13YHh3ZlinJ4nYElWekXk4iyLuNrtuUob5zdZ0Tu5ucaxrtkk4F19QYcAaDwdDP0DY5HeIO5h0tn2UfrQwvP9kS6VR5lvBM+awqxhNxWVM06pKLdu1o2Qf9HuxX7ShvQKEeMUZhMqjj1YWFhdGxfOXl5THj1WWVBue2Due5j7Y9ivP3OT8Hs618z24R8FD8zLnNjfguuvOQRVyI77nd7kJ0J5E0iHDviGUu+aY693PCRY3eTMqIOudlnz3sOOVXDxs2LOYbPOlqUeNUnyYpr8det9n3fV23ucO1/pFzm3P89WBwqDKa0GF64AwGg2Hg4d1trw2qDBzaw4QusaqSDJvh3b1vVWQt0XTgeFeSf1uO0+QNuzA5mXBWJDwe+UEkfhlyBvHTCU/nOGcRn8u+h7M9jXArwhv08p2wz93kWcx+1yPBkpISN9v7Yl+MI7wWnZRv9+Z1eMO9hTIu7iT2lbTjMNJkWS7pjbmDsI48+8jYO8KZ5Ak4jpV2b91mDyevnOlysfbkYuZiIVcgfvQr5OYik9huZtsnPWOIMrK4iDGWsBPydjri57O/OPS9nPjDDv1V6OQT7cFDhw7N5ThzufDK+vYm8SuHvlLXsX8i3Sm6TqDuUQNS8Ia/s3cL+a7WdRUZrqcq68Hpur6Ac73Uuc01PAXdCdT5euL3cV0ns70COYz4rNLS0hHE3yF9OtmHEe6n7d/tODmDwWAw9C+0GWo928LCwgIJPZHZl7zH85z5NmVoJ9Oa4OFJ8AmYtilugYB0oKxZuu5bCyf7iq5LBx6ieVzg37N/3AoLqXrQ0qE6vB6q+Hw5GHma+Hopk/hqLZ+M6xolcTFakA5EHAGeikzFOncRjvVGPgnzMG0VKeehyP7vVUd6ING9QPzNDaWHoYgyyrgSuY48R5NH/NVMLyoqKmX7Um/E2Kyrq8vhmrRxjN3IMwt9gH0n2OWgS+tBzhRvN59Qm5qaJM/RTp3H0ROqQz0/1nUGg8Fg6D+qI0OOeDffZ+toT65h+1LSchFx6XEVofwZP7esrKxow96bNrQ/f6kOj7N7lPBh5CHOQeJPkvYs8iKyiu3VhC8jb0R0L5BvpSc83u5ptkVWIE+S9wnCxyOidMirHKNKP/63Gq+2thnb4yorK7dCpHt1NKGarsu/Af1z5yGR/GsklG5UdMuqw0ZRQgMOgybGj00yvGGjaDDlfEC5Rzn0OziyZQz121NCyt1B6oixVe5M50cRN+umr+D69ct6o5zHcbpO4FyTDnolrV7X2VQbA85gMBgGFDFAaOumEr4r28QnEr9KtqVjoBh4N8tnSxnzdgbyrO1Kw7AFw0Pxkq6jgT8N/Z3I7jwoLV6t50vgQdrRjmOYxQyQZ79Xnds2lDMXeVTiGIbbIWptUR3yJFyr1O1252F0JdwnHbyOT7ubO1zjO/hH9h/O6Xt6GrrdS0tLZYzB5eR7xRsew7A3Iv/yZL25ifo+NuT/SNcZDAaDoX/wOoYWZQLvceV2w7AF40kyUDIVJSUlCf2v2PBAJvR/Y8+E5Jiy+Pu+8n2cMG5sWLIePIG0nyO/5xh/QD5m/9+zLctqiKdqWX5DPoW+4A13ycqyHL9CPork7fEEiN7AsQ/UdT2Fc7qL8jrkGnH9JhCP+xyKQR2duIChPbO8vFz/p6bGViTCaxz5GgwGw4BC21TLu1c+l95N/Dnked7d8snwMeJ3EN5CeAO65YT3sr2VXoZhC4UHYpqMDUtHeMB+q++vQ56hGA09WqFgyJAhubouXTiPx3RdphQWFspaeMn8tg3Oyclxy8wZpD47O7vb5T/4wcl3+aQGaU+gfupeROKyvmyfwTX8l64zGAwGg2GzBIPkBzSUQUIZVH8uck4KOU8aV0+afsc2VTA6uvMF1y1ci4MqKyu3zUB69a+C4/2WevfYAMwUnoc/67r+hmPGGFic82+c272F8pp0ncFgMBgMmx0VFRW1+uB7jIQ41xU61ZFlITZXMKZSzm7cFOGaf6br+huO+ayu6y/ks6muKysrK87Pz8/I11syqrck/zkGg8Fg+HZDo7ZU1wkyS0RC6bEgz/bioiJBnhxdtzmAQTAUA26f8vLyzWpVgkQGzkDAM3Aw97rC4/G8oaf1FanOjeNOpw4n6PpMoIz7OQflkkXg/k/hmF9RboBQXKhID/TdyAPIY8hTNTU1zyOriSeVSPqLyErkGbZXyP6EDyMPRsrsS3kO6SotLe2zhZoNBoPBsBlCY3CzrvOGB9C/UlJSko/hVk+euFmaAo1iWssXbYrQmIsH5AHv0eoOrukZ1Gs9xmUedczH0ChCSth2se2OSBn3xY1IWgH3aiXp/eYiBIZxzLyysjJZQ7bPnSxyvn/RdYngXF0cfzH5b4hIEHkGeRdj6T1b2H4eWca1PIl9yj2ayxGu23c8sZNLBuyzdHdgmOXrukRwnm26zmAwGAxbEDR0S3SdDo2mW9cJNCL/Zf83SR9Q53Ji1GjbMf7O0oF9+rQBzM3NHSIGLddjONcjKzs727ncU1qIUabrBIwnD2XeIXGO4bWSzLLknDJaPSFTqsNLkCXtKesJnM+/dV1/wzFfRNRsVM7nkYKCgjyu78XoDs/Ly8v2OnwHEp/E9b/dE54ZtRf5r4/o1dR4tgPE/xrR7U7eI8hbQrhcdMR3JD4ZOQgjexQGmprhTN4z0JUQPifbOTk5xcR3ojw1o5fwOdLHs38D8ZcI86UcK7zk276RMvr0XhgMBoNhM4JG4AFHXM3AlAaIuAsDrZIGR5YjatywxwbQZ9OoNNPA3B9RJTQsegvHacM4OUbX25B+CfW4Stc74VxyOa9K6irrj40klDXHZLH4UuKl0rPFMdJ2Rms32pnijTgyTAT1uEvX2bBfkPr+sKysLJ98CQ1m0qNOgVPBuc6mjH8TzqfcHcRwiBgPssrCIchJbF9AKCs0LCK8ziGyhJXdA5aOSH6R6yhrHnIucirX+jh0/0T2Y1uWMtua+owlLosZi6H0OPKkXve+wO12y72fjUElvXMLpReTsAV9EUb0FDuf9EBTB/VcecK+AyvYRYwo2T5EPmOSJ4/4HaRdSL1/hJyJXIQop8oC8TmILAE2ElF+AjnWSM73APazlzETx84XU5ftyCura1zGM/tr8k8mLmv0yRJv6vdF/G4Jyf/7yL4Gg8Fg2NKgMXjREZcF3p+QBhW5JKI7h/h0GhbpBfo1YXT9LvQjaPDUhAfSbsrLy4uZDIHuTRqhr5F/If+pCbvq+I803IR/Q9YhX4qQ991kg9U5ztmILD0R/dxLGdKzcaQ37DPsItIbnPs4IS26+HwqOJcC6pLMxUYUOa5z2xtx3utEfJVx3J3FKNHTyP83XSegT7nQOuWNk3AQ6GkC+y/UdTpyD6x+MrQzgbp+ousSUa3NSt1U4L76dF1fUxFZj7aoqCjmdyGf0yXkeXjLqTcYDAbDFgQNacJVBRJRrS0ETgOixg4RLrZ1GHiqPPJmPOCduvT5MkeUeY9zm0ZxtHNbh3qrdURTQZnqM5pj+1mugVonlFBWBPggMnbwfK6H9DidSPwkO3915DMkoTLYyH8LIuuLfmnnEdgvaa9jItg/5edwjI6MnRr3B9Rjpa5LBdfpcV3XW+TzJNfrYl2fiFGjRqlxf9wP1fPFfnsSj06A8YZXhujxCho9hevyjq4zGAwGwxYCDVGPP1PRgCSchUqDtoByE352TUV15FOsfJoi/gplXOZMz87OzkIX0/sleJOsjCB4HT2MZWVlqueJMq7PAxrxn8o2x7q3pqZGxpZJWp2dPxnkeVDXsf85ElLWND1NRww46iUSM4kCfZcdLywsLCL9HFmjFb1aI5XjjscwVJ9POd6InJycoegq7H3If6EdTwTlxBizG4Pu6pgI9rld1/WW6vCn2zMJP6b85woKCuQT+3Li4iFcOUwm/qHb7R7CNZdxZz+z960IrxDxW57T6Kds7kcWZS0n/HGiGdv9Acczq0oYDAbDlgoN0yJdR8MgDmrVp1EMiBryJGz40Sddcoq0Gd7IWB3iMgZoDuEPCb8cM2bMUI7RSEMpjd7+6E6TfGLAEX9JPvMRvs3228Tfs8usEOulqkoN8pY6kecHnvAg8VYa0xGyX3X486x8shX5tzTO9v5O2O87uk4gf62u0yFPu66jvBg3F+RJOqFADDhdJ6CP9sB5w708MmZKxmup5aSkzsjVtbW1QzjnQmQi++zj2OcsO54IbmnS+6VDWa8hT2m6J3gextjbnsiao4SHk9ZJGE3jVsXNViXPT3RdumB8Zzwp5NuO/EZ0ncFgMBi2EGgEpubn53fnDiRuzBT7zdJ1TmjMdybPHYTnEx4nOsK7kfsxrIZhTJyNASKfHJ9DdyPhu4R32vuTLuuJvp/JxIJEYOC84NwuKiqKnuuQIUNixuwJHLPbHjTqeZ6u41wmud3uAolzzMMp5xGJEwZic6r9Expw6P+k63TII0aSuh+ci8xcnGqncdyUBhzpCccYJkIG+HNOC5ETOcahgwcPljF9+3A/DkCnXF0QNjn3YXsqeZ8n36NebeYyaR7ndqZgtMbdq95AHYPU8XauyTI9zQl5lLsSXS9QRpzLD3QzONdDdH1/UN2DYQoGg8Fg+Bbh7PlJBxq1l2jfJ+h6J+RJOqnAiZRlx2n8ks7CdEIDGbdGpzdJ7xP6mHFCbJ9RXFw8HGNrhCfyKZQwapCRvsuG3Ikhj5rgoelklujuyCiujRg7J5aWluaij1vJIFkPnDcyC1jgHH9gxwsKCmKMF8q2P6nGfGL2RgzlZEiPp67rDRhzaTmTzc7OlrGSvTLAuKa92l/HG+4xXIkcg3GYTdjO9VHrrpImM0/VtUK/P3IafzquR78v57wT+fbkHl4r9wHdEsJD0M9wll9RUSE9w+I3TybgnO1M6yuow491ncFgMBgMMhZNzXrsCTQu9+q67mCflDMTaQx3omGsIxxOo/gPVOKz64qSkhL5JJvQnxj5PrDjgwYNyqKhlc+OrehvJPyGRnYK8ei6qN401sokf696k8R40HWC1zHhgkPI5+ITMVwKie+LiLuJPIw5cd47mbq/Rf4z5Twc+6hxeMkgf3c9rf3B4KysrDiDO1P62oDrLVzrw53b3JNC5/ZAwP18XdcZDAaDwdArMDA+xLAqKCoqyq0KL7mVNXTo0GHoF4gzU9E7hQbxeJfLldQh7+DBg2Uw/9k0lFV2TxL7FNKILWL/uE9ZNjT8+eSLLqHUHRwj4Zg5HbfbXVxTU3MBchF1uJ5QlmB6llDG8P0EeQ15AVmBSO/c+ZFPa6kMERnb1qwr0wHDttu1Xbl2aRlw3z9iRtYh+0xNOEElEzjnFu7pcLl3mr6Ka1XNddu2eGhR8b3v3Br9RH/02fN3POP6+3ekrq5csPU9NeDknuTk5MT1PFKHU7jW3ZZJnujsYYE698p470s4NzMGzmAwGAx9Bw1L0sHqNIBJ3XQUFxfLp8e0DKhM4bjSa7WVJzy54v/Zuw74KIrvfwkQkpB6vSahhCJVUQQVFBEVQUWaooJIkZrchaIUCwgiXUABpSNIB+lIS+4Cduy9IfYu+rf/VOb/fXO7x97s3uXSkOh+P5/3mZk3ZWd3Z2bfTnmvKSgbRELEl5JLhw5iWhIsCbhOLZEXK1A/r3QYYz/qtNcdPNRB+vReA+8dcilMfKQlu5tPwP9iamqqSkgRAWEkeIgh3vnS3WOuY0R3gSDazUBZdQ0G4/fsxBIWou8Ws15d2zAIq3Gtzm3CNq0Yyh5dOJA9NKMPs1jtkvLmdHbshans/aP3sbeevpdtWz2c6v6YJcXy2u5fC9muXw4F6edDdDBlhcvhegb+kzt/Oshk6ntn/7+sFkvuypd/ZY+9w9jad0FwZ+5+g6HOXOgsjQCH65ByXTvqUU9656SomA5l0AxnHMo8F/6xoLtc0iEe+KdJLs3I3kV+5H0e/hvhTlaU/QDq0gjuRYijdjQTblHt2rVjrl9FwRNhKV6HDh06dOgoFehj6CnBNJc7iiUCGfhA0odR85RoRYOEJZFXXuAZ8MMMFQ0833IJCahXhtFksbNvH2EiQRCbOH/azSr+q0cmIi5xqsj/++uH+XP7+eMHVXmys7N+6Jbfi+34vwNhdG7b8042P7e5ir/u48cZpM8Wj73NmJJIiDOZjEap+nGo/98ktBDhWRA9BXoQAtlNDoejDtqMBXGZCKeBaFY3ATz+zMAPIM10yU9L53xmGGnoAE1rtDmV0A2+R3JVS8DIawXxk7Z2u/0cpFHtdaxsoM6XiTwdOnTo0KGDPlKNsoKqOA7jo3cY7tNw3wTvuEwI85OTlBYfMV9OTg4th0WcyfIodJ2VBJo1sVqtYXZPKxqoT4mWF0oL1FtpKL3CkJaWFtMSaCTgWdLhUpsocBEZDBl39L+5g4q/a33ecMQdFfknvwkKcN+//4Aqj9Xm/t+1w7qpBLXc3PqcRP7j3z9BZTXUEuA69uzHD5WUZgZOCbyLrywWi0rJLtpqzAqsz0Tos286dOjQoSMi7HY7N5otonbt2mE6ufCRPCLNjPyg5Isg00BI82O9eqQJI2aQstqIS7LlhaeC9xHhWTRzOByVMjMSHx8f2hNWFqBeWRCEHKLARWQ2O0bNvLe3iv/Ry9MgKJg+EvnRBDiny/N3z4LeP4qCWovzzmbnXHCuSoBbe3wrlVVXS4AzmzO54FZWAS4a8O474CdkO2hWWQj55+J9k53XRWiji+En1SSr3EH1OeuRhlTm7KhIwrUex3tsLd6LDh06dOjQwUGnNcnFh2gPKdCFy9Uk4ON0qdVqzZbi7kP4BmW+aMDHh3S9/UxLWGKcCHys5imCmhvqLRaLammrtHA6nd1FXnmA++uKMme4FSpBKgp0IEPklQZ4Xw1IgPvs9RnhQtd3j7C4BOvDBkPNN9kPSxj7XqIfljKz1clsdkcB3xMXLqh9iiLj1i6+je+VC9H/LaO9bv/XqFmj72kPHNGe34rYbpAt07bb5XC+s/KdDSHeYxDePC6uF696vzvnsfUfMLb6jb/Yshd+ZN2GjA/NMlWGAKdDhw4dOnT86wAhi1s8wIeTn+CEDNcU/rMg2NF+n5Xwky3JeQhzSwCuGExQGY1GZHF/q7WkJQLl0h4m2lzfOzk5mQtw8A+FcLSAZrlAFyDcBbSpevXqtGn9M9R5j1hOSUB5pZoOjAWoy07Uv4XILy8g1JZrORnPpzm5dWtnOfA2XjEYzJ8YDKZXHQ63X0hqYGxLuNWGeKPx3HMa3Xn1la2mIc8ICHVcUa+DW3cwmZNSbeaEZKvZ5faoLDBUBLQEOPBaox08g+f9MZ7NCdDPWUELHCdBLBaimWPk/wkutZ9jKO9t8F+FexThp0DFCBfBPQjePmpjcOnwSADuy6DjyP8DSFW2RCdBZB3k/0DfIP1zyPuoeC9VBRZv8SW2/MClRNaC4rZ2X3Erm9ffwjyquKF9eKCeOb8w1+jzn2X1FZ1tyQtcxNPl+ftavYcr9EdJhw4dOnREAD40nUVeNCB9iRYMCPTBFHnR4JKU1hIgLLRSxikBAbMlys41aFiNiAbkqfD9aqW9x1iRnZ1drrri+Z1Lri3NuseSaH7Hkmx+A+4rdpOd22S1plhOzC1exB56aglbdHT5Hw+/sJLhuXI7s7Z02zcum/N/DrPjhMvu+kUWlm3p1m/Ou+x81vT8Zuz8K9qwJuc3/Yv4bofr7XEr72ED7xuyw7twzNvzih8mQSnNmmo5ufu3Qrb6/U1sxVtr2eKXH2Uup4tOJtd6KPAJW3r0B7bhA8Zn4syJhogzcLj+78owAXWNuPdShFherEC+UrWvSKisNlJZsPoCFVJfCIART6Hr0KFDh44KAD4wnUReNECA40usivBlIJrVeBX0JujDrKysT+C+C/ejrOAhCOKR/xPQZ0i/0BGjdn8ZyLPMarWWqEKjMuAOHurYB8FkBfykqZ8TeEvgrpVoHcKbQH8gHT8FWVog705yc3JyMlHGg2J8rEDeC+s2rtuQVHco96BRGEJUhxVvrVPtT2t4diNmS7Wp+Ju+3N4pJSUlldSDiHHG+Iy+Dz29RMXPMKStnnt4kYo/YMoQZs2oGbb/jWj1m39FFODcQRwjP9rMMIn3hNPp5Ap1wauNcNisDwS8dLSVpuTHs5ggufeSi7SpoAbkR5r64IfZgUV59RFPM758FpMA/zXkgr8ylDBGmEwmu8irSnD4/GHPRwv2PL9qdtviK24n8nTo0KFDRwUCHyfVDBx9wCBoaZrQgpBxtuxHun2yPzs7O2zGwhnFnBOuuRgfSgc+1hFn2rSALGQWi8mKX3H9AjGNCKS5Ex90bu4L/ilifElAnufJxbVDHymXYEc1NTU1TDUF7isF+foreaVANeRtKTJLA+S/1Jxs2isKUCTAWY2WxotfWa0Srs46r/HvF17dTsXf9NUuLlzB/6cYZ6puXDltzxxVHqfJsWDilqkq/vWjbmJ2Uy2VAPfo6/+LJsCRRY19cDvTCWi4JETTYYJL5TTwbwYtwzsKqSLBO6eld1r+JCF7Isp4giJIybScD+XlEQvpBiLNSJlP7RN0rdFodEjhC+W4/xJs+f7Vdq9/miWvqJfJW1jbmld0g80XGGnLP5xt8flbWb3+MaYRRXXM+cWtrD7/TJO3qFwzxzp06NChoxTAh+smkRcN+EhynVkEfBS5AXf62KEcMoo+KC0tLQEfT6ecBvzB4HMlqkh3A8J24lGY9g7J6UoD5O+HaxdlZmYarYAYLwLXXYg8PUR+LIBAQTOOXBjFfZEA6QWRcuCHQavBJh1jNPvWhgQB0AxKi/DbynJiBfJ9iTK+FvmlAd7RFamGWgtFAYoEONT5/CWvqgW4Jq2asouuUQtwW77efZLK3Plz+GwekTnRNHmOf4GKn2iovvi+3bNU/D7jb2V2o1qAI5LrLgpwaDu9lOHSAM/ytOtsq0BUS09Pr4XnATnSaEPbM+InKd1sNtPPC7XHClniVSK5oOiMsT6hQ4cOHTpKAD5yoVksl0KNBz70fMlJA6EZDKSnWToSYAZSGHmugDyVBZdmNL5F2WT0fTnNnEjxdOI0Hi43I4X4lXJZpQHy3WexWOhwBS3dzhTjRaAOn7kUtkRLidD9KkCzNp+LTCVQtyMiLxbEx8cb8dEOCcBlAa5NB066iQIUCWHgx3Xo1jEYpiXWn4JxbqebXaQxA7foheW0p63Bhs93/E+Ms6SbJ7S6ss0+uQx5yRbpx7fpdCH3b/9xfyiuYbNGuI6dL5muefNv7pLwNmv3G3/IdRcFOAijV0KAIQsai0B8bx/Kf1mZBj8Cmvvc0O66IL9JKx4C0QCRR8v8yMOXS5UwmUypKCe0pFoauKXlWiVQ/4/QflUKhSsL6CNtcc3wwyoasHqLVbPxJSGt+9wwVUPmkYWqZ61Dhw4dOioB+MDcRy4G+Ak0q0RKYFNTU2kJcD0+ZjbwaabpJUWW0N41xJdraQnllmuGBB/heiQ8Zrjdv3/YvPnmY82bT5DpePPm0463aLHgwxYtNlk9Hvbx2Wc/Bf9boPfBf+n42WfvhX878vFTuFFQqr16MvDRDLNEgXu9CLwtoBGgfNTbC3cc3CmII8sWi0Ar8Ew3ILwbwkSRSIjfQAIraDmVpSxfCcR1xXtMyzSks043d2EksHUd3J1deXPn0EwXrtGt5QUtL2vQrMElHreHCy0Ou6N7miH57xRDAilt/uS8tud/c1Hndn4e53BckGJI3O20uw4kG2rOcTldq+SyUOd2Dqu9a9urLx6Mcq+T+QJieo6iAIeys8nFc3oUZXeSntck8MfJacxmc6p0uOUeCsO9DmmmI428/81NLnhLaBZLKrc9wvzHAukvQ5oihN8Hn2ZSH5P4y4JX4GXQwZkKgXLmGde8RBFF938WrjtUyYsE3EvomVKdUVYc6DZlGhmeCIcpwH8d98yVKFu9gVEy3+ILNDMYNsQZRuzLNIzYUdOaHxhg9wVW2bzFg2z5/oU2X+AFnvCm+dWtXv80m89/oS2vaL6cX4cOHTp0VDLwMeEzWAmAQVqWwUeABvJ4fLQTyY8Bvi7cjlIW5UeDD/wSyJwRXyqVgY/DjYqg6gOO/H6R90/gWLNmHUSejIyMjJq4L9pLtSo9Pd0ECtNVB/4Wic5T8nHvn8p+PMdyzahFgluxB1EJXJufKFUiNzc3bKbEZrIOTTekbrWmWjakGVK2I89Y4veeNiwxMyMzpe3Vl6fXbVI3xWg0ygJVvN1q74931h1pW9stNi4oVK9ePc4cZ/wOhc9G41mTYUh/JT4+PjEtLS2pfoMGrFenTqznlVey7h07nmx37rk8T7169f66sl27v3MbNmR1cnOZIS0tdGJRFODw7EKnk5VITk6OuMeSkJKSEna/WlDuhzudQJ/7lVw8y4lwquM9vgi6G/1sGZ7tBtzzjaBrEE/2WvkSssViob2RS5HmDtC14M8HtYbgSn10PfKtwbNLhzsaAq3NZDLRLPEsxPElfbgnELcN194JOgB/Meh50LuIo0NH37kd8WFCntXn99lvW4F+ywwQ2KYYznuc92EIcj5zXqClxRs411ZQ3MdcUOiweIvPNQzZV81wT0jm1aFDhw4dlQl8KCItlYYBg7z8dx0SxNzSkpbk96OsdLi7KIwPQiE+NHdC4EkBnws3iDsACijy7Jb9ZcWHLVqotNV/1aRJ3JMQRj9s1qw9hDO+RPx+s2Zcz50WkO4DkScjOztb3hhPhxU8+Ci2Bx3BhzN0XVdwVogOZpCAQ4bU6d6+l+Ph304uPpwXwE+2Obvi+dBs0mSEP4J7H81wgX8FiOsOQ/xypD8LcZ8iTZFBeu64Lm3kvw3Elf16NHTiIU9vcmccmPe7csmTljHNieYvEPWeuBxKinjp9KZ4cpVOn7qcrp6Tt00P4xN1vuUaZo43fiTyrx7YlRni4vaxZ59lYfTCC1xAUPFBRltQIBQFONzfdjyb0MGZqgS8PxLMhmvwNWfDKhJ4bjXQdkNCrkdDHQsB/D9QR6530Jzv5+2GYM0rbHMqVXTY8wMlLs/q0KGj8oGxfx6IVmkWgh4DHcA35WXQC/BvxtizAP4Z8E8FjUH4PoS3I89xjAMbPYotVTqqAPDSbpb9eIk+iVcDH1KyytAeL5RmoO7Ai95wKlcQ4F8m8koDT5RlwFjxQfPmxSLv43bt+EzisSZNWn7YvDlXPXG8WTMjhL1D7zdvrlKbAiHvHZEnA8/BJvKiAUIQP72LZ/eNzMN9as0ihW1CR5ppkttHySdAgGkbqR54B6rDEuiQfOaTrCCIwlWqIemDrGTPLyJ/16+HaB9cM5FPAp3D7ui84h216pH8eaNYTu0cFf/OdfeSgFIkCmkhAe6551QCXI3MzM0UJwpweI534/5DJ06rMnAfNfBuGkYT4FJSUpJwzxFnhGXgvav28EUD2tVvIi8SbAWBly3DDjUwDvPXt3oL78oceCDZ5g3Mt44o5PsAM/MOusC/yuo7fKvB8LPB6vWnEd/uLT6KvFsMBQcrRcmzDh2R8P0MQ7kmA07MMPBT6mUB+vSzoL7oY93Rd69B36TDev3B6w+3D4Xh7wa3M9JcRuM5/K2Qtjncc+E2wXejBfznIN35CPeCv1C8TklAGbVFno5/OdBQLieXGpvMQyMjPWa0n4b2HQ1C3OVoVOPhnhPKaOB5I+6BQ9zDIk8ErsNnq8qDY82bfyTySgsIcBFtsOK+QzNwqO8UdL6z5DDu8SfZL8Kj2AOHdCWelJWB62kKakpAyOEfTALK3qiMI+DaXCgn4/GicJVpSP8hzZD4l8inAw52m72tis91xzlvWfKG+uRq/txRrG5u3V9Fft78kSSgHBOFNHb0aMQZOENqKm8vCgGODrvcDPpOCldJoP4v430cQt+xUXvBIGuHAMeVIItwBwf7HUajsSaF0RZo9vpC8C7Fc2mEcFf47wCdDT7/EQGvJ4gODq2F2wrX0jw8g2t+K/Iiwe4LrLEXFLc39N+baPMFNhoWsDibz7/CWlA005J3KNc44pDL7PV3Qhx/Z9b8QKLFF+ht9QaWZA4qzEDaxwyGDSUuYevQUVH4bpohTMsABDrVT9D30w0Rt7IgPf/RLwnp6elpbumbSUC/5qtQ6I9aWzpiOSkeMY3FYuFqjCoC9D0GLSR/RkaGg8JpaWmqbU0yMExpTTroOBOBgV/TmL0SaKBufBzChCWndLpUBMpbYjabsxE/Fvl6I7xNTEMA/2mRV1ocb9FCdRr0WIsWYZ3546ZN+Sb2SIAQqLmXjICGHloqxf3wAQDP4S7wX0TwJ9xDB9C9bkHHnFuxPIxnYFLGETIzM+kUYgLKyHFKG/UJKPsHcsGj/VkkRF8px6WmptKJ31vlMAHpeacUeHwWb6d0OlRJaYbkd8zxludF/obPd7D0GmktRL6k/Lf9gxoKezv06MisKZbPRf7F11xCS6LTRCHt6KpVf1O9fvb7wwW4554jwY7vLZQFOLe0FI/nwIWZqgzcy7N4b3Rqei6F8X5US/YQ2hKQZiTu9wKZB38u6GLkm2UymSxwaYvCcNCdoOl4VufBHYPBlutfg382ypiDsOrELAS4T0SeFiB8hU4EK5HUdU8NS35x2OwwBLaICqttFWTRQYeOWAABLEzv5onphtdPzDIs+H6m4d4fZhiyEPadmGHYAV4/0IDvpxnCtmW8NzHuHvQdUtA+F/3zEfhXwyUF7bvcQZN6tE+YzOs9Afcw6AmkIaXtfJwCfw3Ij/C16GtmjPl1EH6D+jP6I20h4vttwe8B/tvZ2dk1rVYr7V8tRJ7u+F6Sei7ad04CIumnlMu8hb7PoKxTtQ2BfnJL1MJAoHsA0QG5NqhTU5T3hacSrBPp+IcgNV6yDfk9Xiy3HUkE/lvgLYVfpdgXvLBDCzLAN+PjkoqGzBXuonGqBBgCyt4k8kqLD5s1e03Fa9zYdrxp0yWIu/ijxo1rvNeiBd+D90Hz5gM/bNHiOTE9BDi/yJOBe/lF9teoUSPsjwUdk88yIE0aOkWYWgiEQ3+Ayo6Ce16M57kAz4RsjCbGx8eTfVeurR/8R5GP9iEMgL8H/I/iL8yIeJrBi0fYjXxhAw/SLVeGCR5pBs5hdgSNyUvG5smovCXVzDe1Oy1O5nF4WJY7i3W86UpuaB4wtOrYhqfd9UvhyS1f72ZTdsxgGFTIYsFz/ScPZjeNv4UNmZnHhj/gYz19Nw7D31x1Kufibu3Z2Re1ZB1uuJwEPj47lGa1MovTyVLhOjyet1EO/6NskJu7H8Qa1K/PPNnZLM1kCh12IQEO9ee656o68G4m4Zavl/zcjBkBz7JUwo38kSgPcH1+cCIWWPP9LWxe/3P2fP+L9vyiV0Avg8j/gi0/8IUdwpndV8zsBQqiMOcHGIS3u8QydeioTEA4Czu49d00A/8p/mGaoeWJmYYkCHI20K7PpxhS2G4u8C1WpodAx3WTxgr0SdLeQAIX798OySY2CXnw0zLqLPh/d0lWXGgsl9wxhuCP+Vb4N4A+R/p7pDL6gT+Dxn7pGmETD/SNQRzphKRl1mL4l+Ebe7M7aCe61EuuOnRwAUeaPSDt99UQplN19BEmqgY+nZ6Lh+DBp4ohkNBHmqZwaTP9GYFjLVqo9pEpgU7yBTrPSNQ5AXU/F/fVAzQCfNqrcDHu0YVwAsI18FeVAX/YrCD9VSnDFQlcn5vfUgJ1LZVy5n8KJpNJtXwg7oGrisD7f8cV1JEYFegvGbjfDLSPdPhTExISakEgTqQl1Hr16tFzoB8E1TOKEfHp6elJ6HdmMUKHjn8bIJA9JPJKAwh3ZdpDh76bI/IqCrVr1464DQFj/BB5v7UCfKyg7RYCPyZg3ApZAMJ9XaWM0/EfAQSKclkRKAuON2tGfzUqfNawYcQ1fhnHW7QIfNSsWZhqkIoGPub8xKgMdD6yt1niaR+keUThVwlqBPAPizxc7wZynS7XmEtatWKd2rZlderUYe6srA/Q6R2I73lk6VL2ytq17Em4n+/dy4b16sVnhWwOB7uuQwfW5eKLOV2M/N3btElHnqmzCwrYfcOHs7sHDWIbp01j2dnZ7PuDB2vfO2QI+3TXrhC53G6uaPe1dev4vjf2/PN8mfSHoiJe14I+fd6XeTJB+KWTtlVagHMF96ip9iSWF/gpqLLPRIeO04UTMwx3QBDbBmFuz1dT4575bqah8PvphkM/zDLsB38P+IdPzDTsODHd8CTS7v1hhuEAzcqB7hDLKg3Q50mPJKnbGgP/GLi3IzwO7t0Ik4aCWfDPh7sAfDodSqtd84jgJ3VAC+DOltI+QmU0atQoovBWElDWzMzMzGQIYU3gn4LyJ4LOA12JsidgrCX9o/QNWg2i61+LdLtBpGWBrxbhR7LEvdg6/oXwRFAYWhlAA+0Kakz+D5s1Mx5r3Nj8YfPm9s9atHC/36xZ7fdbtMj9qHnzsyCgNTzevHk9CHo5nyLu3aZNHR81amR+PzmZ/7GgEX8YXnLFAp03TIADauCaz6PuDdBhlhADz41MjnWE+wT4tCmdLA+E9KPBT/sxCsiu0qliOP8VZZiAMvgUvP+RR1SHBS4499yTGRbLCpFPApXZZkvigpUQh6KWnH/22f8T+c+sWEGHD+4X+R9s3XrSkJjYX+RLZRnoNKoG/02KO90CnNvl3vlAYCGb9+QjpacjD7MH/AvfwzucgGce8yGB0gBlNwO9IfJ16NChBvoKHbjjJ/ojgQQcjLUxHVr4J4D69xV5sQD5Qoce4M9RRMmoAT4JivybKcMlbeHR8R8HOoYP0v2vaBBlmsKNFSS0oRGqDi9Egt1ubyfyRJBqB9S/UpZ1UddK2yzqlma7lKA/KnJfX79eJShl16nzc1ZOzjaRT4Ib5eEzZmrhatXskSNV/Lc2biQlvDtE/kurV1OecSJfKiuSAMcPb5xuAa5ebu5ndFBj6WtrVIc0iO7dOi0sTPZcyR23+p4QD8V8JZZbEbDkFZvsvsC1rizT3zZf8Vyb17/G6vOvdviKHrH6AnPAu9vqLR5oLwgMtfkOhymS1qHjvwQIZGSJZY3IjwSMm7vwXXAhH81SNQLRz3RtkJkOi4np/wmgTntlP+qldco1DO4IqzSlBcpRKYLX8R8AnaqJpuOqIkCzZRDgcuGW6jrorPVFngiU+RfKrnAblSi3rshDhwyZgioJ7lNKlFXQmp2hmTxyaYlUFJT6XH01MyQkbBf5JQhwj1zerp2K/+zKlcyQkrJS5NPSqaF69VtEvlRWJAGOHy453QIc8OHW755gl1x3KRfG7t8zh7W84Fy269dCtvDZZWzApMFs7Udb2WQIchaDiXkfHMO2fb+PeReMYdcN6s4PfKAMzZOb5YGjoLhU7Ztg8waUJu906PjXA+Pf0xgzckS+CIz/VVY3IcZzrv0B91ll70FHFUFFzGKhodKhCFJwSAoPB4JIbQedziGTQfeCT3sMrke4NQSuVmjgJc5wUX6RJwNxg1HeLSh7BPxjQXQN2p9Ax64f9wSPkMu0EbxlUn1o2TNsOloLSDdeCNMeBFL0SPsPNsKl++QqGRB+2WQykTJXUgnRFHxannudNrzDvxAUtEF5qqywMAHpuYmzHXPmqASlHpdfznC9S8Q9aL8dPswFhm/27/9FzOOgfV01avyuTE/UrlUrhuvfgLx/Kvmjb775r4Zud9Irjz32N7/O88//TG7/667j17ixc2d5XxyP//uZZ9j4QYO4Hc7TLcDFGQxvyTNpNBM3acs0tvLt9WzNsc1sz+9F3BIF6dObuGkq2/7Dfh4moY38c4oWwN1H96Rp5UAE3ovmaWwtWPOLw1R0WPP9t9ny/VFnkm35xVqqBnToqHLAGEWqmW4X+TLoYBjGRzrJHxOQlp/MxzhaxyXZOhaB622mMV3gTVWGCTRmi7zKAq61AHUYhPttgWfSVYzXoaPcuKJPl5euH3kTN5beuHkTVrd2XVY3J0i59XI5r23nduz6UTezEfNGMnuiVaUHSwYaa6lnESDw0MnPYyJfiaysLM14dwWY80IZx0WeEogPU66KMLc7KiHObDbTYYuwTavosHXRYc9C2nsMQTNaXI8QOnTIbJHFYqkFUulJ80inierXrUsD4NdtW7UihcNk2uu766+4YoiUprXT5cqyOhwtHS4X6SDicAf1Cr1nSEv72lC9+qeGWrVCgyjSz8dzvBN5Z9ocDm4oXgYGxizUrYmSVxacbgHOZrSODZkP+ykoxClJXFIVidJkGFJDZtMiIduVdZKEv01f7HzZ5XDtEONF2L3FnZVh07C9qZnDi+xWn98PYW6TzVf8lGnYvjCBzeYrylWGdeioiiDhDOOQD+PMOxhvSLMBbfI/5FFYtEH8Q6SmCu5K0PMYe+6N5USoW7IfTT/ooGzQMuTjCuoRx/sPwqQlIR9xk0C34TrDwaonj+MYl/kWlX8CqAM/eYpxshbqZkS9SOecEd+BdNItSjaQxTw6dEREdk72bbF86ERqen7zSEtEZIT7QlDYzBbpQ1OGlUADbu0qwYKBR+NwBalwEHky0ElJXUjYngqEub1OLSQlJUU98eouhR6uWID7HQXqIvIJqGc9kScCeSfiHi+HUHYXbejFM7xETBMrcG9Ds3JyLsytU4dOYnW3AsTHNTZUT08nU2d0QKHY4XRy02lIQ3+5tL/jbUNcHOkzCqkAON0CHCGrDsmxjitQDzpFGo2uQ92vs1vtXa2ZVk5ul/sSKoPaF0hTF9Pw2T5V+7cZLFFPa9t9h0Pa3mOFPT9Q4mywDh1nOtDHMjB2pKA/XSSxSN8a32iPOD62IZxMYwX6ZD/wSE/luXAvDhUSjrKq4gkDflK5Indc6wExrrKBn3wMn85SzbCjnvpeNh3RcVHndqqP0/A5Xrb5611hvHWfbAsPf/y4SqBCZ7xCcmei8Z2DDvw6aDNoCzpsfbjDQGQ0ns/0IB0Z5X0XxG3AIRyaSRLh1j6t6RJ5MpD+sC2o6f51lzTrhT8xzal3AsoKzYyVBJTZElQXQinp6OICS2JiYgod3Qafpvib0+CFDkvLunfIBH5ednZ2RPNlMlBvLkBd1bYt+3jnzuByJdHRo3+jnAcuPf/8sXy5U7lUevQoKexNtrjd3/A4Kc+vxcWsScOGvexO5wlxCbVenTrMYrerjNZvnT6d0Z5D1TWe4xYXDN8eOPC9mMdQq9Yyqe6nXYCrKODdeQVWwtZv96j6h0xnX9BS1Qdk2PKLQhY4YoXdGyh1Hh06zjRgHLpT9ruD21VC4bIAYytfvSBgTB2pjCsl+NiEMTSi6cXKAgmqIi8W4Fnqh5t0RMZlva4I+yhtO7GPbf9xPxsybQTLnz+SjV48jtXz1GMbPtselm71B5tV2vYhoAwSeaUBGnk3kScDcdxmnRKuCjwtC8EjZgGusoF75cuqL6xeHS5AgTq1a/d7otG4RuRLdkqra6kRaZSbu/zCVq3+EPmv0mGF5ORBIv/dzZuZIT4+8ilUrYMSCQnvU1xVFuBkYID/sF3X9iqBTYto9tqYZFQpzXR4/WHm7TIHFqdbfUVFtnz/Mxaf32gteNJu8xaHLWNbC/yXKMM6dFQ1QOAogJBFS6gqE4FlhdFo5AJcenq6WfnT7ggu1fL9bHAHIO5puLuTk5Nrwp0MuhU/7Y9TPOJ243sxBz/d8XDLve1Gh44zAi3bnqf6KMkfpmhLq1N3zf6fWBY6TJhunpSUFH50Gh1ankoPg7j/C/mj7U1QTaOj3FBnRqfke8NigTwgKIEOXuIx79MFq9XKD3UcXrJEJShddsEFP0FYiiTA1dQS4MCffemFF6r4z9Ep1OTkASL/7Y0bWUJGhoovz8BFuAY/TftvUFp7x4o7Ve1dJGXfID8a5wFlGdZ8f9jyR/pNm+JteYEMuzfQi4cHfqhS9Gnz+rNFng4dVQUYv2/HmLyLBDgxrjyw2+2q8dpkMoVtecH43ycuLo6WarPpwJiCf158fDwf21E/vo0Hbnlm8coNXH8Z6hVmCgy8I/gumcDX98HqiB1tO18c+hBt+2Ef26EltGnw7lhx1/+JZXkUe8yokSLcCw3yQXTohu6gvbeHKQ6CG1eMC941SLNIzmMPGg2OCJTD7dUpwvxUINyzcnJyyFh4O5S3F+6juNYBUDLobcQ/Y7PZzsZ1a8ClTnIDqAf+zmi/3hRlmWcC5AGGFO2KgpL3xhv/gHC1QuSH1IhoC1ezkO9Pkf/q2rWkyHeeyH9zwwbmcDrHivyQAKelRiQujtv7zMzMVAkmFYWGTRrWtxttS2yZ1iVOm3Oj0+E84LQ7i11251NwnwUdhf95p83xjMPqeNJhtgdsRts+cy3TZmNi5kpTonEB4qL+fZPKEbmNzyl8iD12fCvb+fMhHvYtGM26DOyK8EF+kpVcZR8xGtJDfcLmDdDewVLB5gvwZWgdOqoaMO7OwTjbPCMjg8Z21c92eYAyVQKcCAg/Mf84QsgTTVhVOtwKVVR4VpPJxbfHi2dmxHePjN2PxPeJ7w+E/1U5rQ4dUXHVLVeHPkIDJw9hsw7OZwPuHcKuL7iRLXltNZu2Zw7b8PkOhh7Eut7WgzTX87T375qt2v9DU9YiD42R1CnwPyD4+6DxJsqCnAiXYPxXhFvQp4aGTwJaaOYM8Utr1aqVrEwjwiX9+VSvXp2nQ54p6DhnzOwbQdbF98T8+X6VoJSS8ifuoecbGzf+TgLYsW3b2FdPPMEaN2rEbHZ7dQhZYYLan089xZwuV0eHy8W44PXii0H3pZeY1eGgvW5Nd82d+ySVJVMNo/EoLl/NjPhenTqxNuedt2f8gAGsz7XX8nrZnE52Q+fO7MYuXdhV7dr90LplS/b30083z87O1pxprQjgnvvt+iUoSJWXHnx6sart2sy2GbR1QJmu750D2L2bp7GG9RuyXt4b2eglE9iUbdNZ07OasNXHNrMlrz4aLsSBzrnoXF528uBADVu+/0lbfuBqa0FglMMbWGH3BQ7Y8otesPuKj8F9CeH9ENrmW31Hetu9xSxpyMtnVDvUoQPjddhPc2kBYSndraHKozTAGBX2U4ixoC3q9RiEn37w10X5D8B9AEIcrVyEzczR3mtDUANAqAyJFwaUx5daywuUo7nfD3UM2SktCbgvrkZKh44S0bbLqRk4Tj8dYLt/KeTLQhu/3MkG3T+U8yiOPljyR3TQ/cNUH0E00htFXmmA/PwwQySgcxzX4K1Dg3eiU1aHAFEDXjJKnwg3CXFkT45OQ6UgXIvC6Oiko60m0iRQHvBJoAxb/joTgHo9KvLOcMSjzh1EZkUh1ZB8XBTEZuJnY9V7G7n/seNb+Awy7eF8+IUV+NFYwDZ8tgP+5eHtG0TqQBITE0PCUqqhVk8xTXno/A6tVX1DCbQ3n6uc+0V16KhsoD/zw1Qy6CQlxuiz4Y2HsKT5s4F4+QR9aBaOfr5kf0UA4/h+1K0xBDtaweGTAQiPrlGjRiKuPwvjeivwu4DXCdfm6nwQ7iPnd0k65USgvGsRV4D7jDibRwJpUlIS6TnV/Fbhu6KprBf5ziIXZYerDpIOrBFQZkPUWTUJokNHRFhTLTui7XVTkpyOhDinw/mnWBY6zwCRR0Cj5XsSED8NDbSVGC8DDTjq3x7iZ4s8JVB2CjqKFelIpxnZIx0Jnh2u2WQypUt77ip0er+ygPp3Q70fEflnIjA4LsFzPh/1VbUJEUh7AhRRj2Ak2Iy2kMJemR56ZinpZWP3bLqPzS58iM0+9CAbueh2dvvKO9mWb/ew1R9sYvftmMke/+6J8HYMAQ7tJKS2Zs0Hm63DH1CrChGJ2j/9xIh8kZxWR1QBToeOqgrSVYaxaS/68AH0dz/6vcVqtZIaEAofgUuG4ckgvFIwKVCWURa4o1izKS2cUfTAuYL65ZbjeqTmiWb37oe7HuPFCGU63D+pvnoIZfUEbUJ821QA/nRlOhmI5/vvkGch6GbQJAiM6XDPQp4e5K9WrRrZOuVbPMC7GBSyjapDR0RYjZZrkg01A6YEo99ushU7bY4XbZnW96wplq8yDem/phiSvkwyJLyVYIgvrm6I87fu2OYSsQwCGpxmRwX/SkmlRx5oFRrpHWKakoAGTh2G69aCv0SN+OhgP4q8qgg8LxLkaF8fnbB6EnRICu/APW4BkXWL1SDaGLsI7jzEzcCf4BT474GfFPeOA90B/2i4BXDz4Y4ADUWewe7gCa5b4Q5CeChcL8KjUcY4+O+GfzJoJughhJfDpWuT/rcwvXq0fI3BXFO7ujM40xk6SYy8rynjS4LD6nhZFJTKSjQDJw6Omz7ZnnbHcvXhhVvuHMhaXngue/S9jWzj5zv4lgISDq/ofRVb8dbasLQk4LkdLk2F0zKs3kAHm9e/xeI7nG3z+Y9Y8wJhp1V16Pi3gcYTkVcWYPy4BP12nSQEPYgxaI5EcxGej+uQ8PUwwkuJ3EEVJs9L/sUgspoTUXirCOD6XNdcaeAspX44HToqDegsn4m8WIB8n4o8JdD5DkFwI71rJQKdqLfI03F6AKHvD7yrMCW3GKAuM0g6mJTAe6IZ25hmRO1m+/OicKVFW77eHVrmJxo8bXjIT8ur5FI82tJFaHMf48eiNv6OyZD2MNRnldPi0Dy0Q0QCGuXl+96kbQUyke1VU4ox6uk2mzfwrcgj2H3+CrfFqkPH6QD6TInCh/ijV1lAP24t8oA4XH+lyFQCY4HmcrASuM9pIo+Aa96jDCNdHWVYhquE/d06dJwxIGEMneYruG+AfqdN+aD/gX4D/Sy5fyINuW/DfVHK9y4aeqJYngzEzUTa7SKfAD7NJj0o8nWcXuAd9Ad9KYc9GhY0lEDa6+TlhWiwplheJEGp002d2fI317LpT8xlaYZEdtO4fmzG/nls8P3DWbchvfjp0G0ngkum3fOvZ/MOP8wWvbCcrf90GxuzeDwXwIhMJlMC6kaziaFT0DJcDpdv4xc7VQJcJJp3ZBHZlKV2zKiNiuXZvYWDLN6iqDoLbV5/K7O3qMSPoQ4dpwta/RJt/HYIPEb0m6+k8OUgL9r9SvC2wD8bP2wrlXkQN1AZ/gcQZ7VaS3XyFHXuhjy0JHoBheHeTcIqiCtix7O5GffaDvx+ynzgafZhpFsg8mIBytsh8nToOKOBRvuMW2P/FzpPYwwSqtkKpD2BDtIbcbe7JVt5Ov454B3Mx7u6AO5EMS4SkF71vpVw2pxbRcFJSbQsGgoLs2M8XjErt+bDzbSEqrnZWIlsW9ZvYjlK2vLNHubJ8jwtp8f9TjCbzS7p4xZn8wW62X0BzRPXkWD3+gOpQwNRT1Lr0HGmAv1YpfLDFdREcFpgs9lUtqUJEMaqoX9WhKWT0IoB+notZQQB95oj8pTAuEMKhheBdoOehCD4HsYL+t5th7uRBGGkWQI/zfjFtDqhQ8cZA9qjgEY8VSGokcHjuuB1gdsDDX6AtOwl2+vsijwRLTj8W4Fn0R7P6FLcO9kBtSJMy8slLgVEQA3kN1JZRPC3yc7O5rYLywLUpwPeyzkivyTguu+KPCXOa38+2/O7n+35rSgq7f6tkM/EhRHxQHetm0w2T1VWRCKhliFxGeUXhbfFL69iDZs3jHiP9mG7/jIMOlSmATgj3++25xc/KfJ16DjdQJ8s92l4VwVazCkJGHsuRZ1Hi3wC6lEb41up96iVBhhbIppr1KHjP4WsrKwj6JAR7aMS0ClVZowkaCqUnf7qpvibZ/WOd7ltFE9EeoNkOmPMaUWCrCPudCA9PZ0G8FJdLycnJ0z1gAy8xzi8K75HDGPoJRjofhXTEMD/SeT907Cb7Y65gaD+Q6L6ufUjPhOrt2heUreHw2YBLL7ivRZfYKiSJ8Na4Nfat8Nhy/dPNBhOaLZjHTr+CaAPc3UYZyJomRLj1XJDUO+bJhAfcX808pNi9+oY95Lgb0LfFqTvjzHpF4y798CdiDBNLgxEXDfw2pvN5toIV4efVFI1Q/wzYrk6dPwngQ7BTy3CJZUgD4jxBPC5BQAZdrvdc8cy9WnCWKl+48gf538aGCgKlWGbzVYDPLIsYcMA4sSzyEK4biRCfB24Oa6gihU3XPohJTUrNvAtCJtQTibCIVM0BMTFpN8N+TeLPCXwbi5F+U3h2nFdvpdEC7jeCpH3T8NoNFazplpYm8su1Dw9a8o77LFBeBP5thHFWTkFTyfa84tvtvuKlxmHB0ymEcXNaw0qNNm8gZWgkeAfhLvAPuyQpgkimy/wscjToeN0AX2W1F3QLP0ZP7vklmyjRgPSvCTyIgHj1G1I/6zIjwY8q1Ltt9Oho0KAhmpGZ6WlNDP8VggIJBQ0RINsBjobH1ZSBXI+3AvdQbNVNJNCen+uhNsZvGvdQbUX3cHr6jmlTPFyEgLAv1jK3xz8OiC6RsT9PsjXXuHvh/S0r4qOih8A3UR8lEV/XCFYUs2h04pLXl3Nxq66WyWkKanzrdeGhR99f2NEAY7qarFYMiShh0CCUSNQA8gkbvBVm34rCh7twwARn115gfsMKxvPW1NwUQL3H7NKDDzLqEu0Ee73jITNdziqCbhIsHj9g5Vha15RRBUHlrzAxYYbtoVpmSdYhxanZwzek1S9YH/EWYfSom7Pz+LTh+ytlji8sEaNvECCpeDJxIwRh5IyhuwJkdFXrCls6vh3Af2eDijsFflnKjAGxbQH2iMdXsI4p9rHpgDfAuE6g2cddejgGLPkjv8TN3/HquC3vLT0tTWkWFX1EUTHyRZ5IiBEibM+z8rl3r3hPjZkRh67bdowtuz1NWz3L4fYjaP7sjHLxrNFR5ez8Y/ew4bMzGP97x0cutftP+7/02w2qzbCdh/WS1VvLSIVE+YUc5lOHEUDBqZhIg+D0Fug10Dvgt4HHQN9BPoE9DnoU9DHoA+l+HcURCeEXwG9ACJdSWEkXgsDXYnH4JFvj8iT4T6loZ38x2gfI96vpuUOlBN1L1xZgGvRD8fncM/Hs2xEwjco26MAfl6yEUdLIhSXC2oI/1mgpkQIt0P+L8Syrb7CHEuev43IF2HLLwodeCgtLPmHQz8zBJsvwE8B/tOw+wJVRtDWUTqgvdN+0YvQV/+RrSW4/iPok++BfgJ9LtFXoG9B34N+BP1fVlCzAaUhorBMFM8J9/ED6AT8RJT3O0oP3p8g8stEZSuJFI8rw9+Avs4K1uNL0Huo5xOeoD46bvWBgO9ZieOlDh0VAnRQlyy8DZ8d1EhPG7dJhxZpsR8BntLmoyzs0IZxcm+dNIhdO6hbMF4qZ93Hj3OXTv/Jm8BJA753/mjWe0zf0DXkMu1G2xNivQjoFB/ho3kOfUCtVqsTwlW6yWTKIAL/TlBTIcsRpUAl1jmMpLoq43CfZCUgHtf7MhFA57ShM7Ydv2biZ6TMtd+dA8PKmLprNoS+U+H7dsxiNoPld6FOVR6kgV3k0bMReXgfqpNeSEeax58G5cB/G9pbDgSlocmAmBbP/R2RV154hNk8XPteZVgG6qalhkbzYAjKCNt7ab7tyTQIVZrL/DJs3sLx5Nrz/UctvqKdNl/RNnt+oIdlZGCMmFYJq9eveiY2byCiRZNM35EGtoKi0HKX1Rvg1yVE2osXDRbf4YiKWO0+/waRp6NygbY3ISuomulPyT3jCX2Q1EjFJOxjnCBdkt/Z7fYcMa4iged4BNe4QeQrgXrEdIKW9EpK9xm6R4+kakWHjkpFUlJSpiyA0Ok6siU5fvVE1nvUzZw3be8DbMXb69jwBwqY76ExnL/9h30hwWfBs0u5f/6Ti3n4hpE3sb4TbmVjlk7gvEXPr2AbPt/B4zZ/s5uZDelswtpJrP+k20KCjznJFFWNRCnwjFLA2vhF8LpKWoT7E3kyQYD7CwIG7SX7HJ03tCE/b/7I9zZ/tZt16N6RPfLSKjbu0XvYVgi33Ydfz2Ydms+8D45ii19ZxdZ/tp3Z46ykA09TX10FIR6DXNiMXE5ODvFo9qiZkk/AfZT7IwvhOUzYQpnfk+sM2pidgvAXLslShhR/3anUsQF5fhN55QXKVC1/kOCPei/FgPuClGYj3QMGYbLzSHt+UpHmkOQnCyA7DYIgh/Sa+pkg0Lxh6LtbtdQZFaP8KkGWYB5x5GxbfrHmc3T4/BeJPBnGkUW5lgJ/P4vPfzmEvzvsvsBHNm9xD/jzTL5iuyU/sN2ct43fj3Xw/vqW/OLZaUOeNlq8gbrpgw5kpnkPNbDmF19vGl7UBPnSDV0KIy7PQmjVT8ueRqCtrsMPZSv8wJaujZ0BQF/6yR3hhKgSsQp6FQV30L6rJhB3vciLBowLvyjDGGdCY6IOHZUCfKDqiYJMJG30MZFyKVbUyaUIK2e+PB63SgFqGfGCXCbp+5q6ezYXJCk8bKaXrf90O1v17gZ2O3gklJJS2FvuHBCqB+kTM2jo35m4ZWqo/us/2RZ+P6DdvxUF7wdki7N+jY5PdFQspyKAcndZLBYX3AdAw0CLiY+BnQ4oFLuEY/sYRMh01nYynIw0dLqq1MIl8vD9fbgWmdf6FIPsXAg8UZdWkC6mJUN8jOjgxBaRTwDfg/pbUf/GqENrhNvDpX2V19EsmDu4r7IF7kvTBiHSjRJ5SOsEvwnKnItrk5BOOqJGg98TvHEoNwN+Miu2gJ4V6GrwZijLQDqVYKiE1ecPiLzSwO4t/lDkKQHBLurMAcGcH3CJvIqGzRuIeUO4jvID7fR/Bg2rJqmpqTXRTtPRTulAkhtUG2lz0U9pu8BZ5AfVRtiNfmtB+9b8aahs4Pp/iTwRqBtXnktAnY8iD620+EB5uK/RNAMJPv00LkCY7JauQ5otCtoKehz8VYh/xBNhVh/ljEAaMnzfB9ccjPBAhOnQwnCapXcHbWmPxnWJxiDsQ9ohoBtRPu3vvgL56LmGZrjxbHuC55DDSKufItdRuUhMTMwIE7IkweSWuwcEhZNfC8VlRiZrqp+6c3aI731wNFunFG4iULfh6v1kNqN1jlivssBay1wol0n1pCXcuYcXccGKm0GCu/2H/Txu81e72LwjD7OFR5eF6rH9x/2af3/owO19C8awezbexyZumsru3zWbzSl8iN37+HQ24bFJ7PZlE9ioxWOZPdFCSmKpUz/m1lAqbEw3Wm8c05fXZeaBeSftFlup7cKebniChqtDg5ISMQhxLfE8IqqCQdnFIk8GBE7Na0YDrkezZcpwT2U4GnA9TTuuWsA9tRB5WrD7/KUS4u1e/9siTwu2guIwu8MQ6N4wGJjqx0OGzVccdpLY4ivWFO6s3kBXkUew+QKaxsTtvoCuNuE0Au05ZI4NQsRhZVxZQWOVyKss4FpR+5hbsY0B/leUcTLQ9zT3zkZDenp6qjKMsovIxfjTV8knYBxQzW5i/G/qimAmSwTShQQ6grMSD7fp0MEhzriRgDEfws21/a9jGz7bzq65tStr3rIFe/jFFWzJq4+y6fvmsnp1ctnKt9azK3p35nkG3TeMPfTMErb1u71s4NShbAbSPPLiKgg245GmE7tn031s4OShbOzKu1QCXA1D/CqxTmVFl1uvDWrml2bESChTzQSSgIc4edaMiBS95mTlaApwZYUr3LTSL1r1yLHV+1uRJia4g0qNe6L8tqALIEidh4GiOfh0KrYObaIF7BaLxYwBKVNJSJtpoSk8l8tJalfg1kOeJshzHpWHfGFqKxD2I07TREyscGvMsOGamrZBCajHQpGHKofNeiFNc2WYgDL9yjDSdCGX/pbr1KlDAk51pOmC+66bkZHB76lWrVrcxi49R0VWjpo1a/K9f4j7hGYG8PyaUBjl3RKeMjIs415xWvKKIu4jI1h9xXsMBU9FNCMnwjbyMJ+BM40obm3z+edBkHrEnF94YcagA1ZLfvEYS16hk4QuW37RFGt+YJ7J6w9+qAqeq2kY/Ga83Ve83TG00GIo2F3T6vXPt+QFpiCNxeYN7LN4A09AQOwJ/+2Uxeo7PMLqPdzKNPhwaGM28q/mrjewW+bpqHygH30u+9EecxRRHIh/nrq2yCfQ7JXII4DfX+RVFrKzs6O2cdQltBcafs2fGfTFr0Fk2qox+uEQ3PNHoLZIfz/csJPdkeCW9LXBXQ+nBsqhvEVms5kGzmSUfQLuHNAmKd1UEB0aewLPnWb91yYnJ5PuN9W+V+S9U+Qh3zJykW+JGKdDR7mhJVjIBxfk2Td+IIGWCuUDDT8F04QOI8iHAsBT5pWFJHLlWTDxWuZU8wSxThWBtLQ0BzpZe3Scq2VCB+uATtjMarWaxPSVAZfTNW524UOqe1bS4989cdKcbJok5iWg/qrlDtxH1I3v5QHKHkcuBjNubgrhfXhmueGpSg8MYv8neemQiObgLMMlLPPWqFGjGng3pKSkkGUOWkJ9F0JYE7zDsMMVLsEkl0val+cJLqUsxns/H/mXgu4GPZOVldUHafgeGITXoL1kIN0O+BeC38ktLQPDNSN8L94FVwTq0lia1QKeIdlcpWUvPhtnzS/MUcZb84va2woCmh/WaLDnHW6rDKf13VzDnh8o0z5Si69I9fNkyttfy5rvV32IREDI+0Tk6ag8oC19LfvRllUzQminNUHDQZtBk9BeufJstMMktNmRbg0daOgDvL+fDmRmZkacJSbg/o4o/KoT3zJwH2ej/8uWUDQPGkUD8h8UeTIQNwiOStDEswybxSMgrcrIPZ5z2Oy4DPAHYbziP4A6dFQoUgzJv3LhShK+gnSIz2SpSDIIHhNJecLLPUUUN37NPRU663UmwWzI/IWeY0hYEwTlezZKe+v+Lyjs9vTdEHoWGBzWo9P7lOVFAgY72icSdckRg0fEzehK4Lr8g470XI0Lwn5QhQw8qOeVGHjDFAVrAemOi7xY4JGUAOPjVp9cWYDTgs1mK7NQiucRNqOG65IW+KNwPwC9C/9h0Hx8HMNUoljyAskOX4DZCvyvQXAK21dXGtjPgL1nNm9xV/MIv6609DTCLR0eIqBtV4guPncl/gxqoCQBLrTlAH3nOWVceYBndYkyjDGoxBUFk8kU0/41l6DuCuHblGECnnGV0aWnowojIzk9LSMtI4XMiRiCfzaq/QBK4EOpUiURA6pXN8QlpcQlpyYlJqmEit/ZJ/Eet/sSdIS+6NDdiNABeoFokyltJB2PODIKPA10F8K02bQbOqXqD+mfAuqTMdv/0ANKYW3XL4Ws+4jr+YwlnWLtP2kwy58/it08tl+YUHf3himsfa9LOuLeDuA+7wM1xr2ROhN7RkYGn3FKSkoKm3nC9S4AZUPoyoG7GnlI/9tkuMr3Q5v1HwY9hzT1EDcT7pVw98ENHQJAPr58ievxvRsIBxAf0e5nZQB1CtNFhzqHDZIiLBYLH2xR15XuoLLn5fC/CH/U/TK4Ry7E4f6m49mJm8NV+gBlID1XJE3wRFEXgHqsEXkVCVPBk5m1+q61Oy8afGWm78kMIyjT91RGppf8T2UYCxAukPwUT36JbL7DTpuvqK7d629UFhLroqPy4VFsO4B/ruxPTEyksTomgUNE1mk89YlrRd0zi3t6XRmmvgwaKxL6lTJ8B8KcyC+mBWn+KIFP4yE+NW5+4APXJpvbWejbTowLFjgmmrk0RJ7hi0ca1XI1yukn8ggou787qOy+xANIOnScFqCxku4bro6hIlDInsnZ8vUe1RJjrEQqTfAhjqrl/3TBbrL/FVpuVhCpUiGX78378QA/VKGMr5tbt8QB1WazqdSFEDA4/EjCllOa7kdYJSCXBOQJ27AuCXDnK3mVDdQhtAcuMzOzJgmmGFSvAP85DIRchQf8a1Avsgqi3PgcZpkDYc3lDAlxKJsGcB/KoYGfhObjoDEIc6Wc8E8RMxEQ30b2o27c5BsB6S9A/ULLKnh2t8p+TYw4nGQe9Fy6efhTxvQRhWbLoP2Z1YcF0hNG7k7J6HcwOX3Y/gRD/0ISLMNnLvJf5e+VBHzU5RYI+JE+Mjr+RaDxVuRVJaCtRl2uxf0dr8r3iP5PP429RD4B4xfttaUtINcajcYEjOHUh2mCRJyVjK9Tp051jE0JRJSWyGQy8S0tZQXGilRpkqNMgr6OfyGygjY4o27QLg1cTtfrJMTI++QGTRnKNn0ZPPEq76fjREuwcFe9t4ELQsp9deYE0xkzAGAwMvUd31+1dKpFMw4+WIhOxvdYlQQ88yedwdOuKRKlgtJAGdnZ2aSWw4iyTHBNqIMR74koE3lojxepG0ijDg2/nJ8TCX5uaQlVBtL4QSGB5XQAA01IKIoEOllGf8xKHur5qjKMe+F7gCoauE5o/1FSUpJ8CKI6rjfTo1BbgHB32a+EzVf0qcgrC+wFxRH1wen4dwLtLOL+rTMZEFjqYXyJulzrlg5p0EEr3GcjpK8PXl06RAWeg2bGIMykYyxLjo+PT0xISKhRt27dUgkkKKNazZo1SXiqWbt2bTJcT+NeGNE1cH0zTQbAdeN6tWm8pfpEIrl8pL9GcTmOihJKUc59eB5cEblL2l6DcTAd9axtNpvlA1ed5esh7XLUrcGpEk4B6QZ6hBlPHf8xoAGoppDLA5vRelgW1vb8XsT1tI1ddRdrf/WlbNKWs0qkQAAAeAFJREFUaXx5sc+4W9n4NZPY4KnD2eKXH2UPPr2EjVw8lq3/NKjCpFP/LhXSWSoSbS6/cObDL65UCW1EGz/fedIYl1Eqg8llRBwpAMVfndZfX1RgAItofL6ygLZ1j8iLBgxIqn164Gn+DZcXLsX+IwyeEfceYgCVbfb+hjzPwP3bYc+8xDasuHna8MJ4q/ewaiaVToWKPEJGr2Oqd2b3BvgBCR06CBBokiwWSzbaGtmtvgrt7Roi9N/rqC+AbkS4L+L6wz8I/qFw8xAuAI1BmJYcyS0AEX+oM6gf7VaEb4Z7A6gH/F3BJ/vXrUkww5hSIaoyUN53Iq+qAc9GZY2mIkHCGb0L8kN2q4n3wGfj8SMZ55aUz+MnnqfFu6VTthGB9O+LPB3/IaAh5Yi88sDldD0lCjixUPtul4VOvnbqpy3AdR/eo3ufCf3ZbfcPZ6SLrfuIXuyyXlewBg0asrOaNGbXj7yJWY0WroFfhN1qf+z25ROYTGOWTWCjl447OXrJ+P+B/iAatXTcH4g7efvyOxmRtbo5VA88pw8l7wZ5yZQOebS9+mLNupYEqRN76tSpk1iRhA5Ng7/qKD4uddoFOALq0hrXJpukRI3pgwHeA6AbEO4nfUwuxiDWGn/Wqj2QSMdnx2Qg/TT8qdLsJJ/pRL6u+PjQ3zYp/uxBf7JSurqIa0V/tfDvR3xjlM8HTQL8IRUmuP5XruCeuxlIOwv0KGgbeOucir1yIsze4n5Wb+AuW15gkcUb4HoQbd7Aclt+sc/mK9przS8eaRl55GqrLzDW6iveZfH621ny/Fdx6wpeP18atvv8FW69QoeOfwoQNH8WeVUNGAcuVYbx0xx1319pgfIPeiR1KxhjcjEW5YM62O12WkXhP70kzElpQ/sktYD4qHuEdfzLgb89+SQf7SeiP4EkNKIUfAhpU3yy0Wgs1R4sNMgXlYLZthNPsO6De6gEtlEPj1XxZOo6ooemUDRh9UQeP/nx6Xxmr07dOkEVKIrlTckSgwpB9Sen0pF5MZpR01KJIhOVTXlJABDLy0jJiKjcNgLCVImQACf7ISRENAUjAnV5gXTDiXwlkOZlkYfrtcFfXcxLFRhQaDDZXtEbpHGvtNk46qAkAuk/Enky3JIVCy0gX5h1B6QNDcQeQYddRd+njEzvU/y927zhJ1ZT849wQdPuLf5DydehoyoD/ajUOjHPNGCcCPvZxZgV8cCPW9qzC+ErF+My3+OGsbM3+KKN7xDwjJ5AfNTxxi3tfcY4xcuPi4tLBfjsnDt4OI7/WLpLoehcxxkOm9G2lwQVEj5C+8xkCulzUwsqMZFSSMI1XHbnn+L1CS6n63llPrKWMHb5nazVpa3Zhi928GXV9Z8+znrm3cBuGHUTy5tfwPpPPGVTlejGcX3/RAM9G42X3GvlsqfumMnjb5s6jD3+/ROsS79r2OPf7WVbv93LRswpYBs+384FOHS4t9CwSVkkmXEic03TadasdYcL+H1cfM0lzJZg4Sa56Jl07nM1e8C/kN/XstdWsxn75rGLu17KBTjkpWWKL5X3WEaECcJyB4a7gPZ0wG0Ll8/KwD8W1+QKbOF/hjb/Y4DgSlgR/gI0G/HrKIy4XJo9ArWWy8YA8absl4E8rWrVqhX1RLIMl7AHxGaztYEgX2E691D3YyKvJKD+v4Fiqn804HmlKYVnAsqdQjN4Sl5JsIx5OqQUNxqs+f6w08YiIMCF2V6sFHReIXJKjeQRe1XLvzrKDrRB6vNkIWUG/LMkIt2GZB7qRvxsdQN1J8oK6jok3XDjkGY6pYV/JmgW+EXon/z0NZ3kRtiFMY8O4pDOODJZRcuuWaBQe4U/A8T30xJRWHIzUXbYbBOubQYv5kNlct9CP2uBa28U4ysLruApVvngEv2cVcOY5UH928lUu3btBMR1Qt3qyfkQ5ntukTek15Jm7mU/AWkiHgBzB00DknlDWmnolJycnAEeaVggzQOaao5Qlz3iGKQEfbNQR36oySMpb0b5IQXJyE+rGQ9lZmYmwY24QqCjimHsqrvZjP1z2eD7h/OTkb1H9eUzVQMnD+GCz+pjm7lLy4dKgWnM0vEQgoInR2UBUKaVb6/n7q13DwrxLrq8LTfFJV6f4Ha6wozRy8TNecn61BTC4Mp31rORi+4IS9vnrv6/87Lc7pfx55GABt0dDXXx8Dm+kBBKBx/ofrnFBuRZ/f4mNmX7DHkGrhoGM7K/GTpdS2nIjNbdoPx5o9hSCGrEu/GOW7hVCrI+Mevgg2z6E3PZiAcKeDlk2SF0YxUMuQO7gsudcTk5OXQooSHulY62kxmvAsWARBuBnZK/CPwJyH+7M2i5gWwMdjSbzTXg3kdp0MHfBr8bwoeQjg5LXIPBpA0GsJCaDfAPg3+FHFbwNQUZlFcDFNHeLeJ6I+8XuOYIUJ4GjaQ6U91BE+GfSH53UG3ASI30ZDdxnjjQoc4Nkb4T+INBd4IedAdVq8hEBrdDYcRPdwU/fh2Rt7GyLBl0DcR/JvLLCvOIwKWZ3qfqWr2BuTavP6qlA3uBX1aOXOGw+QLPzX39INv9ywG251dt2vL9AbbmiwPssQi0/mvquwd4GQveOfC3xRtQtRkdpQf9FIm8sgLtuz256PeaP9UyEH/SoGGHVQn0kTBTWRhHueCHPtJDyY8Et/RjivSPiXGVDY+0LGkymaKuGuF5hVYokGcfuW6F9RrwWsp+KU7zEEFZgfL2Kcc1PPNLyEW9+pGLuDdA/GcV7iA5nRaQN/opeR1VB3OLF/G9Wx2uu5wLOn3H3cqXMElXGQkraz7YzAW0x45v5YcGyMQW8Re/vIpN3DyVLXphBevuvYHdv2c28y0cwwUbih+/ZiKbsHYS13vWrvMl7NKeHbmAKF6f4LDYQ4cYuJoNhWAmU7fBPUICo7yESfW6YeTN3H/T+Fs0y+43cdAxsSyRqByDhu67rd/u/U5MG0YaM5Q0uyeWU1GQBzotoFOG/bnRrJEyHAkYAPhJKnR61awO4mjvGW1+ZpKAR39uZFEhVA/ERzSNRcDfZTzyhRR1KuGKoLAY/LD9JDKcCr11BKobuSg/ZNEDPD7r5ymlUmDcH+mZKs3pzqgDfmkBwelyQ/cF8dYC/2ZbXlFrc95B1d4+GRDg+M9KZWDEdsnCioJoG0GvJUUqvpImPxu+3UBJ168qithudcQOtP8ckVdWWK1Wvp0D7T60WqEF9Ik16Euq/bEi0AdDwqVHOq0N3oBTKSIjS9qKgPRrxbjKBq7NzWuhzlF1myI+ZM4M9dxDLvKGtmkgXmXiryLhCR6IepT8cPNRh9mg15zBmdNNrqAiYT7jDf70sMwCUNZskaejiuL+3XNCAlHYEqqCd4cw+8b50uEBpc6z9ZJwJ+cjYeyx41uCAg7NgEUQ4KxplmLK06FHUIgkw/G9R9/MBk0ZwvOtfHsd5990xy189uva27qzxyFkUt3la3Xqf7Vm2WjYFvw+kk26ZfYa9uX16+cuyW2QW2QzWadaUswPJBtqLnfYHSot2gR0jn5JhoR+iYaEvq0uazPmqj6d7+s+vOfcG8fesqT3mL6Le/luXHBd3vUPXNrjsvEOq6NviiH5li4DbqjQzatKoD4X43787qDaioWgVfCvh7sH7tOgZ0HPgV4B722k/QD0GQaab8kFHUPcm4h7AW4haIsnaG5quHwcXQlXUJmw0rxMHF2XBlwiTymWiT2CQAUBM2QWCn/sXI0Jrkc2CXu7pL0aBLdk/gbuXFxTnlG8F3463s8PGKDsqcgzlvwuyaQN6l2qE3Io83zk/UnkawHXLpMpKbu3OKLgZcn3x7ysYc07kCnyKgoL3w7f30lC2eMnDrA2s/2s/bwituqTg6z5ND/ruLCIrTh+AOEDbNCmIjbpmUNszy8HmG+fWgC87yntPaY6SgeXNNtSEZBnltHuJ4lxSiD+D/QvzfFRCaS7XuGXLaIMOZUiMhQC3GmfgcO1/eTieUS1FONRmPhynxLgQts6EK91Gp7bFa4IYLzsAoqq/QH3wLfQoF4h02RaQF0/EHk6qijuXj9FNeBq0SMvaajDiDBbFom2ndinOZCjQwyl+L1/+LnAtuTV1dyCQbdhPUMzXLTHjNKQXVZKR3xySScc+a3Jlh/FciMB1+On/6oa0PEYBoUtEm0WiP7CQoS0dCJyN9wDnuAJJpEOSVRI5JJms4Tr1ZP3VShhMplof0tofxPykuoCleF6EXjuoQEN6c9TxslwS/oFbTabyi6hBNK7tlng0VJwxIMJiLsC17teol4a1FMiOuXaR/LTSVeReDoMkGQphPxiOXckJCSoZnKjIaHP9iRzfiDHnO9vYysovFpJJq+/jXlAcdRBu6Ix49nw7RBKUs6wRZpt0+KP3ld52wr+S6CT1CKvvEBfukXkKYH4JaDQSexIQJqQ1Rb0N7586CqlAIf+czrUKoXBIy2hkuJwMU4Jd7g5s0JyUe/jCl7EQwsVDdT5blwvgDq9BHoZ4SfdCiXoSuTk5HhkEuN0/Aswdecs1YArEs2i3bNxCjf/RMLSnWsncZf2otHeMFranFO0QJVPpEgCHMGWagnaZZWXJKMQnymUiPL08F4fsVwtuAWltVUR6MCNQRXWKTEIfKPBy7bb7WECCa45XBlWAs91EuK7yWFPUAFlmAJSCIR00CRVay9dJYBmDEvVNsoLCJ58lrCqYvYLpwS4tV8cZAV71DNqRFqCWqNp/pB/5UenZvImFOozcBUBt8L6SHmBfsH3WcJ9WoxTAkLKSQiOFvTrqKfenQrzUm5p/xfcYRIr6mEWWYCT/LRZ/2kQrSK8hfDboNdBL4GeBz0l0NNESBsA7cM1i0igAT1H5SBM/mItciu2pCD8LhF4n4P+An0iCUevwn0X9x8SnsE7LNU1tAcW42SF7nnToSMm3L50gmogFmn1B5v4nrdb7hrADzgQb/Erj3Ie+UmQGjozX5VPJFK6K15fhM1obWfNsHS1W+23OOyOWxw2Rx+H1ZFvt9j7WtLNXc2ppo5Wo7WjzWTtaEo1ae6VKgnokLtEXlVEdnY2VwiLAaUVBhD+B4mB9BwIEZkIk7UMrtARvL4Ik6qXJu7g6cnmIK6SQgb4fFBSwhU8hRYafJGmfVpaWsxqRSIBAx+dYNO0VkDAdSaSa7VaTajDMlfwxBY3xwMBMOz6uK9sZVgJd9DKBE8Pd5hLOuAhA+G+IE2biSLwEQtT3Iuyt+La9fDse6FOIY3sBNzf5cqwDKTdheu9BPdD0DHQB6D3Qe/JHxDQOyWQnI7yUN4PQB+iPh+ibFo+j2ZGrEQ8+EZQ8Fr35QE28fAhNmx7Idv83QF288ZCfnhh8lOHWL9N4H17gM14ET9QPx9gU6VZu4vmF7H1Xx1ks186yDrOP7VnbtqzugBXUcD7PQf9/hy4dEhrNFw6kLMEftqCsA5+mp1f7w7qJVwKWgi61x08GU8HeZoSoY1GU0R9FvpLFtp1aM8pbd9AvkzkIzN0zUCXEyFMS7FhP3ng8RObSM9n4OIBZbyIrEpSx1NZwH1zoRf1/lrmORVWGXToOG3IbZi7j9R0iMJWiBSzXZFIPuFJaVX5JaJ02e7sMilsxEASJmyUF+h4mpvqqxIwiIzDoNEyPT2djvLfBpoOgUJWSHsYg+et4PGlRqQbD/9eUD/c+6Vwx9DHPikpKbQ8Cn7oSLwMCIJhy3fIE9oHogXET5T9qAs/5RYJqGNEcy4op78nqMSXTtJuJR7Kuxz8tnCp/ntcMQheqD8p5JV1I4VmXdGemoDy8VxoMzA9p5tBH8PP1azApT11D4NIWXAf5L0d1AbhTgifD8GS9uy9kJCQUBPuucQHKW2jqvQsgRcytSUCeW9Qhi0WCy1Rlxmecsw6PvRmsA+v+fQAm/vaQfbQWwfZg6BZrx5kk585xB5E/LQXDrGNEOAe+zx46rTfuuD4cfeTB9nWEwdYg3sCbNF7wdOqxB+zXxfg/ktwSoct0A77k2s0GqOeYq2CAlwxuei3oT7tFA6R6dBx2rDgmUdSHRb7PpfDdQT0vMftOYrOdzTLk0Uun4r2BNfZaerZD/oV/oNul0iugy6JnA7nQafdcdBhtR+0m22HEG4tXjdWoHO0EHnlAQaMD0VeVQAEh9DGfxF45jGd+JKBd/iiMoz8qo35EHJUgoRbmh0TAUGSlPj6yU9lgyLaykXcd+KMVmUgJSWlJgS+sJOrlQU8v9DGYdxf6FSsDDwbvkka6dqgPZNS5bjs7OxqeMbJSL8I8dXkv3gInnVAquVxxKv2I8rA8yR7t9loIwlwI6YrCVnjTy2DirRVEsgWvx/+ozbrpcg/bkRWr3+DeB0dZQPawGIIRKETkx5J55cSaEtrkC6kt0wDqiVN6pMir6zADwhvuy5pOwXaeNQT26IAh3zt3f/AgYZYgfp1R/2KcF+XKHh1FUl06Dhzgcb7KhrvdSK/MuAOmimqUL1XKI9MZ5Vqs/mZAgx2WwTaDNok0UaJNsRIlJbya+pxgzAQpt9Jhkt7Jk651LqTXKQLE54gUJFeuFlSXMgwvBIQuMJUeeBDFCYIIv9hCDc5Sp4WkpOT+fvFdSKeCkYbHtSsWTO6RsRlWALKCIt3l3xy73nQ/aApeLa0rPkArmHKzMwMKTYmwQ3lbsP9NoU7BOkWQAiuAf548Fq4grOqXEcfAR9Fmmnly6P42I7FM6DZv42UNyEhgfYUrgT1k9Jq6q6LFTafv4NxxJEu5uGHL0wccqiOYfj+NEP9PWGzKLZ7305IHVeY4swvstjyCj32/EO59mFFLZz5h9tY84o7mPMC1xBVH7e5zMKkDjXwzi+TBIjFcIvg3gX3Lrx7J9zLpDSXJiYmpsOtA5pK7Q9thlQCrQNNR7+mJdBR8PdAO+LvxxOcYaaZerKXOh/x7eiHAv6FoD7UtuBeDP4R5IlJRZEMtO2obSBLEOBwjZXKcFUAnp8uwOmoGkBjXYvOXGEbaksCrne/yCsrUBapwCA7l3xp7t+IKCc4SwUMpBHVVWBAz8vJyYl5dgvPexiEk9BGYLPZrLnZH8JLG7yj53EPDZCHlPiSwl6yhzoU9BPiHkPYAncDwofgrhDLIBiNRq4WBcKM1mwDzRLPAS2lMMoh5cab6cME3uWIfxHuDtwjqRYZhvAliP8MQmF1hGnzMz/xao+gNR1p8iU3F/fJ3wXuPaqeqbICdXPhXsMEbbfiRGBlAfd+Hu5plMjXceYC7TFsZhjj4AFluCSgXW0TebEg2swxQRTgqiI8ku47HTrOeKCxLhB5lQm72c7cCrMl5YG0xLTYfeqEVJUA6vwQBmAGIYPP4qSkpND+rtcQjnR8nWa7EmkfGz62F8jpMJhyLd0oKwn+qEo8kS/qnzbKpJmfqFq/Cah7aLOvEngX0ZZ5ygVPFOWjaWlpXKirVauWanM17mc57rsmng/NkBkTExPjc3NzqTwPBBZ+UAT3zWf13JK+KxHIx/f+CLyYzIp5oiw9xwrcQ8RZx4oC6vmeW9oLpENHNEBAK0lFR5gAV61atSSMbwnVq1dPRDtLRv6M7OxsMtmVSS79WKKPmvBzZIZrBC8jMzOTxqok9O0E8MJsSJ8OxCjA0biyFvW3g+Jr1KgRj7GkWkZGRnXaJ4i6V6NtFenp6WQVqBruoxrSU3w1OjyGcHzt2rVp7OLjF8ajOLIggbL6gfoI19KhQxvoUFwj9OlAl1uvDe2lSTOklNoephbQ2Mt0mOKfhDO4D5A660506g7o0HxfCcKP0P4ndGRuFFlKewEGFG76Be4GpL8a6biw5FQsF4LfUfZrAYOJSrmvFnCNiIdCcN2IhtcRdwFoC+ouRhmSkpLi0M5on1g8BD2y/hCPdOTSwBaPwYvzMQDGwQ2bZUOaNfIgjns8re8az3etyCO4pT1wJQF1/4yWq3B/bZBnOmgJ8XEfk8Gr64lB3x6eW9Q9RzqqNtAWrpMJ7aEv2stw0B1472PRXkhH2Fy4K2RC+EGkI1N6QxDuibRhJq4wfrjAn5cVNJi+zB1cXtW0LCD1uQyaIScho06dOqoZbhEQOqKuCOBaXIBDvRqAJovxZQHu9SuFnw4o0dIwbcfZjPA0XMcL939yGowXtXFPEWeukU9lK1qJWAQ49F/RZqwsiIX9hKOeUQ99RALqENUqjo5/EWj/z90bpvy257ciFiuREl2y9cn9vxaGaOevhX/u+uXgj3t+K/xcou/B/0PM37rjBTFPlTdvfU77pa8GbY8qqW69ujGXQTAZMtmIuQXczNfQWfms/6TbWJ8Jt7Let/dhfe/szwZMHhyK9z40mjks9oBYRlUHBtoyDQgYrGOeycHgMU7eT0PAH2USBqKQfUD4+b64SMBgpjLl9W8C7n+5yIsV+HisEXnRgPRviTwdVR/uoMH1CgHa40py0W81FcAqkZ6enoSxQHPLA8EpWUSJBI9g7F4E4v8mF2PAk2JceYB6ke1nvudWA1x4wrW3S+774dHhcCiM2WuhJAHOLRz+cgctz1wIl7YH0WoKnXzngi78S+C/DGW2RP2HgKZK/KPgk666uzIzM43gj4K/n1NxAtal0MOp41+MdZ9u+1YUjshw/OTt07l/xAMjw+IGTR0WTBOWZ39QjYiC9+BTiyNaaCCzW0teXxNStxAJDZo2vJlsrIr5ZarfqEFMQpzT4nhPvq7sivWV4yZtvZ+7e373x1T2PwF01hnooA+hY9PG5HEg6sAyjVRQgQYp44nkfKRLajTKVRmexqClOgkZDSgnDbQT9TvgCuqQ40C4tTtoukvT9BbS7nL/C5QrR0PHjh35rIAnaMHhWtA1RLjvjq7gyVTaWN4QRHv/IhLFUzqkP8sVtFVLe/aoLCqzhzu4rFmqGbj6jRt+1ntMH/4DQ5Q/fyTrf+9t7PpRN7FrBnRl7a+7jJ3XrhVr3Lgxq1c7l+WYspnDYGNGQzpLNFRjkNpZNYksBiOrm1OXNT//7JMXXdXuZKc+XU7eeHvfkyj3pHfBGIYfqj+atGyuufSsIzog4FSYMXsC2k6J7QTtjPTMlWvFxVOCAId68Jkwj7RqUFFAva9C2TSjx+8TP5gO3M92jGtuk8nEZ+hxzY/IxbN9T5FVBZR1qchTwlPCIYZq1appLiMjH51IN1QHcI1SL/2KB81wv3crwzr+nai+62e1yZwp22ewR9/byLoO6s68D47mBuzz541kS19bw7oP7cUtMmz6chcbPG049/e7eyDXAbf62CZuB3X+k4+wHvm9eVk+5BfLJzKnmG4RK6MEOtc56z7ZpsonUuPmTcIELbPZTGosXlXygO+2freXTdpyP9vyzZ6gEmIIcBu/2MmWv7WW3bNpKp9BJDNhM/bPY33G38rLpiUCoZx/BOiMO5ThWrVqVVq9MJDcK/LwPPeKvLIC5T+L+9HcCwdUS0lJKdMsoY7yoU6dOh3EnxolDZg8RMWLRNSHyH3kpaCC763f7uWuONa0vODcM/Yn6UyGS1JmXUGgbQhRDxcQ/r+9q4CO6ujCi2uIrmU3IbQUaKG4a5ECxVpaHIoE1wQp7h6coMEhWNAgwSXBChSKuxRavDi1v8L8353dt7ydlQiBUpjvnHtm5o7u25l5943ca7Ionk7UZQcRJjc3wQmYZ7iNYAhRLrcpIXgVRTrl0lGCznshXSvlogb8AV5eXinRlrTwk+k9ftEIv+2i1eU7AOB/COLCmqenJ6XnCw5wXW6vEhDvdoUuOYDfEu/Zc/w2fhNZ4i2Gj49PFlptEydgEs5oRYosJqy6F8PmnF5CEy1beXcji368lcfTqlufhYP4ZL324RZb3uhHWyzG639Y82Kly4m5HZ2Xbje1wSwcXCXo/LQZydyWOv03c/vyNqjrUshH48EwsA0YPOvgFoRLZlj+AZGhdabPooPgFsMyaNKyWRDSSlUuzTb+tpNbjajWuAbLosnElv8YzV84A6OGs6kH5/B2oyy3y+GvC+LtLHpmARb7paJdU1dEaXci3wH8phN4PpfhvwP6y2wxUn0b7gWTRYP/b+q6CIi3qbFIDuD3OFM/QvU46KB7V/HzJM2ZaFKM/csuB4r+ZTeL/jUBROk47WQPJ2gcxpmArTSWaOzS2CDTdKvvbeTjIOKoxf4xjcnG3ZrYjz+kL1u5HJt2eC730/gPPxAB/3bWPqwzzx95GR92+BgrXa0sm/n9fDbTuqpOH0xiIyTiB8bJSpFHwNims2/MAMDtJETTWVKnH0dBQUF8GxHjX11uatSzHDyuJgp57yPMjbeD9wR0wJqODuRzwSs+mOIR4BDPhSfU41LZNeImQgCjrUYD2tQfebpAAK0qplMDaehcH2+7KwRY7a/CtZ2Vhb8u8pZ6kcomwJFAdw5tGI80drsTpkQKcPRXIQ8JpXQ+ebTC9/Dw4P8VhMcU4M8nf5YsWexW5lD1b3Q5TQkLW6hSgHvbgQ6gU7YOnZFFUHPkE0VeWeXAs6MnTngq0vvoTqPDbTa/+FJIgzCZJPq05Yi2DumjIbjRKtk3c/s5xNFLwtvbm/QdNUfHvYgBbafw119ndJpH5ImkLuPfhvlf2loMSII2f+TxA6XFJORwu1OFlPjPaLuALmRwIia5yEuUFpNuGkxwLg9H438uY04mRZ/oe2VEQfnfws/hmf+i/rf9p0Vs2w2LyTqFri4vbheOveRoe/jS6nI2/9YbFuGL6F64WyHuNk8HobFB18Z8FZ1sHk+Mm86WXrd8jC24GMXdb2b1ZWFbJ/EVtS871me0ur3u8TbWYlBr/kE3MXY6P1M6eOUIfOQN5Kv5jXs3Y7Xb1WHTIehN+XYWb0+HcV3ctUfCBRRBSgTmvo10YxxjYiCotJM5w+VYIqDcKigjCmOhLc2lKMsDYX42DmPjCeK5ImaT5TLEMbgTkDYrxmFxuPGaboOg6HZrEGU+s7pnxLiXAdo5kUgJo61F1PEE/L6D5OJ3XxOi7ID4YiLPuutD+h5jTCprKnguqcBzqXwecZeQpgrc2mgTrfiNgX8ieKTfbySEMzMpOjdbbd/CXYB0tqNHqVOnpnmTX/ZAXnr32Sy/IJ3bi2kSbwHQQbLQJLzg/HI+oYbvn8W/iukrvHLjamzwqlF8ch4VM4FNiJ3Gv54p3fhdU9nnwV+yyfsi2Ipb67kxe1qtI6GNtidnHpnPom6u42nJwD0JS2O2TWKLr67iK3gUNmoN/NCoM6Bd3vSCEF9MzojKev+D990aYgb+odUDSksrBNQG+t3lv6rEVxXo9664vZ63b/HV1XxrldKKhfzbwGANBT3GBBeCQZ7NOujzYvIpBCquojImixZzslNI5z9qWYlsIH4K3ifwl6a0cAtgos5NX28oMxDh9xE/gIQZuC5VcLgC8ri0EpFUuBIi0cbn5KLtNcQ4BeL5Pfw+p+o5wK9MLtK7VZmSEKRIkSJloEVlgtMVDxWcvlDjzit9fwfbcns5O7uxCjsZ15VdWVaY/bjgQ7bx/lq24/IUtu/CDHZ2S0MWe3kW23U1gue5uKEhO3x8PAS/RWz35Rns8srSbOMDy1jc8HCD0+doxVlxbKlp9b1NDjyRVt1z/cHnjLrP7uOuPRIugDGWKGsryQGMj72od67ITwwwJuIT4J5Y3WQ7skFAuyNRZif8hsKY60gxcUv4yUoFzYNcsEP8D1bX6e1xBcjzkchTA/HcmD3qpJW11iBSsj2GbusSn6zC2OdwRKZMmeKbN+KFWW6hvhNIRVslpWqUZV0md2eREGAq16/KZhyZx8rXqQQBbiQLnfYNG75uHAvbPNE28VaqX5kVLVWCfVK7Ij8v1y2iNz/71nZ0J9ZrwQBWtEIJNnZ7OE/bbXovNnRtGBu3YworXb0sq9e5AReedN66+L4QUs0+4Xj7VCS9py4htxbvj4wZz0ZuHM/CIEhu/l8sF9BaDm3HwiGEjlg3lh+6XvrjWjbnVCRr1rclLxuDIN7BJvHqYXZhmB0vBH42EF+pXDkuJk8jJsuScG3KmSGQmTAp263SIc1UpCF1AqRO4SPQPLNVvQomWqdWJwhI83uOHDlIDxOdncmAcGa0wQtl+aIOUipsR8RHGi8SCpE+E3gZsmbNmg51kKUFUoNCrsOZmk0PYiz9+wk+LqwrxVvvrGbrnlr8655Zjj2QG/PQIjRtubfWwnu6jaejfBYe5bFcJor+dZc7gWmbOLaIaNWbzqIqK9b08UZzhhJWbpaTv9gnxdmE3dN4mOKJ6AKEEi8SfaSJjZCIH/6C+o+XgU6n06OPxvvRQmME/dfuLG5igb7vVoDDGHlo9abAGLGpQ3oZoM2Tra7bvoZ4rl/UFM/tTaS7JvLUwHNy0MdJq2Hgn8JYb4VnwJ81wt3EdAqQPgztsDONZraaJ1RDb9UFSkC77G7uIlxRHZZ4S9Gkj+XAfkKJzsxxg/VO4hJKtContsMZNv+5r37bEZZbr07oudnJ+TlnKFa+5GAn+d0SCXliORLuIb5YMAlVxUSyQ82jyUwdVoC07ia0r2hF0Loq+DdoBvmRZ7eYFvXVJ9ecwAPOIjDJFhB5Cuj3YQImKwzNxTg1UHcVkUeAwOagTw9pq5FrUunb2nJ7pUN/dEVbb9lvsbqj6F/cCnCbxfS0XUor1rQyTUIb8ehWeNTt9ax2x3ps0t4ZXMBrPrA1q92+Lsvxfg58qIWzvosGs0C/ADYWH220or36/mY2MmaCQ3vozKnYCIn4gT6zEP003lv88QFl5Ea/4wfiUeZyMV6ByWpfGWnyeHp6uvyoxdj7S+Spgfxuz8AhPl47rFmyZPFEPYFBVmBM2qy6xAez5QY8n0eISKizkoOOSBT9HhHSFwGNxrOiG9+NxXQi8Kzcmq+jDztykY7vbiC8FzQbcwOpWxqCOsh82TW4bcAfDjoEoq1TvnUbYNX/iLQ0r9IKfgbwOiH+CzwbOo8YRvEISwHuXUE6Tcq/SlYqxYpXLMm/oouWLcoKlyrCCpYoxPIVzs8+LpCP5f44D/sw14csZ46cLHu27Oz9wPe5moDsQdlZjuw52Icffcjy5MvD8hXKxwoWK8QKly7CipUrxsukshWq3rwWDRinh3CdYfvzw9oGPewPTvMtWJ3hkZjWHUw6/2/7Lx3Kz/XQJQZqJ/2GXDlzsUL4neWqf8LqdKrPVxTH75yC8o09xTIk3AOTBzctpQp3xmS0FP/3eK1Wq4Pw44GvxsqYXOi84hpSzkvpECabuvmRjh/iRT47PVfg11MF6dxcKyv/mIqfKKAOpwIe2vGxyFOA+vpb3S/QhkizdSsLZW2i36lOi/A3Josi1SX4fS3hzkLZ9cDbjMk6l8l6kxDuQ7xMLiCeVKhcMpoDDsVetD/Xtv36bAhqKxitpG26v459d7gf+/ZEGF9lOxXXlW37cS47uSuYxTzYwHb8uIj9tLgy2/FTJNt1ybIKrpA7AS6jJn2cKGC5o89bfclvdIv8xNDUg7Ndtkci6UiRIkUaDw+PjBhrnr6+vj7oVx4Yf6RbLEFbc+ivZvRxE/I7tRON/kqry0WQpiHKptWlBKmDCYhHjYhZpd8O/mDUcwl5SAFxOAkm8A8G9QaFIJ7O6TWzUhtQN6TvB3cE4unM22z4x8Hl27LWMq+BxoMWof1jka4taITJqkBYAcapAfxwEFlLoHEei7IjzKpLBq6APC7nDwLqNQjhwaBkN6/n7+JDWULCBryIaoq8VwW/NL7HaNLvGzmYGfQGl8okJf49+KsO2CYnMMG2EXkETKq7FD8mTrq8osUkO4jCNOmSoAS3N2mKR9vowgMZ4V6MtPXhki1TsoOq81eZEqOb2YpfBNKqBckkQ6fTZUXdHclvUh08VrD/zGg7QWfH9QWWbdMn29iJ3W0hqG1kx/d2ZpvurmAbHm7klx2O7O/E1j/azLbcWcFO7O3Ott5cwk7EdbErx50AR8BzWV7l62rs04ZVWbnPyz8rXqnk7XxF81/Kkf2DY4aU+kOZNOn3IRmtem4Fbcbn/3atxu9AoN58KEeunOdzF8h9LU/hvLfzF833MF+Jgr/nzp+XfZArF/vg/ews0M/McubKyYpVKME+a1qDFS5TmG55u9WZJeEc6DNT4TgVrhIJMtF0kzz47/eKkQrML85T0Y1Il+eNEcd1qblCAiwx/Ewu+kUjMc4dxNuZIlDuVrTNqW45CKl8VRzxig66CfYp7BHg5oYsAeU4tVyhAHOS0yMatMKHdrq1rlKiRMLV/6Ed/EyvhIRLYKB9I/JeJQqXKbJhNzvssA0l8XYjwMVKGyapW4ofaTpbefywMAH982NMikUDLOfRCsHfi/iYLPNgIqWza3R936ikJ4CfVwinpRcmyvgLxF8wyQXUX17kEWIvTrUTvOjygS38xFGNTkIpPgEuqQiI53yRRPIC/THZtscwFsqjPA+RLwL/8TSMlbUiPzEwWS0MuIIiwKEevg2YUGAc2an6EIG2f6+eQ1DP16iDtiDTIi//OITLdcsh3Y9KOmeg1U2RpwY+Kl0ewSB4eXk53YLG/0DmBOkm6zKaF+A2AI2Hn5sZNFluqMZQGvhLoJ1fIg/NXU4vQpldHOOQkODQ6XQZ0Ynm+fr6vjaByuzmnIbEmwFMLnTj6wLoO9oahHuVBB/QH/j/6AybcpbtOXi/wn0Augn/NdAV5KftxBOggwjvdicc0KQm8l4G6kkP/nF0Oxf1d4B/BSZSm76lVw3bJQYSun7dzbdKFRKFMnveDrbzygx2dn0ZC1+hVyjA4bnQKmeEyJd4dUC/5Fr7kwkpAqxWANyBxgPSxYj8xIAu8Ig8NRQBDvWMEuNQfw6QU+sCkGO4mg1XwHxDc8335Eda5RZ6Sh8fHzrjxi0vmK3bt3B/sMa7glsBDvUk+y6Et7c3qWUqKfLdwV9uoUq4AzrUkQAXKyOvCmYpwL0VCHSjaT2xyJ8/P23r0FboDpR7jMqmszOga6CboHug+wLdAV0HXQSdQv6tcGlbygZMgBkDrXrh4CpKS18Ldl2x6EnjAhpX3LuL7bgyhV1dW4+d3vIVux0RyPaeHsboTNz2W1HsalRhruNt27UItuFRDDsf04jt/CmSHTsQytb+Gmsr63x0Oa52JbkhBbjXCzxvlx8TJqtSXQgqWQDb6gz6MN2UzvYipQUQYrxRHj+SAncVuRAQ+UoZ0ldQBBr45wdYLyRhbMSBP4P8er0+PfxuV50UoE1uBbgAq+F5s9XSghBXmI5IwP0Lv2UY/HRBigzRfwL6CXli4fZHnIOVChrHiD8h8tVAPL/IEGBVJ6KxCLbZ8Cz47XT4eR/38vJyu3WNcoqKPDX8/PzcrkImF9COZFullXhLgYHxt8h7VcDERHY0o+A6fJ1J/LeAfsOv7L+pwGS9D31tAPlNL1QbvDY8GqP5XVxpc0briJysyil04PgQu/Cj0W4V+SYZJn/TTJEn8eqA/ulwaQD99Avwe8HdbLJYJygNtytovDUPWVlxOFvm6+vrhTh+sB5p+5sth/bXwq8YTueKfJFmeYBVjQh4TUAHQGu0Wm0GDw8PupTk1hoCwRSPzVVlBQ5lLRPjFKRPn55U76RHW2wWD5C+uzqNCBLgUPb/RL4CUkMUYLW/CpefCSRAUG0Pmob61MKQ0y1LBQHxrJSZXOihVANp6NIT39qFy1fS4JKg2pD8aJNNWbArmFSKiyXeEaBjeKCzVwdVIUK4Ik0E6Dh0lTov/LmJwH8fXyboI6bcQUFBWYjA9wH5g5cNlEtJa01PZ5GCxPoSC7ThsHLoVOK/CbNFDchR/1dw8+plgX4eFyCoPfm38HCspt3jMZrTP4enPvFwvObbR2M12x+GaXY8HqnZ+2S05hDo+OMwzWkIe6cfjtOcfjCB0mY4/fNUX4H8Tj8ejTxjNA4a5FF+06vLPvzrwOlxbN/5KU5p74XpLO7yLBZ7dT7bfW0R23VjxUtQlEvacymC/Txec/DeCI282BAPMH6S7RnRSh3Ki9e2MglVIG6JIamAsOf2Fqz5xTbmbDHOHfAbcok8NcyWs2On4U2B91As5p6icL+0ni+bjjFfzmS9QY+wTYBzhrRp07r9DXhvfiLy1EA98f53eLeSqa6eKQG0LQ/8pKvyQ7T3G29vbxJeh4h5nOC1rPRJvCEw+OoPiMamE0KiSSoxrBCV7a3xfKkVAHRcflNI4j8N0lVkpybk30aqVKkym6x6md4VPB6m+Vsco4qC4FdN64R5ZuPDF2f+9pydvOlBmCZZlLi+rUjO800oqxQoIWfgyFbnIpGfGGCMud1+NFlXu1GP25ugIiDAkXqS+FbG3AqfAdaztmiDW110aJvbCxOmBNggRXvtLkolMzxFhsQ7gP5LhvIJtO/iIazzpK6seb9gNu3QHFajxefcziHFNerxNXdHbZrAes7tzxV9dhgXwnmK4NZjdh/uxli1sdvinmzjSj/Fel0BA+H7+j2a3Og6vSe3BtFpYihrP7Yzaz2qA2s1vD2oHWsxuDVr2j+YNe7dnJGuOAs1dkFNuD3GpgNasuChbXj+ViPaswKlCrI8Of1dDn6j3hjqp/E5SOSf2Xg0V85cVwuVLPSg6CclfilZtczfZWqWZxW//JRV+KoSq1C7EvukVkVWtlYFVrZ6OVamRtl/SlQu9WuRckV/zles4PU8+T8+myt3riM5c+c8qFD2D7LvwwTKlbm6Q7na5WnpfTkaOthb4zXYN7UPJ59U3kN90/iM9U3rE+6TwivCQ5NxYQZN2sg0mhSRSBupcULgX6TtAXX5rwu6kD1eAUE5+cHhNwGYuK9gUv5O5P9b2PLHrgw6T+1k9I0D1D+yBQYd1Kbw+xaf/XQOj1Q4HMNb8AfQz0RpNSkfZ9Fk+kOfXsuCArOyHB/mYLkLffxXwbKFH2U1Bv5Nq+FiHYToZ9uvqIWoq8sLsO8PdGPbf5zPdlyfy7473JftujaPbb0ZyS6tLMCO7O/Azm1pwTbdXsLOxFRmsZdmsD0XpliELnKfbOUXJn5YUZl9+/1Adm5DTXZ0fwjbAOFs1w+z2ZlNNZBnOjtwMozdnarh+c6tq4g0nS15VW15NObVbPW+LcDYXZMhQwa3wlBCoZzzxBjYK8YpgMBhO1cGv0sBAWPJ7TmzbNmyuZxnCQFWU1pW/wH03SVoF12CsinfdUZmy+UoMjFIF6D2I98G+BfCT5ekbGdbwSO9jNEkzAVYtoQXgXaDd09Jo9fr/REuSrtRKIcsu/jCn1mn02VB2j7wV1DSOgPSxLuVrAbS043Sr1BuY9RLW6cdQaHg9QDVAYXiN3ZEO9qByHpMgwCLHsoayPMZwtXg1sD/4mDfVeIdgmL6avbJSG58mgQuUmpLNk5JgFt+Yx2L+N5iGJvsnOYrkI/bEe00oSv7qn091qBbY9YvcjDL8V4OrqE98vJKluODnGzxlVVs6oFZXNgjkzpivc6ATpk1+uHWJ3xCtwqBCy9Y7LXaCO1TBMS1D16oViC7rHbprETCo8hTKHfBPE7bVblhVZcrimpKkmWKJ/Zhg5/B5apUJk3aBLUjMbTh6fbneM4rxLpeJfShcQ80vc9y5b26kLgIv/a7XOpcSyi0Wm1aTGazMMkVMFtuqmE+888KIj9tPxTChEdKR4lIpYiaGCZms1imO3hoMnXw0XhN9UvrM13vpZtr9DNEGnXGKH+D/xr8hysMPvolOg/tfAjVsyFoT6e0XposII+pELTgetpdlhDhrfFw+K9EEvubu74Rvj/CQcs8G6FJIa62HTw1kZEN1pO7O7LTW75k0b/sZKdiu0DIKsmikfbo4WFcUfD5jV+xC2ursNiLU9iNeSae93RcX/bdsTGMbsFeWludbbu5mH17cgw7cWgUi7m/lt2Yo2FXokqyvafD2I8Lc7LT2xrz8XtucxN27Nt+bOMDexuq98M9nI5HiRdAvyUN/HQuuBLcz+EGg3piHIy20ijQSCLED8Y46A2iQ/+U7nP4SQiorS7TYDCQ0t/PkKcg0hEVRrrP4aZV1euN+BVI932g5ZLQDcTvA01Sl5UUBKgsIqDcLgGWywk3QHdBD4nAuw/3DtzbcG8RwU9toHRnAywqQ8h6wUG0PaFt4nNScgD1urTLLCHxyjDlwIubb+ufvXgp2L0cntm/MLhrTUsCmpJOHU98JZxQAc7bw9uT8pGpnTmnFsNdwBZeXMGWXl/D5p1ZygXH4dFj2KzjC9mgqOHcvBdZWZi0ZwZbeCmK10WmfwatGMF6zu3HRm+ZyA3YU5m9Fw5kk/fOZEPXjGb1QhrwtENXj3Z6O4+EPjK4TdYbmg9uzctu1P1rturuRr4lPPfMEp6f7EMqv33hxSg2LDqMPxebpnrrc6N2W57JTrbk2mpeBvEHrxzJukzp4fLZrHmw+cV/QM9V9ay7z+pjF04MQaBwebA3OaEL2VtX3yXO6UqQPjQ2TuS5AybIzXRzTglj0v5CHf8qgZfKr8p/6XDcwMoXSZ1O8bcd3dHlf73i1nqHMsrVKs8/QKjvkIm3aYfmon+/GFNN+jRnY7ZOYtMPz3XIS+NArIOg3sYUhTl3FP3UfrVMTXRjVh0+tast11u38b7FTmtC6c6cgk7bLGFBgEUI6wUqRWQ0GkmAI91m7RDXDdQHNBjhkaBxILI2MNBssQ7SFh83lJ7y0sF9LryAvxFElhWIT2fDeNng0c1Om240lHsN/AVwJ4M/OcCyirUKdB9p89gamQSg3N/JRTnjxLj44EpYQ7tsuutMVjNTadOmJVvGH9GZbWsUnTX7jTxowxyTvZ49m3AHATcH4sJVcQ7AM7EpBZeQeG2gF4A4kaqJXh7N+lmMvKtp9c8vzq/ERwndQsUEk40LfiDKQy8hevlRG8ZuC2fTD82xCYd0E4/UKVSuX5WtvLPBtjqxQfVCDd83kwtNJHgp5VG65tbf03/xsKdK3X5+fjalllR+1xk9WduwTixn9pysfVgXVrJiSbbq3kZeHq1KVmtSk7dFWeGrF9KI5SuYjxUsWYhNhEBJwledLg3YggvLWJHSRdkwCI5tR3XmFiXIxmTHcSF8O7dq0xq2Z5Mzp00XLcemP+yNgVP7Zx6djzIGsRKVSrKwzRN4e/Lmy8vaQDjoPLkbK1ejHBu+YSybEDuNt6/61zX5qoe6nECPwFcqwBlC9vTWd411qqxWhKHdxqOYHGkrhPTF0dc26Yb7ARPiefhPII5uhtptnSCe0l8Ry0LaqaBvMOFmxSTtB39W4sPv8IJBflqJPIc+twH+iaCO8FcBr5Ber38fYVK/8CfKypRZk/ERCWpkH3Ri3HTe/xQbodSflI+VeWct9knJnzN3TjZ41Ug2cOkw1npoO86njxB1G+h3aLVaWv14XylPISqzWLnifBV7yKpRrHabOmzB+eVsAD5YRsWMYzO+m8dWQuibvHc667NgoO1jSSFql7ouBZvvrebx3x75hp2O7cr9m+7Q6rVF39yGB+vYnrOjbUKZ4t6cpWEx91axfSeHstsRZrb74hS24clWdn+8hp3fWIOvmJPak7gzYexOuGWr1CIg7mAHv+uOctdDoIt+0T7EbUa961DGzmuzOe/OjFxcFYbEqwcJNRgXDgbYnQH99LLIU8McjxWC+IDy+Ye0OZGXGAhmJ8be1UDZG60uXQLgq+DIUxd+fnwCz4Hf7IVLVkZcAnncKq9HeXVEnoTEK8fA5SPsJn6R6MXyRbs6rBoEAVoJm3t6Md9apZWwmi2+YLNPLmJDVtubABKJzsWJ9ToDBlEu8UXmiuiFRatrIt8VKef51DQ4aiQJArMw+O7SyzTQokPsopjOGYkvzKRSiSqlyLSQEfXnRluqg4bQhAZ6Sqsu6rSjN01gc05FspApPdiK2xv4f7P8p2g2YbdFWKM0Tfo2Z8uuv1j5oPR05k9djk7j90ouhaTpEJfa0DUu0SpmtN32RWqGM7fnZAh4JnvwrLhOQPrfxHj0H9riaQXqiXSVsmTJQl/czZBvuJg2IUA5M5F/aFpNyqf03Jr1bclXe0dvnsjPfHYY14X/D1UbV2ezji+yHTVo2KMJa9i9CResRsWMZ598XhF5g3k8+tc5lLsdbZqNsum/vom2LnFY2RNI/WGSEKL+oPwO1BOIeq7DV2zbrWVceDpyoCO7MduLndrZjB04M4kdOD6IXVr9Kbu4tgrbexL+VeVY3Lkwdn3R+7y829M1bPOtJezU9sbszI6OLO6i5Rzcsb2h7OrqWuyH5eXY2Y34WHi4gcdT3NXl+dmN+QXZ3tMj2YETI7gQeHFVEXZh/Wfs1I5WXBjc/uNc9sOSHDz9nWm5+GqIxKsH+kMf9MNmIt8JUiHdbpGZnDBZbZLC5fronMHHxycNxomzDzG3qkTwO22rekg7BnWQ0XgyFr/f09OTbn1y3XoYl0Nf5HIE0rs1UYX4+iJPQuKVg7YIxclfTSQk0CpT+IFZTL3Nw7fvrC+VmsGfO+RT07If1yZIgMPA+sCVAMdX3lRUqFwRtvLuRjtBatFlMvz9Ii2tdPEw2kqrcGKZI9aPVb/kbDeyxHTOiM7cNXWyMrnmfuIMfZevXcnu2eAZnPHz8+O38Tb/L84hvVuynq9bdHmljbfaSXsya9L9qq4zOaAPjYvQdYltKfITA13IHqca1wl4LnaHdV/ljS6zoz6qW+IzVNPX/YIdzjY6o6nfOjfijr4X5LTfW8dX2JZJfBWY/HxFWnU8YSPGZvP+LflKLG3jK3mpPK1Wy7eKdDqdF34Tt7e4/eYyx3pAO69EcDfu0swX/Cdb2fn11R3Sviq6MzNfooX/dx34X/tDeKCtTQdFtgT0rVYij4B8owOsZuggGA3IkCED34HAuDJBmPFH3EcUpu1DRYDztzehmJznx/i4QL0uVfngd2RD/aR8eCvclgiXgH8y2uvWiDzKdLsti7J8yTVbbSnTGVqU3RyUP3PmzJnA52fb0Ea3W6SIbyzyJCReObRefq3WPky6nUUid6tRm/+IpYP6XClkfPD19s3i7FxXreDarGCRgnz1L2RaT1a/a2NWu31dtviH1Wz2iUgWOr0nhMwXt1/pdmibER34akn2D7LzixZr7tufJyOiFS2xDQQxnTOic24hU3uw4EFtWK2Wtdm4XVNZq6Ht2FIIq8GD27JKdSvbbua6o+ZDWjttA0EU4Oj3DVkzmm+P0Ytc2TZWXuq0GkRpaDtV2do1aQwOdXpoMjoccH8Z6LrusfsNupDYrcaQPf5BLn6ZNjRumshToA+Jc2k0WwQm1+OYOFfBXY4JdyH8tJo6C/7R4H0Df1cr0UrXbCLELaBtWMSPwWSdoJU5vMSMX7Sv81fDnl+zL9p/xao0+YyVqVmOFf+0BCtcrii/0Zy3aH5QPlagZEHwirBin5Ykw/Dss2Y1WJ2QBqxR76a09ev0uadPnz61IsCRELb02hrWc15/fga0Sa/mbMbheazl0Dbox03YVx3q8rOX9D/TJZ5uM3qzdqM7sQHLhvLV2M6Tuln6hIszcFvvWD5yiPafnWLZIhUv47ixu3p9QUb726P0saS22Qo6cHqsQz6FflxShsVdnu3AJ7odkdtpmyVsILUZToH+3AV9ezAEGrqkcwzhbqo429lRBUjzFYgLd2aLgt4VCD9BGeUxLlL6W1WWgE+XGrYr+RC/E7TEpFINkjZt2nT4SEiynk4aj+SiHpfnYq0qQ8g1YzyiWebKyKecOXEpTAa4uWSBMnrgd3JdePg9tjnJbDkDOBz12HS3Iez29j7a0kzkSUi8kQhwY6fyZdFsUCuHif1VkVlnWboXse7xdgddWa7IlfBaM/gLtzdgFarVprbTNhDooLo67bqn21hmTSo269hCVrhYERYNwXvkhnH81nCu7LnYzCPz+cUIWlVdBEGgQt1KbATixTqNGp3t7N/LAMKW07YbQ+Mu6UP39dKG7PL3C91VyhAat9PQJW63ruOuGroucaeQb6qm18UU2i77y0LY41reRRhCYp2WndxAXx6IiTrZ9GslFdMOz3H4n16GaPVZrIOw/vGLD5n9FyK4aa5jsc3ZpeU52e5Llm3RHT8uYltuLmQXNjVnJ/b15nZZb02nG6Vl2a0IL7bn7Dh2bWEK9mCshu24NpefZdt1cRLbcH8NozNvm+6ugKDnxW7M92a7r8xid6Zq2A9LgnjZd6doWOzFiezcunLsxizLWTmF7kZ86LTNEskPCC5lIai4XVUieHl56SC88NVbV0BZPiIvMVAJcAk+A4c2jTdZlfAqICXz9LGl5gW8OPfWDOljyQ8hkC5gxII+A58rFjfFc4GCBGSRp4YiDEtIvPFAZ35lWx16vT4giybzLXhJN9AzEG330S0lOnj/F+gffG49T6tJ+Ty9Js3zTJr0z300XsxT4/GPlybLcw9Nxr/B+yu9JvX/0mhS/IG0dK6GyqDVDxJcqNxHmDS2WGp0RIA54O/ISysP0ZbsC1rJidSkkLvwctTfCy9F/Ynwr6CneGE+XHh5xZX5F5atm/Hd/LCwnZN6D1wxslXXOf0adZnZ6+teiwZ1nv7dvE3zzi39H+g5qWyp26UBm3NuiUsN3TMgkIkv5uQgD02mlz5rZAjdQ/9FgqELjbPdClPg2T7W06vzIZf6pSDs3RZ5CjDh0qHkpbRqAHoEegAidQPkJ91QxH8K+g30J/7vf+D+DfoF/dfhEgd4trrgn6+Oex0wm8xrhqweyeZfWM7V+Sh9jvrb4h9W8VW5pddWc79CkVdU/fFSFN/Wn39+GcsZmOOfNiM6fyLWQSA1IWJ/UEi8lXpsT0cuvPE44aapOkz5FHqRxvmHjaIeSCyD6K5cgXML0sYv8pIKzLOfYAxxs03xAWPmkMhTI3PmzC/VLkWAQ3sSNS9BcFyAsfol2rcZNDTAyTk0xNtMMMI/CQIp2VUlA/dcRYrJqoAXcS7fBwSkc3vWDvnbiTwJiTcSGAAzMHgGi/x/ExhApPso2YylvwkIPxDBRm4c53D+jxPdhPzFckuX39Z1RdZbvEQUpq3dCacWuNyKSSgMIbEuhSuCrnNcV31I3CAHfsiumiLPGXzbxnpASHSpIw99cIHISwzQX2wqEhTQSgJtD2ni0e7+X4YopBHtOz3KLkx638Q0XOBystrsrDwxfttPlg+RIwc6sw20PeukHKI7s/JKAc4NApJx5wNl7TEajfz8V3xAWrcKuDFmEnSb1RUUAc7HxyeD2XKujW6JNrQSKbB1RbQNzP0Yu3QWkPtRBh2jCKYy6fwneC6V8CLtUXIDLGcIXW7FIt0ekacG4juKPAmJNxLo7DdE3psCtG2W2WqQHIP6tekKe1VgjKX0zujl7ZPFR+fn7ZtlwLJh/jO/m1Ng7tllny3/aU3/5TfXLY26tX7Xkp/WnFtybfW9xVdXPlx8eeX9RVdW3l5wfumOqYdm9+kyoXsxg1avN7nQzp9U6EJje/p225dV5BP0XeP6QYCbow+JneDbZW8eTb8jqfWhsZt1XXbX14XGHfVuF5dVGxJXXMxH0IbGfq4Liasn8l0B/3kA/uvqShi/c43VpVtn+/HVnQEu3U5traRxt+2DF8ouczzqCf6LIDtF659sfi4KTrRlenFTe3ZlVXW24f56dvTwEM4/eHwEO3yoJ7u2rCy7vLY+P3N5bH8PtuHRRnZ1aR6eJubnNezyyk9sZZ3f1pEd29eTnV1Xnl1CmZvuLGUbkebMzs7s+K5G/PzczusL+HEAsR0Px0pLDPEB/XKI2aLklpTYkjJbukF/z+oSEf8a6AroAugciKwaUJ7rAZatQ5sib/CygraBt4o+XuDuRPg2pccYsV0QQHgX6CDoFOgo6LQ1/D3SvZQKDdT3Uv872j1P5KlB8x7GdBm0lfTlTQMNRpi2kPlFDRVSQIjMhHgycs8Jvy2jkMYpUJ7bLVYJiTcGer2+mch704DBuQwD8CMMXqfKeiWSD4aQWKf6u7yaXnG7kqXvEuugewllORz0x39YUuSpgf96BL7aRxgMBq6dHl/dgep45K+FNNnUX8lIk06dRgHSVqMVAUzcpNXe6YsFdXhjDAQhTW5QMeSpCKoJPilEJbM4TUBfgaqBXwFtKwZ/Dn+L7Un3RrH9A/m5xkVXVrCoG+v4RQVyIZiz+WeXcSKVJWTubmLcDDZx9zTnFDudW1ep2rDac9Rvux18bcmHv4mC07br81jshYns5I6m7PoCDbs9zXI2beut5Wzjg3Xs+sJs7PDBELbp3ip2KboOi7kfza4sL2gR/q7NYTcjNGzrbcvliJ1XI9iuKzP5RYitt5exfScGo3w6J7eCHTg+EGm2su8O92KxF18owSYiRcH3R2oKqJ+FxLsBs5MjDYkBxpXtw+zfgll1aURC4pXBaDDmpduNG3/dxQ/Z2xTm/r776NY/42Zte743bNW9jWPnnVk6edrBOVPHx06dNnrLxOnD142ZM2zt6NXD1o/ZMjJm/O5RMRMOhm2ZeDxs66TzY7dNujZ+Z/id8bumPgnfH/E3KZslSwp0oy7q5nq+fUe3UTdx2s21yJNuOKJ63Ro7fUm+LAIstxGD8PIq5epFLJG80IfG/qgZeE5kJwi6kLj/BWg1tJIQh8mwM9yqIFId4IX/kN94g5/sAm4T8yYFKCeNyHMGtCXeW7Fon8utFwW+vpbdKmHlz+7skMFb/6daqFFb/YiPSCWO4i9TtZxd3IZfd3Bj4QqeDtOwDY9iVFuZ5FqJeFaiLVOR1v4Wa3fmLWH0Ir+tfOsZOeKd3VyPPRiXiq+aS7x7wDi32SRNCvAxZhB5rxuYT3qKPAmJZEdaTYotfFLHxNl7EX0Rb+eHodUT/qq7MS80zasU4A5fT3YPt7OI4wu5uSt1HjIXpQ6LVLF2Za5Hbs7JSLbw0go2fONY3gYSILVardtVCXfImDFjKm9v74wYQNnxsi0IKkMrIpgUyOBvDbhNQX3hHw+XVmJqwE8KcylNUQh3pED3A7xY6QaTBymMRLGp4I+3TUhj8E3lc7Na8xr/gFipqmVYnvx5WJAxKyPblpk16VlaDd8WslEKlT+lQOo4kSg+vSYFey/gPVaoTBFW/quKjOoEPS9QvMDTvEXzudUU/rrg0T4ukz4kbqXIdwVDSGxHfcjuWiJfBNk+xf+WE//ZY/xfdqoBwO8LnltFmwSk6av4MeknSIBDfblNlu1Xl0a/0Xf4CwSurXw/Pz+71UcIeVzlAcohsz5OVyZ9Nd5/KeNFUQ2z/OY6Nvf0EpsgN3zDGK5Qm9TYNOnZjPPWPtrC6nSsz9XItB/bmeX+OPcLc27WssS6CA8mpPR6GqbREz0BPQjTmB+M1mR9MkaT7cFYzfuPx2k+eDRWk+vxaM2H8OcBP++TcZr8z8ZoCiJc+OEYTZHE0qPRPO+Hj8I0QVTnxQ3FXF5ikXAE+uP2TJky2VR40Bynjsc44Wox0qVLlxpxkxU+/FuQd7AtoQqKig4RAfGcfUsuoJ6LAis92rtI4L3RwLh2qodPQiJZYdL7n6RJPeb3XeyrDvW4XqlFF1ewGi0+Z6VrlOVCVvsxnbmZp6JlinNrBxVqV2L1ujbmN98o7/jdU9niq6tZ6apl2ad1P2MlKpdiHcZ2Yf2XDWFtRnZkHcaFcMWiJOiRJnpSSDpuZzhbfiOamyIiZbftx3SyCXCQg2wTUkJhMvrvoFt3VI9ifour9Hi24znq+x3tfAy6A7oBegD6zWJ+a7tFQeoz5xcDFJp5bMFzs8l8RKxXAV7W5XvO68fL423gqwrWF+av8asPcUckQIs8MhvmyHtBZI3hg5zZnb6o/w3oQve08OscW0zkq6EPjbPpl3IHPOs+ILdCHl4CjWgShfur2aJxPQhuF9BGCOkzEK4Cv2150NfXN0E355CPPgpIh1w+tCE//HngD8ZLrza5iP8QfK54GW4ehEehP3vDbYq0pJcrEMKciVYJEI5Bnv6I60rp4T8BXk+ER1NYq/G1+09pHK2+F8OiIMSRJYc+CwfxD6v+S4awaYfncvu+1Jf7LRnKph2cwybvj2Bdwruzxr2acVvBSjmudMJJ/PeAPrYaQpoR/SYc/aYdwmR0fq9ery9E8eAvRX/n82nAC+W+KcHXIn0LuFPgFoBbD+neo74NKm51qS9yNRzUf61l7Id/AX2kwE/6FmuhT38Iyoc6PwSvPPJtsNaTJKDMgyIvsUidOnWS9dAlB/AM+os8CYlkh5cmy2FlYifbjnQwWTFJRTZFycapEqYve3Lp/A0pwlUU/iru4isrbWk4PbGs2LlajaM4nhfCDukwIx4JcJgcErQaokbdzvWvU/5CxQvx1Yl5oG/m9ONCqWJ9YOx2i14r2rINzBDA/Q1CGtu1qctki+JTapsihJEAtxJC1NA1YS5ffHovPVfbsObBFjZ2RzjfGqZ8VJc2rZYf0ibj47S6OQdtU9RC0As36tY6VqBMIV7XiI1jWdvRnfgzU1Y9udUItGXZNdKrZUkfjXpI675F0fE2LoCTPwQvbMpXtVF1+Hu4bO+/BUNorIO6EX1I7GFN2/1OV6GSE5hUuWUHuA79i2yQijxnQN6CIi+5gRfYWtAeP42PXd90RQvOL3vRV1V9VkynEH1QiHVKvB1A/+TCGtx4t/GdAf3O7uwWPja06rAI5TiDKrw6KR/gakCQTJCid3dAO74Uea8TeP4OKkwkJJIdBr3BDEHtH2VyJ4GKtltW3Y35c8XtDc9W3Fr/MOrm+vtLf1pzPPLyiui555ZMnHZ4TkjY1gkNBq0e/mXIzF7V6nSuVzV39o9J+WkVEC3h0+BpAKpTonTxerXbf9Wg9eh2jYasHdE0/MCsfrPORs5ZdHXliWU/rf11+Y3o36Nurbdt8dB5OZO/f7zblSKGR4fx/Ctvb+AWFWhbiVYdaJWPNMuTQNRquMUGaNjWSYy06EdeWcGNyTfr3xJCU0e+yli+TkXWcXwIm7x3Jtd0T+nJfijlj/h+4d+ZMmVyOjF+2rgqf4aKeTF6kZLJMKp/wLJhXAhu3LsZI11ufLurTzOu34vSklBXJ7SB7QXbelQHNuO7+TbFv+O2h/OVF8pP4TEIkxu+byZbeCGKC4FkRow09Tfo3oQr9l32UzTPL7bzTYE+ZM8wbUicW11LiQEmzCgQ3YSrA6rnguqDWoN6gnohfTsQXTQ4iI+GeLdcCchHN/JopewK3PugvwIsdnMTRJQWef8XYNFPdxP+S3CPw/1ZrMtL4+EgfBFR36b+RX1t3tmlnEerctQPyEoJhXvN68/7jJiXiAR81LcSLzluLkmNTJoMAX4ZfZsbfPVzdF7aYR6ajKWR1qVaCMTlnn9h2U2xjoSS+kiGetVaJG1mv5Ni3e8qMmfO/J/eZoZQyHWuuUGi538RGFM/iLzXBfy+jAn4jRISbwbwYjoj8l43SGgTJ/3EkNMVi2f2L5WwzZN+8VcJl+qXfukaZbiBc4VIgHIoz0rOt0Sdk7PVS9oeE3nOKOYdWmkxmUyeECYOmd2cfcP/xW2Bvi6Y49EVFR98NF5/iP8p0ZQDs9iwtWFs/K4prGrjamzW8YXcnFbfyEGsetNa/MOFzLr1nj+ArX3gaDJO2UKFAFcXzy0Y7TxP4dwF8jgVoqi/2bfMDsFKOlI63GNuX76ST+XQWTvi09haY22HUv6EuGnczVPwY37kgPw1m1tsKDtrQ/sJIe7a8E4BwkmyWE75t4D+NkTkicBQtbs5nligXy8Vea8L+H9e6hathMRrBa1giLzXjT50/keY9EWK+H6BAy8h5q0Umhg77QF+axVMDh1AEzFQFyF8FgLs04LlCl/m6SD0BQ9rx2q3q8vz0MuLtqU7TbFszdLL6YOsH9jOySmCY6dJXe0M3ysvwNGbJ9i2c/mWKdwOE7rYXnLRtIIBP62cdpwcatt2JaJbveJz+q8DE3shDw8P2/kWhKfgf7jo6uC1GuZ4zN8kN1Bfgs70uYJRa5gv9sHkoO4RvW39As8tL9r5A2jMgKhhPF7pey2Ht7P1T523try6bQq8Unp+oZQ7/bt5rNeC/mzo2tGs/9KhrOfcfuDNZavuxbB6IY1Y+P5ZrNuMXmwmxiHZMSY7rUUqFOXHHAavGslNwCmrybRq3WZUR1ube8zp+9b15aQC/1lpkfdfAubOfSJPBPpjZ5GXGCD/v6LzE/V2NRgM/PyhhMQbjwDLjc7DIv91o/PErg4vKjXRCkCHsSHs697NudH7Rt805cIb6dCilw2tdDmzE6qmJddW271E8Nu/x2/PSv5iVUvdV9KF74tgNVrUYg27NmGzT0SyNQ83s+U31vE4qqtY+eJs/rmlXKBsNjCY89uFdWItBrTiL09aPTFlMPJzhrTKMufkYlax7qe8/umH5/ILI2SwfPOfcazf4sHIY3np0pnFQStGsLZjO/My3+Qt1KSAzud4e3tn0el02Wk7EpNlgkz/KDBblJ0m6LLCywIv2Qqoa5PITyyyBmblNm3nn1/O5pxawm97k6A09ds5bPLeCK7fbfKembzPTf12Npt+aC6bgXjqW3TDe/65ZXyrPvKyhcp/VYkNWzbK7gwg2pmBtnZJiKJ+o1jrmBQ3w9b3/Y3+T/D8fsZ/EAa3Noj6fnGTv39JcZyIJK6o2YWtfs5T+4UyQmf0fKv68ssC/9djkfdfAPrMNZHnCuhjk0Ffi/w3FOkwJ/3zsiuHEhKvHZhMXN7OfF2o0rCaw6SvJhJuaCsoeEgb/tKjL306K0ZG3i1ptrGG3b52yKcmOqsm1qugStNq/xPTx0f0olK2llxRq2Ht2YRYeyWnCaW36bZhgMW+4VVMko/EuIQCL49Ys5MLDK8KaG+S2/pvQDmGUL9rY37jlW4yK31Jr9W3UNLhGR7Ai2oG+T8umr8sxdNKnbJl6oyUi07u0hDRuVGRR0TnQl+0VIKA/4EshIT7+Pi89JmxVwlS+YN20rlTl6bw4gP623sYvx+jnJKYA7qirOkIR8KNBm8n3NPg3wbdA90HPQQ9Bj1R0VMrkZ/sX1OaB5Qe+S/QQgTK2m2da6IRXo7wQvgjzJab7KHwNwF9Dn8FtIkUctNNc5PYXgmJZIenp6dPOk2q+9Vb1Pq7SuNqv5SrVf6XohWL/1KsQvFfCpcu8jRP4Tw/5/oo5833gt67HqgNuKpNqb3oo8l8NqMm1YnMmrTf+2l8jwb4mI9m/yD70TwFP/6+QImCxwuXK3S6WMUSZ0tUKXWxVLWyP5T7ovyNcl9WuFOpQZXHVZpU+71acM3nNVt+zmoQBatI4YEovmarL/6p1br2n6A/QL993ubLXxT6uGDeZyazaaP4e9TAoIqiQ918WzI+sqoGcWo71MrjaYQ8geasLl8ipaqX+VV52XSL6M2WWG+MknFx9Yuo94IB3K1Uu7KNR6oeyKXD6XSRwpae1JvAXXBxucMLTSHS99VyWDsuXNLt1bAtEy2qWp7+JwU4Um9Ak+kZ0OUAixmgn6zudUy0J+EeBp3U6/WJ/tJFntwiLzmA9jQH/Yj2nQHRpYRroJsBFpNF9DvIfNExzPPf4vfZrCC8aajY4FOH/kVE/d/faORGvkVk1GRqQGOjS3gPNuf0YvZV+3ps0t4ZvM/SxZ0RG8exmUcX8Is4dPu1S3g31nNef9ZyaDtuPYJWiZVtWhobdCkjeHAbNuvEItZsQDArWLwQjw+dKVfgJBIGo9HITXlhrAVgzA0T4yUk/pNY92R7gleJaMVKHRaV+7qiFUI+RQhRk/rCgHh5QNw+IesNSjmFSxVxO4m3nNYiha+nbza9j97orzUazf4mIwaw3uRv8sXLm7beMuIFmxqUJqGUNm3ajL4evrr4lsb9vYw2rfl0I5DUmFDbIZiyBReiWOUGVfnW6NRDs9mMI/O4zrwmvZuxPosGsbyF8/F8ZCapXkhD1rR/MBuzdTLfdu01vz/fRh0QNZwVr1SCNUMcPaO2ozrxPHVDGrFOE0P5wfGCJQrzreCwbZN5HKkwEdv5JgP/VS/FnzVrVrdqRQLcHOTG/5wek3dnlKHJkyePW8JHTQrUOwLZnJrSSiDctlUE+uIbeYuQnmm5ryr8U6NlLZa/eAFWplY5FjysDTPqjdfEtAqMBmMo9ce1D1+sJNvGrJqebGPrrOqI+K1w+OmIAIXJxJcybui8KJ2ZUy7v0PYvHTeQK3ASiQHmazNosP9bYP9aQkKj99OdVSZTRWjKkS0HnzCVsycLLyznqzZ0+H1i7DQuUJDWdzJ7NW6HRXVF5TpVbQf/N/8vlo3dFs6ibkRzdRaUjnSwUfk0AdPE/kXbr1i3Gb1Z455NbZP5hN3Teb0UH/1wKxc0Iq+sYlMPzuEKhHvO6cdv2lF888GtbfkoLP6uNwWBQVnvKBcIFCHUJoxaD2Zb/HTWx/J7uLCrEnCV1T6L3jcrn1yrn/4fEv6U9GJdCilx5WqXf2OflytAmCoB4etbuJ+IcQJc6ppC/lHkQiCZDhovxjsD0jnop0sIzNaLEXhRNEjo1z7y9BB5CQHqIBuwd0FPrERC7NPUGs3vXhqPP/Qeuj/NRtNfQe9lAwWR/3edh/ZXT40HpVPyEN1BG9pRmWjzGPhp6yjIUkvigbrsLgPFdyzAFSn6JkWiPo12SjUiEgkG+ssQjJcFvr6+XKm2hMR/Gt4ar/3qCZEOzZOgRjcba7auzSbvm8km7JrGvu7bgpWpVo71mjeATYAQRzrL6NbawOWWG2p58n3MNbt3m9mblaxQmvWCsDX14Gz+1Rw6pQe3wVjqs7Js5Z2NXIEuCWofF/yYT+oksNBNs+7I2/Cbr9kyCH6V61dl/SOHsODBbVm90Ebc/E9NCHGkBJj0sLUd0cFuIhd/15uE4GFtn9Oqgp0wpRKo6FnY6LFlRcJCSlgVbyV6DjYSXmquiOJpm+r9999/bee9kguYeEP0er0WAsVDnU4XAHcYeKcwGdfRarWeELRikSwF/A46zBQgD1/JCwwMXIi8FRGOgktm0mJRdhovLy8jyqMzNAO9vb31lJaEPftSEgaUEW5126IMOj/TH+WnQ5gsilRD3YVAk+HPDB5XLorwYvtS4ofJ3xSu/LdqIV1NXPBXhdXms0SivoX2LEVbfgf9Jtb3KmGWZoYkXgMwFk+JPAmJ/yQMfvpr4iT+UoSXCAl6DvxXSG+6AEeAYECmlnKoqBBelBXgfoUJpQnclqD24HWFQNEbvEHwjwJNsAoV88Cjw7mczJZDtLNApC5jHOJHwB0A/jdGo7Ej3EbgVUdeWrmy1Su2622A2d52qS+EOKdKlfF8VqvDeE6+eD78trAI+j/IRZ6FYlxCgHx8tS8xMCXh1na/pUPIHBwfA3SLukmv5mzhpSgu9NPHEx1xqNe5IV+tpS1MSvfJ5xW4q9YlyM+cWQXAJn2b/yvjCc/MrRk0CQk3SGmdL6ehH4XC7QJqB38rUDOM5waghhjvjcGnubYx+ORvZHUbEw/xNG+SEu8G4NdGmGxi0wfXZ1aqRv0Uc/SX8NdHHF1eaA5/K6SlSxRDwJsPN7/YQAmJZIfZ33RLmcRpG462OdUHiBXi+sTGh3I/t+Fp3b7jqztIS/ZDyT9o5QjbtknJ6qW5Syos6nVuYHtB0GWA2ScW2W0biqsHQ9aM4uXQC4m2IIdZLSoopE7/XxDgJJIPmCDPpE+fnut3w8TJ7YMqSJcuHWk6d3r2DJPqbpGH/LlUfoctTPCSdJMadfUTeShrKwRMfs7NZDlfZ4eAJNzapqMMyjigcTJ+5xRuRWRg1AiW+6PcrMWA1ixkSg9uPq3fkiE8jix1tB7egQt4ZG2ExtY3c/vaxmLUzfX/yngyGAwf4rnMFfkSEq6g1+tTQnAqLPLfBKAv225oS0i8EvgbjLYVONLcTtsrJDiRGauu03uyQJ3FNugcvCg2wCU9aXQ2jQzVNx/Qii2+usr6pb+KJn0urNVuU5eFIm/NNhbzPXROrlGPr1mvBQPYjO/m8hfNnFOLueBXvVktO4GsfvdG3B2zbTIrX7MiazGwNT8DQ1uoxC9b7RNWufFnrNfCgTYhUwpw7w4wKc6AoMMgCNFFlDbwL6ItSTGdMyB9pMhD/qnkQrjqFGAxPm+3Sgn+D+pwQoGyuH1VBah7Jso6niVLlqyog77Uw+HaCYz4qp+pDicEZM5NGb/OSPwwckZimuU/Rf8r4wkvYlpVPiryJSRcAWMqSSvkrwvozytEnoREssFoMJ4WJ/TXQSQEirykEr2A8CXmK/42iXcPEJR8INA53ULFZP+NOgwh0AAnJdKXwUS7GPFFQNnUaRCOVocTioAknJ1DXYneQpxzMtJmr9gZtRtruZXsjDpOCGUth7VlI2PsFVUvvb4m0Vu5L4v7zCYzVlTzJSTeFGB86vDR5YMPjUqgzKD306dPTyuAX2q12hRwK4N6geT2qcTrgVFvPCRO7AklWnmz3Zy8tZ4bnBfTKEQqMxZfjV/lyKp79geuE0IkwGXMmFHeKnpLERgYyDApGskPAS1V1qxZU3t5eZHaF7pxarddSmnVYTVQhjcm4Owi3x0waa8VeQkFhLiVyK8WJlN88MEHFE7h4eFB7eZt9/HxyYh0z1TpEow5pxb/pYyDzuHdWath7bjOPwqT4fpcH+RiQ9aE8RXvDuNDOL9+10as/7Kh7KM8H7LgoW35paTPW39pG0/LfopO8m9WI9AU+GTB+WVswfnlnEjv2+S9M/nq+vD1Y9nglSNBI+KnVSPZyA3j2Njt4fwWOlmSUMq00aXlBTJnzuzyAovE2weM557qMMbbTxhHE1ThTur45ALq9RF5amAOsnsXoU30oSghkfzwNxi3iwKRMyJbhfVCG/It0z6Rg1n15p/zA9LtxnbhZ+N6zR/ARm+eyEp/VpbfLCWhqu+iQazrjJ48f60Wtfn2bK3gL1iJSqVsB6hJl9nXfYPZgKXDWHuURSaBaHWOVIfQ7VTSYya2RSS5hfruAZNoCZGXUECI88fkXg7CYHW4dQMsh5jp4HJNlEsXP4iqGQyGZBcIUMdskfcymHd2qU2Ai49IIbTIc0ZRN9d/L9aTFMw8ZrEx3G1WbxaJeUNdB6kZsoXxEVg/tJGdvV6F1Dwa52QvlfxVG72wsPJRno+4W65qBWlr8h0CxuxpxY9xFWx1W2M80yWFkXB7wv0TYzmrn59fergvZfNYnR/+sqhfC28qlM3PtaIuWplz0BuJdgSJPAmJZEH69OmzxPyeAMPtasW7Kh1kSphuvZGfzqopfnWa1T/H2PykDNiVbidOVtUYZI/UIc4JkfFr8XdJvN3A5PmfVMSZ3AIc2TQVx4NCZH6KXzBSxqNA72d/3zZGSeWPwl+JMSzWkxSM3TGZC11NejZjA5ePYM0HtebqiGbiI637rL5s3rmlfL6gM7d5C+Tlinw74GMwz0e5+Ydb2NaJ/KNu/K5p7Mv2dbn6oGU/rWXD141lXSZ3Z0PXhrHmA1tx6w3U7t4LBzpcHJF4e4Gx9J06HBgYaCZXp9NxXZCIJ1NiZMVFp06XVGDOGUkfdiBuuQUfgsHglVc+JuGfBCIlwY1AdZV8/vEoe5eQeCmYTWau7ZzfKHVDNsFNfehZEdLUAp2F6GwOrQ44o7+t8UTPhXy2evg5OSftUNOwtWOYOdD8SpbKJd5c4Kv2G0yW3UT+mw68TDaIvJfBnNOL+Rk4uiXeckhbLugs/XEN67d4MDc7RQJcx3EhLPxABKveohZfSaf0lepU5oIQWTSgj6lh0WNs42/64bnJIsApRyo2/RHLxyrdPqcxTYq9iT95f4TduKd4Mq1FZrNW34vh+TgfAl7E0QX4LTtt454sPJBVkg3PLCbuKF3WrFk/Etsg8fYC4/+4yHsTgXY6VVUkIZGsSJsibXqTwWQ2G03mAFOAOTAg0EL4sgnKGmQOCvp3idpB7aH2UTvF9ku8O4AAl2QhI23atCnRl6KpDLi/gP4iv5rA+xP0W6DF8PUd0D0IX5+JZSUEj0dq0j0Zq/F8Mkbjg2H1+MEEjQFhHcK+j0drvB6N0WTUjBVzJQw9ZvU6ScILF5CsNnvJT4ISCWaKmSoSfvotHWL7+FpzfxPS7uACXqfwrtxVLCUEmYKS/GzVmPLtbPsPLmt9ik3hTX/s5u2y2R52Y4P4hS1iqz1ihaxlr3uy/Tn+n8piGyTeXmCcnhV5byL8/f3tLkZJSEhIvPXACzmOzqZhou4AfwioC6gzeJ1AbencC+KawuVn2EwWpZxbQEvEshRkyZIlDeJdml/CZJte5KmBvH+IPDXujtZkP3J4GNt8dwVoJdtxfQHbd3YyO3xsFPv+u2Hs5LeD2Mn9A9mxQ0PZkaMj2cGTY1ncxWlsx08LeZ5N91axw0eGPX88TjNYLNsZ0N76Q9aGRYp6G5NCVEbwsLYsb7ECybXlZMLzykuEdpZBsFb2j7K3/KjgR9/kzJNr4OftvoxsPqTV8ZZD2t4KHtL6z2YDW7KGPb7mq4i129XhftoepcsXrcM63m06qOW+qs2rz8pbLF//fKULdXkv23uf478vTuWb31Il1RKugf/9ish7E4G++Z7Ik5CQkHhrgcn5jMhTQTQF5nADGcLCZZFHoNU1J7y1SL/K6h9htqoSMVusY/gaDIaP1emRNp86rMZaqzD089RAtvHRi3OfIh37dgBb9+zFAf11T7ex1b/vgd8qiD3Z+lwsO4FIofXRpjIajKm1vto0ufLkSlu8aukMOfPnMkCIIuF2QM7cOdKZ/E1p6BZv5syZnapckZB404G+fEfkvYmQApyEhMQ7BUx6tksK8G+D0FQVbge49628JkajMQ/cX0FVrDzbrTQIXfygsQiksVudM1sV9cKdjbIrwZse7kG8HLaD/gaRUXc76wCI76AOq6EIZGfXlWEHjg1gd8M1bNuPs9iRQ33ZritT2N2pqdjOSxNZ3MUp7MjBPuxMTA12PbIYW/NbHNv4MIb9HJ7SJsQ9Ha2xszKRXMDvoS1h2irmh70lJP6LQP+1U73j5+dnd2ucdLOBRxcZXAJjeZLIS25IAU5CQuKdAiY9mzJMTNQtPT09M/r7+9NWWXOdTucHAU2HyTcHhDiuH06v17+PuCFKHmfX+QlIwy0viPD19SWVAAkC6v1a5CmwrbJZz5oR7bg62xZe+6vlYo4Sx8PKKtyznWztby/Cj0doIsTykxN4FlkhyN2G207Nx+9rrg5LSLyJQD/9VR1GX14AHtk7DQaVwpyQD3NHc/B6gfKAV5XS0VyBcHvMIXnghqjLeBVAG94XeRISEhJvLTCxJlnPGwFCCdlEdQAmUzs1HpjUE63rDWU0EHkK7G5oqwQzxX95WSB3Y+6vY4e/68dVZ/A4J/kej9Lwbd3XATyHQvhdV/BSU2zMXhLTSEi8ScAc8UjkvYkQBDindppdAeNwkciTkJCQeKOBr2m3JpUwsc2B0OHysH1QUJB4To4Dk+k4xW+2KP9MYbZckNhpstpKhb870nETWuDRQfmWJpUqANRbR/GLWK8S1o7HdWT7Tg5hR77twc5sbcJ5p7bWYlejyrObc99jm28vZd/v7cz5dF5u92WVcluLABcnlv86gN87iLaQ5ctD4k0G+udtIdwG4/Rjo9FYCmN0AD5GAsCbjXBx8NvC/RwureKTvjZKa0YaUug9BnGt1WUlJ1C+zfoL1an40Y54ze0hTWGRJyEhIfFGAxNXacUPYYLOwLXDZEtbp59gct6EcDNMulyoQtrd4PFzcAogwKVGvp2ImwHqBvoZefrCDVWncwKybdhGzUA5e9RhxNdUhxXM+ntYWvvt0V189W0deKe21rGsvN1Zwc5tqMairYLe0b3B3KWwklbJ/2S05qXUJOj8dFm0Gf1uvpf9PaZQULYgFhgQyAL8zcykNzF/XyMzehuYwUvPDJ56ps+sY7pMWu7qM8GfQct0GbUWHsKc76FjhiyW9JSP8vv7+TOzwcQCzYEsKCirrT5eZ1AQaz2qkzTqLZGswLi8KvLeRGDOeR9zxiCag+COIZ5er0+H9u8iP9wxmJv6kKCJNCsQtl2aQvgDxS8hISHxnwAmOrubn4kFJkHbFir8EZgcuXoQTIj1ycWEyc/OuYOfnx/f7kBauwsRtCqnDivYdaCdSb2CRrROuVWaBHo8SrNfrCOhMOqM+xUFt0SkK82ufEfF2zZa8sNqB55IZE1F8S+/EW3zu7KwQvXnL1nA4QawhERSgXF9Th0ODAys4evrmxnjMwvmD1rpoo8xX4rDh196Ly+vdBj/ZHd4MgQoE9wgisPckEWTyK3NxIDmD9Q1EW0hM1+2D9OEAPlKijwJCQmJNxqYVPUiT4Bb9Rf+Li4xYAKtZXXpYPNyUCYlzmzROzcA7hwKW18CNAF/o7GY5OGa311toV7QaFIpAsv+M+PZ0b3t2frHFlUipBOO3LXWlTe6vLDuF8uq28V1n7NtNyJ5mg0q1SNPRmpWinUkFGSHWC1Akd3iDhMsxuxX3FrPlfYqSn/JikPY1kk8buHFKK4PjkxckdLceWeWcv6iyyu4yav5Zy2mu77ub1k5pDKa9GvOTeXNODKfRVhtlS68sJzNOb3Yrg0xv+9mWq1W3nyVSBZgPB4TeWpgnOYE+Yt8CHJudT0mFKh/FaguqKN1ha0fqDuoOagW5o2lmGeWgGxbqEhH27pFlDAESy+kM0D49NbpdPz8qRqIsx35kJCQkPhPABNdbZEHoc4XE9pc0BH4/UwWA/TzQFFiWkyaTgU45GlLrp+fXzqUkR8TZ2qzVe8b6rQJcwqQRgdKjUmfvubzEC/AxSWGn/tqMq37xWJXmLZCj8d1Yid2NWMHj/Znm35ex/kPxmvYmZhq7PqST9iVldXYmY0V2Z6TA9j5mDps36kx7FxMTZvA83CMpq9YR0KhFpy4kl/riluLQa3Z9INzWL2QhlyQazOyI7eVSnZTKQ2ZsCKhbO7pJVywIwGvaNliLHx/BPuqU31WrHwJViu4NqvSwGJMvsWgVqxRr6bc/FXbsE6sQIECbHj0GF4e8fosHPCiHSgroya9SWyrhERSgLF8UOS9TqD+MpgbuAJpzAkOcwfmlR7kkiApxklISEi8tcDkGO92GybNriJPAfLvEHkE5Hlp3WqYmJuKPAWPxmnsVp1E+nGevwNPIb4iZ/Xfnq6J9/e7w/zzro3cJwu52YJ1RSTA+Rv9y4ptlZBIClyN8dcFk4ub8hDq6HgGXY5qRWG42THv7FTifX19PcHbgo/HI+Bfg/8K3DNwT6PMk/AfRtw+hLfCP8tWsISEhMR/BZi8vgetxqRWGW41TGg1QbUxudUmP75sPwO/EqgCqKKViiD9VrEsBWZHpbwf6PV6LcrKi3k3E1w6cFyG4hD2R3k91emteVwKcIT7E9IeujNN8/juNM3Tu1M1T29N1dy9NUNzBXT0ZoTm25/ma/f8sOTDnVejinx3efUnP11aW/63yytL/nklqvCzn8M0Nx6O0QwQy0wsJu2ZYSc80RZo5JVVrP0Yy61Xot4LB/BVs+nfzWXNB7RyFLhU5rmWXl9rE8JGb53I7ZRSOHhwG9YlvLstTkk/6/gih3N3FMbzbC+2VUIiKcA4XSPyXidoB0DkYS7xB99uxQ3tLA1eT8w9caBLGAPyYoKEhIREYkFfvOowJtZSBoOhkDXuCwhteTEJp4TfiMl2BWhh+vTpM6rST3yR+81F2BbLmba2ozqyRj2bsemH5nKB7Mt2dVnfyME8rv+yYdzYfeTllaxeaCPWdmQHzi9ZuTQLmdqDNendnNUPacTqhjZgq+9tYpt+3802/raLjdsRzuaeWcLTNuvXkg2NDmNNejVnjb5pylfmllxfzVoNb8eFu4/z5uXn47gReosA119sq4REUoC+xNX+EDAuN+LDjh9xeNOAtmWnoxgin5AmTZrUiB+rEc70Yg5KlnN6EhISEm8VMNEnRAGow600EvAg0L1y0zvJgQm7pjmsinEVJ88cb6TysMiHfx0pGRb4TvOqwg5xIDJOr4RN/iY7FS0SEkkFxuM0lZ9W6ItCGNqCD7Ic/v7+Q4mPcAT4tNWawcvLi99Ifd0IcGOJwcfHxxttLRdgMdm3G6y0tGIHvlsTYBISEhLvLDBhhmJyZ2QTND5C2if4guardP8VzD1nuT2aGBqxbqzNr2yRqinmV8sFjaQSCXAGX31esa0SEkkBxi/XqaaG2aJ2g398pUmTht/qxNjNqdfr02IcV7ZL/JpglrZQJSQkJCQSClITIgpQ7qh2+7ps1b0YNmT1KB5uM6IDW3U3hhX7pASbd2YJ6zSpKytRuRRbc38Tqxlcm33dtwWr0rCa2xU4kSitzktrs2ghIfEygGBku6UNYS4Y4dKg4v7+/nS7/CPw8oIKk1CnEMJlQBVBnyFdLfC+gr8+kcFgcKoe6GWBttgJcKirM2g4BMqRqH8k+eEOR3smgDcdflo1nIp8I8FrpM4rISEhIfGWo1zNCmdFAcodLftpLVtxZwNXIzJq8wR+sYH4tI1KRPyl19fwLdXox2S/1WrDNRG09uGWW3hZeYptlZBICiDk9CIXQs9JMS6pQJkdre5vKDcHhKjeoBnwD0Lf/QTuPAhV1SkN3NoI30Xa23Cvwz0GOg+im6UnjUYj3zpFHFdTJCEhISEhES90Ol3JPpGDY0Uh6t+iVXdjHpsM8auGkZBIKCAYkYJtWuH6UIwjmC1mqGw2kQNUN6D9/PycnodDmj9Engg9QC7KbynGCUiZOnXqjBD8XJ6Bk5CQkJCQcAqtrzaPp8ajRBZN5hKemiwNtR5+w/Q++tVmf/Mlo87wF+hvf73/cxsZ/JlCJhDSOSWT0URp/gH9baW/wLuOMmL1Prqxvhl8aqXSaEjJqYN2eQmJ5IDJYiHF4bKRAghYGTw9PX2MRqPWx8fHA+EhINpS3eDv779eTE+AAPcM5WpFflKBesgOc5DIl5CQkJCQkJB4J0ECnF6vT1bTbIGBgbshdOUiP8rvBsGPn9mEPwiC2CjUxy0vKAA/Dum91Tw1UF4E0shznxISEhISEhISBAhG3FSVKyD+I5EXHwICAr6DoJaP/Mg/Gf5xENBWGwwG0gtZFlReSavT6Wh7dKA133GtVpuDhEqkWa2xrgyCvx5hKcBJSEhISEhISBBcCXB6vT4FiK+KQXhqgHQFIYSNg5+bpaJLD+D1R3gt+HYKdMF7Bl6gmucKuXLlovN1ti1c5EuL/H6qJLQCNwm8BJUnISEhISEhIfHWA0JYd3IhkNUV40QgbXONm/NyClDW7xC4ku0MHLUR5QWIfAkJCQkJCQmJdxKKAAcB6a4YlxBAWMss8lBWHpBbM1ao95zV3SXGifDz8/NCOinASUhISEhISEgQIBh1E3lW0BZqRq1W64M0fmoyGo3eiMus0+nSZcuWLb4VuRRIHwRBz0R5rdujdluu/v7+nuC/JxLymJU0ar+EhISEhISExDsNtQAHIakTaG5gYOBB0BXQPdAjUgtCut3g/wX0GHQfdAd0EUQXFjaCZqCsmUjXW11+cgHlSwFOQkJCQkJCQoJAApy/vz/pd5snxiURZEiedMf5wt1DDL1erwVlA70XFBTkiTonwF+U4iAAMqSrgfpXQ/ibB/drhMuA6LYqA2WhdAib1JVISEhISEhISLyzgDDVEYKT3U1UCEufQXDiK2lGo7GJOo6APM9FnhoGg6EoCWYiXw3UyVBOtMgXgbaUIxftkQKchISEhISEhAQBglEvkMNFAtoW9fX19YbbEoLWYDrABpDR+NEQviIpDYQ7Mmg/AkIWlVFclTcLBLg/X5TmCJRxAOmWiXwRWq2W2/1FPf5inISEhISEhITEOwkIUv0hSP0m8hMDlHFYCGdQVuAyZ86cBuVPJT8EvR6IO2JNQwbrL5MfbhEvLy8PCGklkcbbYDDowCtsTccVAiMsBTgJCQkJCQkJCQIEJLJtyoWqxAB5Ooo8BRDE0kGA49usKL+Fih+FfJ2s/DtUL9KlgNA2VqfTFSQ+uUh3BHGDQZOMRmNO4sNvVMqRkJCQkJCQkHinAcFoCIQpV6pESND6gVyz5ZbpGAhUJvhDQIMgeOUX0xMQlxmC2f9Evhoo90ekixL5IpBOR64U4CQkJCQkJCQkrIAQNpNufIp8gpeXF9fx5unp6aVipwA/XcqUKVOlT58+o4pvA4StTBC8bot8NZDmLOoNFvkiIDTqyZUCnISEhISEhISEFRC01lnd+2JcUhAYGPhE5T+ujlMAwa2ZwWDwJT/SPFT4Wq02IEWKFBlU6SpAcLtAfrRPnoGTkJCQkJCQkCBAMIoTeckNk8mUEoJaStRlZ4EhMZACnISEhISEhISEFWaz+TToe5GfVEDQekQulQn/YbhD4R6DAHcFgtxm+In+ojSpUqVKAf9ZpNkHuof443DXgJaD9oKuKeVKRb4SEhISEhISElZAgLoJQamfyIcwVQ18bug+MTAC5CJ/PTFOAYSxQuS62mJVA+WEkGuWinwlJCQkJCQkJCyAgPSMFPGKfAhMdchFXCDS9NHr9RnASwuBbzp4ZeBfAP8KuKPV+TJlypRGHXYDfkEiPtAKHblSgJOQkJCQkJCQsAKC0RUISftFfkIAwW4WKJuaZzAYbIIWyi2ijnvvvfdSQvj7TM0zx2ONAeXzLVm40pi9hISEhISEhAQBQtbRwMBAvsolAsKY7eIA0kxTx7lCZkDxQzj7AgLbULNFhxxtx6ZBuPmL1Lz+vOTSlivi6Pxbc/DawuU2WFHvTXLRFinASUhISEhISEgQICgdhcC0WOQTEDebXAhXYfAHwx0G9xO4PUBRer0+nZgnsfDz8/NW/CgzN8ovqY5H2xRzW1o1X0JCQkJCQkLinQUEo4kQkvaJfALihut0utTkJ2W/Zothey+4H4Nqi+lfBdC2QyJPQkJCQkJCQkJCw4W1ESIvKUA53Ig9BK+rYpwCCIPcPBbS8LTuQOfsaPVP5EtISEhISEhIvNOAQGUzOK/VarOIhHjbubbEAPlyQUhrBgqGEFbRaDTmhfulmA5CWoPAwMBJSLcF8XvhrkTe6ko82hCoTi8hISEhISEhIaHhQtQaOEm2lPAq4O3tnQHtaifyJSQkJCQkJCQkVDAajZ8GBAR09/f3b2el9hCiOFn9HeB2NJvNnZCuM9xQUBcixIWAKBxKLuLJ3wNuNyLwulEY1B3+7lZez8DAQAp3pTJJYAP1Rx2v5YydhISEhISEhISEhMRrxv8BvmYgHI6YKi8AAAAASUVORK5CYII=>

[image2]: <data:image/png;base64,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>