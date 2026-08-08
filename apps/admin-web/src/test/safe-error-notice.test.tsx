import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { toSafeError } from "../api/dtos";
import { SafeErrorNotice } from "../components/SafeErrorNotice";

describe("safe error handling", () => {
  it("does not render a backend exception or unsafe message", () => {
    const error = toSafeError(new Error("database password leaked: pretend-secret"));
    render(<SafeErrorNotice error={error} onRetry={() => undefined} />);

    expect(screen.getByRole("alert")).toHaveTextContent("The requested information is currently unavailable.");
    expect(screen.queryByText(/pretend-secret/i)).not.toBeInTheDocument();
    expect(screen.getByText("Request ID unavailable")).toBeVisible();
  });

  it("renders only a validated server request ID", () => {
    const error = toSafeError({ details: { appCode: "dependency_unavailable", requestId: "srv_request_12345", retryAfterMs: 3000 } });
    render(<SafeErrorNotice error={error} onRetry={() => undefined} />);
    expect(screen.getByText("srv_request_12345")).toBeVisible();
    expect(screen.getByRole("button", { name: "Try again" })).toBeVisible();
  });
});
