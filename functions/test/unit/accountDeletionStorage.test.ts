import type { Storage } from "firebase-admin/storage"
import { describe, expect, it } from "vitest"
import {
  accountDeletionPublicImageObjectRole,
  accountDeletionStorage,
  accountDeletionStorageProvenanceMetadata,
  accountDeletionStorageProvenanceVersion,
  ownedStorageObjectForUrl,
  storageFileNameForUrl,
} from "../../src/accountDeletionStorage.js"

const provenanceDigest = "a".repeat(43)

describe("account deletion Storage ownership", () => {
  it("accepts only exact household-pantry and private-recipe ownership prefixes", () => {
    expect(
      ownedStorageObjectForUrl(
        "gs://kitchensync/households/h1/pantry/item-1/photo.jpg",
        "kitchensync",
        "householdPantry",
        "h1",
        "item-1",
      ),
    ).toEqual({
      kind: "householdPantry",
      ownerId: "h1",
      fileName: "households/h1/pantry/item-1/photo.jpg",
    })
    expect(
      ownedStorageObjectForUrl(
        "gs://kitchensync/households/h2/pantry/item-1/photo.jpg",
        "kitchensync",
        "householdPantry",
        "h1",
        "item-1",
      ),
    ).toBeUndefined()
    expect(
      ownedStorageObjectForUrl(
        "gs://kitchensync/recipes/recipe-1/photo.jpg",
        "kitchensync",
        "privateRecipe",
        "recipe-2",
        "recipe-2",
      ),
    ).toBeUndefined()
    expect(storageFileNameForUrl("https://example.com/foreign.jpg", "kitchensync")).toBeUndefined()
  })

  it("treats object-not-found as an idempotent deletion success", async () => {
    const storage = accountDeletionStorage({
      bucket: () => ({
        name: "kitchensync",
        getFiles: async () => [[], undefined],
        file: () => ({
          delete: async () => {
            const error = Object.assign(new Error("missing"), { code: 404 })
            throw error
          },
        }),
      }),
    } as unknown as Storage)

    await expect(
      storage.deleteFiles(["households/h1/pantry/item-1/photo.jpg"], {
        "households/h1/pantry/item-1/photo.jpg": "1",
      }),
    ).resolves.toBeUndefined()
    await expect(
      storage.deleteOwnedObject(
        {
          kind: "privateRecipe",
          ownerId: "recipe-1",
          fileName: "recipes/recipe-1/photo.jpg",
        },
        "1",
      ),
    ).resolves.toBeUndefined()
    await expect(
      storage.deleteOwnedObject({
        kind: "privateRecipe",
        ownerId: "recipe-1",
        fileName: "recipes/other-recipe/photo.jpg",
      }),
    ).rejects.toThrow("ownership validation")
  })

  it("copies only the inspected source generation and records destination provenance", async () => {
    let copyOptions: Record<string, unknown> | undefined
    let physicalDestinationRead = false
    const storage = accountDeletionStorage({
      bucket: () => ({
        name: "kitchensync",
        file: () => ({
          copy: async (_destination: unknown, options: Record<string, unknown>) => {
            copyOptions = options
            return [{ generation: "wrong-copy-result" }, {}]
          },
          getMetadata: async () => {
            physicalDestinationRead = true
            return [{ generation: 2, metageneration: 1, metadata: {} }, {}]
          },
        }),
      }),
    } as unknown as Storage)

    await expect(
      storage.copyObject?.("recipes/user/recipe/image.jpg", "7", "anonymous-public/recipes/x", {
        sourceProvenanceDigest: provenanceDigest,
        sourceGeneration: "7",
        sourceContentHash: "hash",
        provenanceVersion: accountDeletionStorageProvenanceVersion,
        objectRole: accountDeletionPublicImageObjectRole,
      }),
    ).resolves.toEqual({ fileName: "anonymous-public/recipes/x", generation: "2" })
    expect(physicalDestinationRead).toBe(true)
    expect(copyOptions).toMatchObject({
      preconditionOpts: { ifGenerationMatch: 0 },
      metadata: {
        accountDeletionProvenanceVersion: accountDeletionStorageProvenanceVersion,
        accountDeletionObjectRole: accountDeletionPublicImageObjectRole,
        accountDeletionSourceProvenanceDigest: provenanceDigest,
        accountDeletionSourceGeneration: "7",
        accountDeletionSourceContentHash: "hash",
      },
    })
    expect(JSON.stringify(copyOptions)).not.toContain("recipes/user/recipe/image.jpg")
    expect(JSON.stringify(copyOptions)).not.toContain("accountDeletionSourceFileName")
  })

  it("normalizes only safe SDK generation values", async () => {
    const storage = accountDeletionStorage({
      bucket: () => ({
        name: "kitchensync",
        file: () => ({
          getMetadata: async () => [{ generation: 9007199254740992, metageneration: 3 }, {}],
        }),
      }),
    } as unknown as Storage)

    await expect(storage.getObjectMetadata?.("anonymous-public/recipes/destination")).resolves.toBe(
      undefined,
    )
  })

  it("returns the complete physical custom metadata map without projection", async () => {
    const physicalMetadata = {
      accountDeletionSourceFileName: "recipes/user/recipe/image.jpg",
      accountDeletionProvenanceVersion: accountDeletionStorageProvenanceVersion,
      accountDeletionObjectRole: accountDeletionPublicImageObjectRole,
      accountDeletionSourceProvenanceDigest: provenanceDigest,
      accountDeletionSourceGeneration: "7",
      accountDeletionSourceContentHash: "hash",
      unexpectedProvenance: "legacy",
    }
    const storage = accountDeletionStorage({
      bucket: () => ({
        name: "kitchensync",
        file: () => ({
          getMetadata: async () => [
            {
              generation: "2",
              metageneration: "3",
              metadata: physicalMetadata,
            },
            {},
          ],
        }),
      }),
    } as unknown as Storage)

    const metadata = await storage.getObjectMetadata?.("anonymous-public/recipes/destination")
    expect(metadata).toEqual({
      generation: "2",
      metageneration: "3",
      customMetadata: physicalMetadata,
    })
  })

  it("replaces the complete physical custom metadata map with generation fences", async () => {
    let replacement: { metadata: unknown; options: unknown } | undefined
    const physicalMetadata: Record<string, string> = {
      accountDeletionSourceFileName: "recipes/user/recipe/image.jpg",
      unexpectedProvenance: "legacy",
    }
    const storage = accountDeletionStorage({
      bucket: () => ({
        name: "kitchensync",
        file: () => ({
          getMetadata: async () => [
            { generation: "2", metageneration: "3", metadata: physicalMetadata },
            {},
          ],
          setMetadata: async (
            metadata: { metadata: Record<string, string | null> },
            options: unknown,
          ) => {
            replacement = { metadata, options }
            for (const [key, value] of Object.entries(metadata.metadata)) {
              if (value === null) delete physicalMetadata[key]
              else physicalMetadata[key] = value
            }
          },
        }),
      }),
    } as unknown as Storage)

    const expected = accountDeletionStorageProvenanceMetadata({
      sourceProvenanceDigest: provenanceDigest,
      sourceGeneration: "7",
      sourceContentHash: "hash",
      provenanceVersion: accountDeletionStorageProvenanceVersion,
      objectRole: accountDeletionPublicImageObjectRole,
    })
    await expect(
      storage.replaceObjectMetadata?.("anonymous-public/recipes/destination", "2", "3", expected),
    ).resolves.toBeUndefined()
    expect(replacement).toEqual({
      metadata: {
        metadata: {
          ...expected,
          accountDeletionSourceFileName: null,
          unexpectedProvenance: null,
        },
      },
      options: { ifGenerationMatch: "2", ifMetagenerationMatch: "3" },
    })
    expect(JSON.stringify(replacement)).not.toContain("recipes/user/recipe/image.jpg")
    expect(physicalMetadata).toEqual(expected)
    expect(JSON.stringify(physicalMetadata)).not.toContain("recipes/user/recipe/image.jpg")
  })
})
