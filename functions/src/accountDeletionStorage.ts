import { getStorage, type Storage } from "firebase-admin/storage"

export const accountDeletionStorageProvenanceVersion = "v2"
export const accountDeletionPublicImageObjectRole = "anonymousPublicRecipeImage"
export const accountDeletionPublicImageProvenanceMetadataKeys = [
  "accountDeletionProvenanceVersion",
  "accountDeletionObjectRole",
  "accountDeletionSourceProvenanceDigest",
  "accountDeletionSourceGeneration",
  "accountDeletionSourceContentHash",
] as const

export type AccountDeletionStoragePage = Readonly<{
  readonly fileNames: readonly string[]
  readonly nextPageToken?: string
  readonly fileGenerations?: Readonly<Record<string, string>>
}>

export type AccountDeletionStorageObjectMetadata = Readonly<{
  readonly generation: string
  readonly metageneration: string
  readonly contentHash?: string
  readonly customMetadata: Readonly<Record<string, string>>
}>

export type AccountDeletionStorageProvenance = Readonly<{
  readonly sourceProvenanceDigest: string
  readonly sourceGeneration: string
  readonly sourceContentHash?: string
  readonly provenanceVersion: string
  readonly objectRole: string
}>

export type AccountDeletionStorageCopy = Readonly<{
  readonly fileName: string
  readonly generation: string
}>

export type AccountDeletionOwnedStorageObject = Readonly<{
  readonly kind: "householdPantry" | "privateRecipe"
  readonly ownerId: string
  readonly fileName: string
}>

export type AccountDeletionStorage = Readonly<{
  readonly listFiles: (
    prefix: string,
    pageToken: string | undefined,
    limit: number,
  ) => Promise<AccountDeletionStoragePage>
  readonly deleteFiles: (
    fileNames: readonly string[],
    generations?: Readonly<Record<string, string>>,
  ) => Promise<void>
  readonly deleteOwnedObject: (
    object: AccountDeletionOwnedStorageObject,
    generation?: string,
  ) => Promise<void>
  readonly getObjectMetadata?: (
    fileName: string,
  ) => Promise<AccountDeletionStorageObjectMetadata | undefined>
  readonly replaceObjectMetadata?: (
    fileName: string,
    generation: string,
    metageneration: string,
    customMetadata: Readonly<Record<string, string>>,
  ) => Promise<void>
  readonly copyObject?: (
    sourceFileName: string,
    sourceGeneration: string,
    destinationFileName: string,
    provenance?: AccountDeletionStorageProvenance,
  ) => Promise<AccountDeletionStorageCopy>
  readonly deleteObject?: (fileName: string, generation: string) => Promise<void>
  readonly bucketName: string
}>

