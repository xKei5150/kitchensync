import { describe, expect, it } from "vitest"
import { plannerForEnvironment } from "../../src/index.js"
import { ControlledEmulatorAllocationPlannerClient } from "../../src/shopping/controlledEmulatorPlanner.js"
import { PlannerConfigurationError } from "../../src/shopping/plannerClient.js"

describe("controlled emulator allocation planner", () => {
  it("derives a scheduled draft from only the typed intent", async () => {
    // Given: a server-controlled planner and a typed scheduled occurrence.
    const planner = new ControlledEmulatorAllocationPlannerClient()

    // When: the callable asks the private planning seam for a draft.
    const draft = await planner.plan({
      householdId: "household",
      intent: {
        kind: "scheduled",
        scheduleKey: "weekly-6-2026-07-12",
        occurrenceDate: "2026-07-18",
        startDate: "2026-07-12",
        endDate: "2026-07-18",
      },
    })

    // Then: its server-owned identifiers, range, origin, and source link are deterministic.
    expect(draft).toMatchObject({
      householdId: "household",
      listId: "scheduled_weekly_20260718",
      intent: expect.objectContaining({ kind: "scheduled" }),
      list: expect.objectContaining({
        type: "scheduled",
        shoppingDate: "2026-07-18",
        generatedForRangeStart: "2026-07-12",
        generatedForRangeEnd: "2026-07-18",
        originId: "weekly-6-2026-07-12",
        items: [
          expect.objectContaining({
            itemId: "server-tomato-piece",
            sourceMealLinks: [
              {
                mealEntryId: "server-meal-20260718",
                recipeId: "server-recipe-20260718",
                date: "2026-07-18",
                quantity: 2,
              },
            ],
          }),
        ],
      }),
    })
  })

  it("uses the recovery reconciliation identity for the core suggested window", async () => {
    // Given: the core recovery suggestion for a deterministic window.
    const planner = new ControlledEmulatorAllocationPlannerClient()

    // When: its typed recovery intent is planned.
    const draft = await planner.plan({
      householdId: "household",
      intent: {
        kind: "suggested",
        originId: "recovery:core:v1",
        windowStart: "2026-07-13",
        windowEnd: "2026-07-19",
        startDate: "2026-07-13",
        endDate: "2026-07-19",
      },
    })

    // Then: the produced list can be found and updated by the reconciler.
    expect(draft.listId).toBe("suggested_recovery_20260713_20260719")
    expect(draft.list.originId).toBe("recovery:core:v1")
  })

  it("derives an emergency list from typed demands without client source links", async () => {
    // Given: an emergency requirement containing only a safe demand.
    const planner = new ControlledEmulatorAllocationPlannerClient()

    // When: the demand crosses the allocation boundary.
    const draft = await planner.plan({
      householdId: "household",
      intent: {
        kind: "emergency",
        startDate: "2026-07-13",
        endDate: "2026-07-13",
        demands: [{ ingredientId: "tomato", quantityNeeded: 300, unit: "g" }],
      },
    })

    // Then: the server-derived list preserves the emergency type and demand only.
    expect(draft.list).toMatchObject({
      type: "emergency",
      items: [
        {
          itemId: "tomato__g",
          ingredientId: "tomato",
          quantityNeeded: 300,
          unit: "g",
          sourceMealLinks: [],
        },
      ],
    })
  })

  it("rejects the controlled planner outside the Functions emulator", () => {
    // Given: a production-like process that attempts to request the controlled planner.
    const environment: NodeJS.ProcessEnv = {
      USE_CONTROLLED_EMULATOR_PLANNER: "true",
      GCLOUD_PROJECT: "kitchensync-dev-da503",
    }

    // When: planner selection runs without the Firebase Functions emulator signal.
    const selectPlanner = () => plannerForEnvironment(environment)

    // Then: production remains fail-closed on the private planner configuration.
    expect(selectPlanner).toThrow(PlannerConfigurationError)
  })

  it("uses the controlled planner by default in the Functions emulator", () => {
    // Given: a standard local Functions emulator process without private
    // Cloud Run planner credentials.
    const environment: NodeJS.ProcessEnv = {
      FUNCTIONS_EMULATOR: "true",
      GCLOUD_PROJECT: "kitchensync-dev-da503",
    }

    // When: the callable selects its planner.
    const planner = plannerForEnvironment(environment)

    // Then: local product flows remain deterministic and self-contained.
    expect(planner).toBeInstanceOf(ControlledEmulatorAllocationPlannerClient)
  })

  it("rejects local planner mode outside the Functions emulator", () => {
    // Given: a deployed process with the local-planner flag set.
    const environment: NodeJS.ProcessEnv = {
      LOCAL_PLANNER_INTEGRATION_TEST: "true",
      LOCAL_PLANNER_URL: "http://127.0.0.1:18080",
      LOCAL_PLANNER_AUDIENCE: "local",
      LOCAL_PLANNER_OIDC_TOKEN: "token",
    }

    // When: the application selects its allocation planner.
    const selectPlanner = () => plannerForEnvironment(environment)

    // Then: static local identity cannot be enabled in a deployed process.
    expect(selectPlanner).toThrow(PlannerConfigurationError)
  })

  it("rejects a non-loopback local planner endpoint", () => {
    // Given: an emulator with a non-local HTTP planner endpoint.
    const environment: NodeJS.ProcessEnv = {
      FUNCTIONS_EMULATOR: "true",
      LOCAL_PLANNER_INTEGRATION_TEST: "true",
      LOCAL_PLANNER_URL: "http://planner.example.test:18080",
      LOCAL_PLANNER_AUDIENCE: "local",
      LOCAL_PLANNER_OIDC_TOKEN: "token",
    }

    // When: local planner selection validates its endpoint.
    const selectPlanner = () => plannerForEnvironment(environment)

    // Then: the local static token remains loopback-only.
    expect(selectPlanner).toThrow(PlannerConfigurationError)
  })
})
