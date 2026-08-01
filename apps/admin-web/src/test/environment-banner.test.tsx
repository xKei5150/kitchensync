import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { EnvironmentBanner } from "../components/EnvironmentBanner";
import { testConfig } from "./fixtures";

describe("EnvironmentBanner", () => {
  it("makes a production build unmistakable and shows build identity", () => {
    render(<EnvironmentBanner config={{ ...testConfig, environment: "production", projectId: "kitchensync-prod-8d6fd", expectedProjectId: "kitchensync-prod-8d6fd" }} />);

    expect(screen.getByLabelText("Build environment")).toHaveClass("environment-banner--production");
    expect(screen.getByText("Production")).toBeVisible();
    expect(screen.getByText("Live customer environment")).toBeVisible();
    expect(screen.getByText("kitchensync-prod-8d6fd")).toBeVisible();
    expect(screen.getByText("v1")).toBeVisible();
    expect(screen.getByText("0.1.0-test")).toBeVisible();
  });

  it("identifies a preview as non-production", () => {
    render(<EnvironmentBanner config={{ ...testConfig, environment: "preview" }} />);
    expect(screen.getByLabelText("Build environment")).toHaveClass("environment-banner--preview");
    expect(screen.getByText("Preview")).toBeVisible();
    expect(screen.getByText("Non-production environment")).toBeVisible();
  });
});