/** Production storage access is deliberately server-only and prefix bounded. */
export function accountDeletionStorage(storage: Storage = getStorage()): AccountDeletionStorage {
  const bucket = storage.bucket()
  return {
    bucketName: bucket.name,
    async listFiles(prefix, pageToken, limit) {
      const [files, nextQuery] = await bucket.getFiles({
        prefix,
        maxResults: limit,
        ...(pageToken === undefined ? {} : { pageToken }),
        autoPaginate: false,
      })
      return {
        fileNames: files.map((file) => file.name),
        fileGenerations: Object.fromEntries(
          files.flatMap((file) => {
            const generation = normalizeStorageGeneration(file.metadata.generation)
            return generation !== undefined ? [[file.name, generation]] : []
          }),
        ),
        ...(nextQuery?.pageToken === undefined ? {} : { nextPageToken: nextQuery.pageToken }),
      }
    },
    async deleteFiles(fileNames, generations) {
      await Promise.all(
        fileNames.map((fileName) => {
          const generation = generations?.[fileName]
          if (generation === undefined) {
            throw new Error("Account deletion Storage generation is missing")
          }
          validateGeneration(generation)
          return deleteIfPresent(bucket.file(fileName), generation)
        }),
      )
    },
    async deleteOwnedObject(object, generation) {
      validateOwnedStorageObject(object)
      if (generation === undefined) {
        throw new Error("Account deletion Storage generation is missing")
      }
      validateGeneration(generation)
      await deleteIfPresent(bucket.file(object.fileName), generation)
    },
    async getObjectMetadata(fileName) {
      const [metadata] = await getIfPresent(bucket.file(fileName))
      const generation = normalizeStorageGeneration(metadata?.generation)
      const metageneration = normalizeStorageGeneration(metadata?.metageneration)
      if (generation === undefined || metageneration === undefined) return undefined
      const customMetadata = readCustomMetadata(metadata?.metadata)
      return {
        generation,
        metageneration,
        ...(typeof metadata?.md5Hash === "string" ? { contentHash: metadata.md5Hash } : {}),
        customMetadata,
      }
    },
    async replaceObjectMetadata(fileName, generation, metageneration, customMetadata) {
      validateGeneration(generation)
      validateGeneration(metageneration)
      if (!isSafeStorageFileName(fileName) || !isValidCustomMetadata(customMetadata)) {
        throw new Error("Account deletion Storage metadata validation failed")
      }
      const file = bucket.file(fileName) as unknown as {
        setMetadata: (
          metadata: Readonly<{
            readonly metadata: Readonly<Record<string, string | null>>
          }>,
          options: Readonly<{
            readonly ifGenerationMatch: string
            readonly ifMetagenerationMatch: string
          }>,
        ) => Promise<unknown>
      }
      const [current] = await getIfPresent(bucket.file(fileName))
      if (
        current === undefined ||
        normalizeStorageGeneration(current.generation) !== generation ||
        normalizeStorageGeneration(current.metageneration) !== metageneration
      ) {
        throw new Error("Account deletion Storage metadata generation changed")
      }
      const currentCustomMetadata = readCustomMetadata(current.metadata)
      const metadataPatch: Record<string, string | null> = { ...customMetadata }
      for (const key of Object.keys(currentCustomMetadata)) {
        if (!(key in customMetadata)) metadataPatch[key] = null
      }
      await file.setMetadata(
        { metadata: metadataPatch },
        { ifGenerationMatch: generation, ifMetagenerationMatch: metageneration },
      )
    },
    async copyObject(sourceFileName, sourceGeneration, destinationFileName, provenance) {
      validateGeneration(sourceGeneration)
      if (!isSafeStorageFileName(sourceFileName) || !isSafeStorageFileName(destinationFileName)) {
        throw new Error("Account deletion Storage copy validation failed")
      }
      if (provenance !== undefined) {
        validateGeneration(provenance.sourceGeneration)
        if (
          provenance.sourceGeneration !== sourceGeneration ||
          provenance.provenanceVersion !== accountDeletionStorageProvenanceVersion ||
          provenance.objectRole !== accountDeletionPublicImageObjectRole ||
          !isSafeProvenanceDigest(provenance.sourceProvenanceDigest)
        ) {
          throw new Error("Account deletion Storage provenance validation failed")
        }
      }
      const copySource = bucket.file(sourceFileName, {
        generation: sourceGeneration,
      }) as unknown as {
        copy: (destination: unknown, options: unknown) => Promise<unknown>
      }
      await copySource.copy(bucket.file(destinationFileName), {
        preconditionOpts: { ifGenerationMatch: 0 },
        ...(provenance === undefined
          ? {}
          : {
              metadata: accountDeletionStorageProvenanceMetadata(provenance),
            }),
      })
      const [copied] = await getIfPresent(bucket.file(destinationFileName))
      const generation = normalizeStorageGeneration(copied?.generation)
      if (copied === undefined || generation === undefined) {
        throw new Error("Account deletion Storage copy generation is missing")
      }
      return { fileName: destinationFileName, generation }
    },
    async deleteObject(fileName, generation) {
      validateGeneration(generation)
      if (!isSafeStorageFileName(fileName)) {
        throw new Error("Account deletion Storage ownership validation failed")
      }
      await deleteIfPresent(bucket.file(fileName), generation)
    },
  }
}

export function storageFileNameForUrl(url: string, bucketName: string): string | undefined {
  if (url.startsWith("gs://")) {
    const separator = url.indexOf("/", "gs://".length)
    if (separator === -1 || url.slice("gs://".length, separator) !== bucketName) return undefined
    try {
      return decodeURIComponent(url.slice(separator + 1))
    } catch {
      return undefined
    }
  }
  try {
    const parsed = new URL(url)
    if (parsed.hostname !== "firebasestorage.googleapis.com") return undefined
    const pathParts = parsed.pathname.split("/")
    if (pathParts.length < 6 || pathParts[1] !== "v0" || pathParts[2] !== "b") return undefined
    if (pathParts[3] !== bucketName || pathParts[4] !== "o") return undefined
    return decodeURIComponent(pathParts.slice(5).join("/"))
  } catch {
    return undefined
  }
}

