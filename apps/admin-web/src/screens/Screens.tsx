import { useCallback, useState, type ReactNode } from "react";
import { ArrowRight, RefreshCw, Search } from "lucide-react";
import type { AdminApi, SupportCaseContext } from "../api/callable";
import { isExactIdentifier, toSafeError, type CallableEnvelope, type SafeErrorInfo } from "../api/dtos";
import { useStaffAccess } from "../auth/staffAccess";
import { CaseContextForm } from "../components/CaseContextForm";
import { EntitlementSummary, Household360View, User360View } from "../components/MaskedFields";
import { SafeErrorNotice } from "../components/SafeErrorNotice";
import { StatusPill } from "../components/StatusPill";
import { AppLink } from "../routing/browserRouter";
import { useBrowserRouter } from "../routing/routerContext";

interface ScreenProps {
  readonly api: AdminApi;
}

type RequestState<T> =
  | { readonly state: "idle" }
  | { readonly state: "loading" }
  | { readonly state: "success"; readonly response: CallableEnvelope<T> }
  | { readonly state: "error"; readonly error: SafeErrorInfo };

function useRequest<T>(request: (context: SupportCaseContext) => Promise<CallableEnvelope<T>>) {
  const [state, setState] = useState<RequestState<T>>({ state: "idle" });
  const run = useCallback(async (context: SupportCaseContext) => {
    setState({ state: "loading" });
    try {
      setState({ state: "success", response: await request(context) });
    } catch (error) {
      setState({ state: "error", error: toSafeError(error) });
    }
  }, [request]);
  return [state, run] as const;
}

function ScreenHeader({ eyebrow, title, children }: { readonly eyebrow: string; readonly title: string; readonly children: ReactNode }) {
  return (
    <header className="screen-header">
      <p className="eyebrow">{eyebrow}</p>
      <h1>{title}</h1>
      <p>{children}</p>
    </header>
  );
}

function ResultReference({ requestId }: { readonly requestId: string }) {
  return <p className="result-reference">Read request <code>{requestId}</code></p>;
}

function ExactLookup({ kind, value, onSubmit }: { readonly kind: "UID" | "household ID"; readonly value: string; readonly onSubmit: (value: string) => void }) {
  const [input, setInput] = useState(value);
  const [invalid, setInvalid] = useState(false);
  return (
    <form className="lookup-form" onSubmit={(event) => {
      event.preventDefault();
      const candidate = input.trim();
      if (!isExactIdentifier(candidate)) {
        setInvalid(true);
        return;
      }
      setInvalid(false);
      onSubmit(candidate);
    }} noValidate>
      <label>
        <span>Exact {kind}</span>
        <input value={input} onChange={(event) => setInput(event.target.value)} autoComplete="off" aria-invalid={invalid} aria-describedby={invalid ? "lookup-error" : undefined} required />
      </label>
      <button className="button" type="submit"><Search aria-hidden="true" /> Find</button>
      {invalid ? <p className="form-error" id="lookup-error">Use a single path-safe identifier.</p> : null}
    </form>
  );
}

export function HealthScreen() {
  const { health, retryStaffCheck } = useStaffAccess();
  const switchesDisabled = Object.values(health.data.mutationSwitches).every((state) => state === false);
  return (
    <section className="screen screen--health">
      <ScreenHeader eyebrow="Control plane" title="Service health">Authoritative service indicators from the verified staff gate. Secrets and raw IAM policy are never displayed here.</ScreenHeader>
      <div className="health-overview">
        <div className="health-overview__state">
          <span className="pulse-dot" aria-hidden="true" />
          <div><span>Staff gate</span><strong>Verified</strong></div>
        </div>
        <dl>
          <div><dt>Checked</dt><dd>{new Date(health.data.generatedAt).toLocaleString()}</dd></div>
          <div><dt>Project</dt><dd><code>{health.data.projectId}</code></dd></div>
          <div><dt>API contract</dt><dd><code>{health.data.apiVersion}</code></dd></div>
          <div><dt>Policy</dt><dd><code>{health.data.policyVersion}</code></dd></div>
        </dl>
        <button className="button button--secondary" type="button" onClick={retryStaffCheck}><RefreshCw aria-hidden="true" /> Recheck</button>
      </div>
      <section className="content-card" aria-labelledby="service-status-heading">
        <div className="section-heading"><div><p className="eyebrow">Bounded indicators</p><h2 id="service-status-heading">Service status</h2></div></div>
        <table className="service-table">
          <thead><tr><th scope="col">Service</th><th scope="col">Status</th><th scope="col">Last check</th></tr></thead>
          <tbody>{health.data.services.map((service) => (
            <tr key={service.name}>
              <th scope="row">{service.name}</th>
              <td><StatusPill state={service.status} /></td>
              <td>{service.checkedAt ? new Date(service.checkedAt).toLocaleString() : "Not reported"}</td>
            </tr>
          ))}</tbody>
        </table>
        <p className="queue-note">Mutation switches: <StatusPill state={switchesDisabled ? "disabled" : "unavailable"} /> {switchesDisabled ? "All customer-state mutation classes are disabled." : "Mutation switch evidence is unavailable."}</p>
      </section>
      <aside className="boundary-note"><strong>Read-only boundary.</strong> A healthy indicator is not an authorization grant for any future mutation.</aside>
    </section>
  );
}

