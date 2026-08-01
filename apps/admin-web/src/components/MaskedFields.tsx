import type { EntitlementDto, HistoryEvidence, Household360Dto, User360Dto } from "../api/dtos";
import { StatusPill } from "./StatusPill";

function maskIdentifier(value: string): string {
  if (value.length <= 5) return "*****";
  return `${value.slice(0, 3)}***${value.slice(-2)}`;
}

function formatTime(value: string | null): string {
  if (!value) return "Not available";
  const date = new Date(value);
  return Number.isNaN(date.valueOf()) ? "Not available" : date.toLocaleString();
}

function evidenceLabel(code: EntitlementDto["evidenceCodes"][number]): string {
  const labels: Record<EntitlementDto["evidenceCodes"][number], string> = {
    household_subscription: "Household subscription record considered",
    trial_end_after_now: "Trial timing was evaluated by the trusted service",
    profile_household_alignment: "Profile and household alignment was evaluated",
    missing_required_field: "Required entitlement evidence was unavailable",
    unsupported_paid_state: "Paid-state evidence cannot be reconciled",
    clock_unavailable: "Trusted evaluation clock was unavailable",
  };
  return labels[code];
}

export function HistoryBoundary({ label, evidence }: { readonly label: string; readonly evidence: HistoryEvidence }) {
  const text = evidence.state === "evidenced"
    ? `${evidence.receiptCount} decision receipt${evidence.receiptCount === 1 ? "" : "s"} available`
    : evidence.state === "current_state_heuristic"
      ? "Current state only; it does not establish historical outcome"
      : "Indeterminate; no historical decision receipt is available";
  return (
    <div className="history-boundary">
      <div>
        <p className="detail-label">{label}</p>
        <p>{text}</p>
      </div>
      <StatusPill state={evidence.state} />
    </div>
  );
}

export function EntitlementSummary({ entitlement }: { readonly entitlement: EntitlementDto | null }) {
  if (entitlement === null) {
    return (
      <section className="detail-section" aria-labelledby="entitlement-heading">
        <div className="section-heading">
          <div>
            <p className="eyebrow">Computed result</p>
            <h2 id="entitlement-heading">Entitlement</h2>
          </div>
          <StatusPill state="not_applicable" />
        </div>
        <p className="muted-copy">No household entitlement can be evaluated for this account context.</p>
      </section>
    );
  }
  return (
    <section className="detail-section" aria-labelledby="entitlement-heading">
      <div className="section-heading">
        <div>
          <p className="eyebrow">Computed result</p>
          <h2 id="entitlement-heading">Entitlement</h2>
        </div>
        <span className="version-mark">Rules {entitlement.ruleVersion}</span>
      </div>
      <dl className="detail-grid">
        <div>
          <dt>Production access</dt>
          <dd><StatusPill state={entitlement.productionAccess.state} /></dd>
        </div>
        <div>
          <dt>Billing consistency</dt>
          <dd><StatusPill state={entitlement.billingConsistency.state} /></dd>
        </div>
        <div>
          <dt>Operation</dt>
          <dd><code>{entitlement.productionAccess.operation}</code></dd>
        </div>
        <div>
          <dt>Evaluated</dt>
          <dd>{formatTime(entitlement.evaluatedAt)}</dd>
        </div>
      </dl>
      <ul className="evidence-list" aria-label="Entitlement evidence">
        {entitlement.evidenceCodes.map((code) => <li key={code}>{evidenceLabel(code)}</li>)}
      </ul>
      <div className="history-grid">
        <HistoryBoundary label="Notification history" evidence={entitlement.history.notifications} />
        <HistoryBoundary label="Planner history" evidence={entitlement.history.planner} />
      </div>
    </section>
  );
}

