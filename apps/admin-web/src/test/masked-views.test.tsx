import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { Household360View, User360View } from "../components/MaskedFields";
import { household360, user360 } from "./fixtures";

describe("masked diagnostic views", () => {
  it("renders masked identity and does not expose full user or household IDs", () => {
    render(<User360View user={user360} />);

    expect(screen.getByText("m***@example.test")).toBeVisible();
    expect(screen.queryByText("user-secret-987654")).not.toBeInTheDocument();
    expect(screen.queryByText("household-secret-123")).not.toBeInTheDocument();
    expect(screen.getAllByText("Indeterminate; no historical decision receipt is available").length).toBeGreaterThan(0);
  });

  it("keeps member identifiers masked and never renders invite values", () => {
    render(<Household360View household={household360} />);

    expect(screen.queryByText("member-ref-01")).not.toBeInTheDocument();
    expect(screen.getByText("No invitation token or token-derived identifier is included in this view.")).toBeVisible();
  });

  it("renders a bounded not-applicable entitlement state for an Auth identity without household context", () => {
    render(<User360View user={{ ...user360, entitlement: null }} />);
    expect(screen.getByText("No household entitlement can be evaluated for this account context.")).toBeVisible();
    expect(screen.getByText("not applicable")).toBeVisible();
  });
});