export function UserLookupScreen() {
  const { navigate } = useBrowserRouter();
  return (
    <section className="screen">
      <ScreenHeader eyebrow="Support lookup" title="User 360">Open a masked, exact-UID profile view. No broad account search is available in this console.</ScreenHeader>
      <section className="content-card lookup-card">
        <ExactLookup kind="UID" value="" onSubmit={(uid) => navigate({ kind: "user-360", uid })} />
        <p className="quiet-note">A support case is required before any customer record is requested.</p>
      </section>
    </section>
  );
}

export function User360Screen({ api, uid }: ScreenProps & { readonly uid: string }) {
  const valid = isExactIdentifier(uid);
  const request = useCallback((context: SupportCaseContext) => api.getUser360(uid, context), [api, uid]);
  const [state, run] = useRequest(request);
  if (!valid) return <NotFoundScreen />;
  return (
    <section className="screen">
      <ScreenHeader eyebrow="Support lookup" title="User 360">This screen requests only the fixed, backend-masked summary for the exact UID in this route.</ScreenHeader>
      <section className="content-card context-card">
        <CaseContextForm submitLabel="Load masked profile" isSubmitting={state.state === "loading"} onSubmit={run} />
        <p className="quiet-note">Sensitive values remain masked. This read is annotated as a support case; case text does not change authorization.</p>
      </section>
      {state.state === "error" ? <SafeErrorNotice error={state.error} /> : null}
      {state.state === "success" ? <section className="content-card result-card"><User360View user={state.response.data} /><ResultReference requestId={state.response.requestId} /></section> : null}
    </section>
  );
}

export function HouseholdLookupScreen() {
  const { navigate } = useBrowserRouter();
  return (
    <section className="screen">
      <ScreenHeader eyebrow="Topology lookup" title="Household 360">Inspect bounded household topology, safe invite diagnostics, and module counts with an exact household ID.</ScreenHeader>
      <section className="content-card lookup-card">
        <ExactLookup kind="household ID" value="" onSubmit={(householdId) => navigate({ kind: "household-360", householdId })} />
        <p className="quiet-note">Invite values are never accepted, displayed, or inferred by this console.</p>
      </section>
    </section>
  );
}

export function Household360Screen({ api, householdId }: ScreenProps & { readonly householdId: string }) {
  const valid = isExactIdentifier(householdId);
  const request = useCallback((context: SupportCaseContext) => api.getHousehold360(householdId, context), [api, householdId]);
  const [state, run] = useRequest(request);
  if (!valid) return <NotFoundScreen />;
  return (
    <section className="screen">
      <ScreenHeader eyebrow="Topology lookup" title="Household 360">This exact household view is a bounded summary, not a document export or cross-household history query.</ScreenHeader>
      <section className="content-card context-card"><CaseContextForm submitLabel="Load household summary" isSubmitting={state.state === "loading"} onSubmit={run} /></section>
      {state.state === "error" ? <SafeErrorNotice error={state.error} /> : null}
      {state.state === "success" ? <section className="content-card result-card"><Household360View household={state.response.data} /><ResultReference requestId={state.response.requestId} /></section> : null}
    </section>
  );
}

export function EntitlementLookupScreen() {
  const { navigate } = useBrowserRouter();
  return (
    <section className="screen">
      <ScreenHeader eyebrow="Read-only evaluator" title="Entitlement diagnostics">Review a versioned entitlement result for an exact household. This console does not edit billing or entitlement inputs.</ScreenHeader>
      <section className="content-card lookup-card"><ExactLookup kind="household ID" value="" onSubmit={(householdId) => navigate({ kind: "entitlement", householdId })} /></section>
    </section>
  );
}

export function EntitlementScreen({ api, householdId }: ScreenProps & { readonly householdId: string }) {
  const valid = isExactIdentifier(householdId);
  const request = useCallback((context: SupportCaseContext) => api.getEntitlementDiagnostics(householdId, context), [api, householdId]);
  const [state, run] = useRequest(request);
  if (!valid) return <NotFoundScreen />;
  return (
    <section className="screen">
      <ScreenHeader eyebrow="Read-only evaluator" title="Entitlement diagnostics">Raw stored inputs are not treated as billing truth. Missing evidence stays visible as a bounded diagnostic, never a browser-side guess.</ScreenHeader>
      <section className="content-card context-card"><CaseContextForm submitLabel="Evaluate entitlement" isSubmitting={state.state === "loading"} onSubmit={run} /></section>
      {state.state === "error" ? <SafeErrorNotice error={state.error} /> : null}
      {state.state === "success" ? <section className="content-card result-card"><EntitlementSummary entitlement={state.response.data} /><ResultReference requestId={state.response.requestId} /></section> : null}
    </section>
  );
}

export function NotFoundScreen() {
  return (
    <section className="screen safe-page">
      <p className="eyebrow">Route unavailable</p>
      <h1>This console view is unavailable.</h1>
      <p>The address is not a supported administration route, or its identifier is not valid for this console.</p>
      <AppLink className="button" to={{ kind: "health" }}>Return to health <ArrowRight aria-hidden="true" /></AppLink>
    </section>
  );
}