export function User360View({ user }: { readonly user: User360Dto }) {
  return (
    <div className="data-view" aria-label="Masked User 360 result">
      <section className="detail-section" aria-labelledby="identity-heading">
        <div className="section-heading">
          <div>
            <p className="eyebrow">Masked account view</p>
            <h2 id="identity-heading">Identity</h2>
          </div>
          <StatusPill state={user.identity.disabled ? "denied" : "allowed"} />
        </div>
        <dl className="detail-grid">
          <div><dt>User ID</dt><dd><code>{maskIdentifier(user.identity.uid)}</code></dd></div>
          <div><dt>Email</dt><dd>{user.identity.email ?? "Not available"}</dd></div>
          <div><dt>Email verified</dt><dd>{user.identity.emailVerified ? "Verified" : "Not verified"}</dd></div>
          <div><dt>Account state</dt><dd>{user.identity.disabled ? "Disabled" : "Enabled"}</dd></div>
          <div><dt>Created</dt><dd>{formatTime(user.identity.createdAt)}</dd></div>
          <div><dt>Last sign-in</dt><dd>{formatTime(user.identity.lastSignInAt)}</dd></div>
        </dl>
      </section>
      <section className="detail-section" aria-labelledby="context-heading">
        <div className="section-heading">
          <div><p className="eyebrow">Scoped summary</p><h2 id="context-heading">Household context</h2></div>
          <StatusPill state={user.context.contextConsistency} />
        </div>
        <dl className="detail-grid">
          <div><dt>Active household</dt><dd><code>{user.context.activeHouseholdId ? maskIdentifier(user.context.activeHouseholdId) : "Not available"}</code></dd></div>
          <div><dt>Known households</dt><dd>{user.context.householdIds.length}</dd></div>
          <div><dt>Sign-in providers</dt><dd>{user.identity.providers.join(", ") || "Not available"}</dd></div>
        </dl>
        <HistoryBoundary label="Notification history" evidence={user.notifications} />
      </section>
      <EntitlementSummary entitlement={user.entitlement} />
    </div>
  );
}

export function Household360View({ household }: { readonly household: Household360Dto }) {
  return (
    <div className="data-view" aria-label="Masked Household 360 result">
      <section className="detail-section" aria-labelledby="household-heading">
        <div className="section-heading">
          <div><p className="eyebrow">Masked household view</p><h2 id="household-heading">Household topology</h2></div>
          <StatusPill state={household.topology} />
        </div>
        <dl className="detail-grid">
          <div><dt>Household</dt><dd>{household.household.label}</dd></div>
          <div><dt>Type</dt><dd>{household.household.isJoint ? "Joint" : "Solo"}</dd></div>
          <div><dt>Members</dt><dd>{household.capacity.memberCount} of {household.capacity.maxMembers}</dd></div>
          <div><dt>Admins</dt><dd>{household.adminCount}</dd></div>
          <div><dt>Capacity</dt><dd><StatusPill state={household.capacity.state} /></dd></div>
          <div><dt>Created</dt><dd>{formatTime(household.household.createdAt)}</dd></div>
        </dl>
        <div className="member-list" aria-label="Masked household members">
          {household.members.map((member) => (
            <div className="member-row" key={member.memberRef}>
              <code>{maskIdentifier(member.memberRef)}</code>
              <StatusPill state={member.role} />
              <span>{formatTime(member.joinedAt)}</span>
            </div>
          ))}
        </div>
      </section>
      <section className="detail-section" aria-labelledby="modules-heading">
        <div className="section-heading"><div><p className="eyebrow">Bounded counts</p><h2 id="modules-heading">Module summaries</h2></div></div>
        <div className="module-grid">
          {household.moduleSummaries.map((summary) => (
            <div className="module-summary" key={summary.module}>
              <span>{summary.module}</span>
              <strong>{summary.count}</strong>
              <StatusPill state={summary.schemaState} />
            </div>
          ))}
        </div>
      </section>
      <section className="detail-section" aria-labelledby="invite-heading">
        <div className="section-heading"><div><p className="eyebrow">Safe diagnostic</p><h2 id="invite-heading">Invite remediation</h2></div><StatusPill state={household.inviteDiagnostics.legacyRemediationState} /></div>
        <p className="muted-copy">No invitation token or token-derived identifier is included in this view.</p>
      </section>
      <EntitlementSummary entitlement={household.entitlement} />
    </div>
  );
}
