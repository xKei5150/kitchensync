import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { expect, test } from "vitest";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "../..");

test("development rule profiles do not weaken production authorization", () => {
  for (const [production, development] of [
    ["firestore.rules", "firestore.dev.rules"],
    ["storage.rules", "storage.dev.rules"],
  ] as const) {
    expect(readFileSync(resolve(root, development), "utf8")).toBe(
      readFileSync(resolve(root, production), "utf8"),
    );
  }
});