export function ownedStorageObjectForUrl(
  url: string,
  bucketName: string,
  kind: AccountDeletionOwnedStorageObject["kind"],
  ownerId: string,
  childId: string,
): AccountDeletionOwnedStorageObject | undefined {
  const fileName = storageFileNameForUrl(url, bucketName)
  if (fileName === undefined) return undefined
  const prefix =
    kind === "householdPantry" ? `households/${ownerId}/pantry/${childId}/` : `recipes/${ownerId}/`
  if (!fileName.startsWith(prefix) || fileName.length === prefix.length || fileName.includes(".."))
    return undefined
  return { kind, ownerId, fileName }
}

function validateOwnedStorageObject(object: AccountDeletionOwnedStorageObject): void {
  const expectedPrefix =
    object.kind === "householdPantry"
      ? `households/${object.ownerId}/pantry/`
      : `recipes/${object.ownerId}/`
  if (!object.fileName.startsWith(expectedPrefix) || object.fileName.includes("..")) {
    throw new Error("Account deletion Storage ownership validation failed")
  }
}

function validateGeneration(value: string): void {
  if (!/^\d+$/.test(value)) throw new Error("Account deletion Storage generation is invalid")
}

function isSafeStorageFileName(value: string): boolean {
  return value.length > 0 && !value.startsWith("/") && !value.includes("..")
}

type StorageCustomMetadata = Readonly<{
  readonly [key: string]: unknown
}>

type StorageMetadataRecord = Readonly<{
  readonly generation?: unknown
  readonly metageneration?: unknown
  readonly md5Hash?: unknown
  readonly metadata?: StorageCustomMetadata
}>

async function getIfPresent(file: {
  getMetadata: () => Promise<readonly [StorageMetadataRecord, unknown]>
}): Promise<readonly [StorageMetadataRecord, unknown] | [undefined]> {
  try {
    return await file.getMetadata()
  } catch (error) {
    if (isStorageNotFound(error)) return [undefined]
    throw error
  }
}

async function deleteIfPresent(
  file: { delete: (options?: Readonly<Record<string, unknown>>) => Promise<unknown> },
  generation?: string,
): Promise<void> {
  try {
    await file.delete(generation === undefined ? undefined : { ifGenerationMatch: generation })
  } catch (error) {
    if (!isStorageNotFound(error)) throw error
  }
}

function isStorageNotFound(error: unknown): boolean {
  return (
    typeof error === "object" &&
    error !== null &&
    "code" in error &&
    ((error as { readonly code?: unknown }).code === 404 ||
      (error as { readonly code?: unknown }).code === "storage/object-not-found")
  )
}

export function accountDeletionStorageProvenanceMetadata(
  provenance: AccountDeletionStorageProvenance,
): Record<string, string> {
  return {
    accountDeletionProvenanceVersion: provenance.provenanceVersion,
    accountDeletionObjectRole: provenance.objectRole,
    accountDeletionSourceProvenanceDigest: provenance.sourceProvenanceDigest,
    accountDeletionSourceGeneration: provenance.sourceGeneration,
    ...(provenance.sourceContentHash === undefined
      ? {}
      : { accountDeletionSourceContentHash: provenance.sourceContentHash }),
  }
}

function readCustomMetadata(metadata: StorageCustomMetadata | undefined): Record<string, string> {
  if (metadata === undefined) return {}
  if (!isValidCustomMetadata(metadata)) {
    throw new Error("Account deletion Storage custom metadata is invalid")
  }
  return Object.fromEntries(Object.entries(metadata).map(([key, value]) => [key, value as string]))
}

function isValidCustomMetadata(metadata: Readonly<Record<string, unknown>>): boolean {
  return Object.values(metadata).every((value) => typeof value === "string")
}

function normalizeStorageGeneration(value: unknown): string | undefined {
  if (typeof value === "string") return /^\d+$/.test(value) ? value : undefined
  if (typeof value === "bigint") return value >= 0n ? value.toString() : undefined
  return typeof value === "number" && Number.isSafeInteger(value) && value >= 0
    ? String(value)
    : undefined
}

function isSafeProvenanceDigest(value: unknown): value is string {
  return typeof value === "string" && /^[A-Za-z0-9_-]{43}$/.test(value)
}
