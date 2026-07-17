export type EmulatorEndpoint = {
  readonly host: string
  readonly port: number
}

export function authEmulatorUrl(): string {
  const endpoint = emulatorEndpoint(
    ["AUTH_EMULATOR_HOST", "FIREBASE_AUTH_EMULATOR_HOST"],
    "127.0.0.1:9099",
  )
  return `http://${endpoint.host}:${endpoint.port}`
}

export function functionsEmulatorEndpoint(): EmulatorEndpoint {
  return emulatorEndpoint(
    ["FUNCTIONS_EMULATOR_HOST", "FIREBASE_FUNCTIONS_EMULATOR_HOST"],
    "127.0.0.1:5001",
  )
}

function emulatorEndpoint(envKeys: readonly string[], fallback: string): EmulatorEndpoint {
  const configured = envKeys
    .map((key) => process.env[key])
    .find((value) => value !== undefined && value.trim().length > 0)
  return parseEndpoint(configured ?? fallback)
}

function parseEndpoint(rawEndpoint: string): EmulatorEndpoint {
  const endpointUrl = new URL(rawEndpoint.includes("://") ? rawEndpoint : `http://${rawEndpoint}`)
  const port = Number.parseInt(endpointUrl.port, 10)
  if (!Number.isInteger(port) || port <= 0) {
    throw new Error(`Invalid emulator endpoint port: ${rawEndpoint}`)
  }
  return { host: endpointUrl.hostname, port }
}
