class UnexpectedVariantError extends Error {
  readonly name = "UnexpectedVariantError"

  constructor(readonly value: never) {
    super("Unexpected discriminated-union variant")
  }
}

export function assertNever(value: never): never {
  throw new UnexpectedVariantError(value)
}
