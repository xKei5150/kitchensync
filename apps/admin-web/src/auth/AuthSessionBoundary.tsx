import { useCallback, useEffect, useRef, useState, type FormEvent, type ReactNode } from "react";
import type { AdminApi } from "../api/callable";
import type { CallableEnvelope, HealthDto } from "../api/dtos";
import type { RuntimeConfig } from "../config/runtime";
import type { PhoneMfaFactor, SessionGateway, SessionUser } from "./session";
import { StaffAccessContext, type StaffAccess } from "./staffAccess";

interface AuthSessionBoundaryProps {
  readonly config: RuntimeConfig;
  readonly session: SessionGateway | null;
  readonly api: AdminApi | null;
  readonly children: ReactNode;
}

type GateState =
  | { readonly state: "checking" }
  | { readonly state: "signed-out" }
  | { readonly state: "denied" }
  | { readonly state: "configuration" }
  | { readonly state: "allowed"; readonly user: SessionUser; readonly health: CallableEnvelope<HealthDto> };

export const HEALTH_REVALIDATION_INTERVAL_MS = 240_000;

function isAuthorizedStaff(user: SessionUser, health: CallableEnvelope<HealthDto>, config: RuntimeConfig): boolean {
  return health.data.staff.uid === user.uid
    && health.data.staff.enabled
    && health.data.staff.environment === config.environment
    && health.data.projectId === config.projectId
    && health.data.apiVersion === config.apiVersion
    && health.data.staff.capabilities.includes("health.read");
}

export function AuthSessionBoundary({ config, session, api, children }: AuthSessionBoundaryProps) {
  const [gate, setGate] = useState<GateState>({ state: "checking" });
  const currentUser = useRef<SessionUser | null>(null);
  const authGeneration = useRef(0);
  const inFlightHealthCheck = useRef<{ readonly generation: number; readonly uid: string } | null>(null);
  const deniedGeneration = useRef<number | null>(null);
  const mounted = useRef(true);

  const commitGate = useCallback((next: GateState): void => {
    if (mounted.current) setGate(next);
  }, []);

  const invalidateSession = useCallback((): void => {
    authGeneration.current += 1;
    currentUser.current = null;
    inFlightHealthCheck.current = null;
    deniedGeneration.current = null;
    commitGate({ state: "signed-out" });
  }, [commitGate]);

  const revalidateHealth = useCallback((): void => {
    if (config.configurationError || !session || !api) return;
    const user = currentUser.current;
    const generation = authGeneration.current;
    if (!user || deniedGeneration.current === generation) return;
    const inFlight = inFlightHealthCheck.current;
    if (inFlight?.generation === generation && inFlight.uid === user.uid) return;

    const check = { generation, uid: user.uid };
    inFlightHealthCheck.current = check;
    let promise: Promise<CallableEnvelope<HealthDto>>;
    try {
      promise = api.health();
    } catch {
      promise = Promise.reject(new Error("Health request could not start."));
    }
    void promise
      .then((health) => {
        if (!mounted.current || authGeneration.current !== check.generation || currentUser.current?.uid !== check.uid) return;
        if (isAuthorizedStaff(user, health, config)) {
          commitGate({ state: "allowed", user, health });
          return;
        }
        deniedGeneration.current = check.generation;
        commitGate({ state: "denied" });
      })
      .catch(() => {
        if (!mounted.current || authGeneration.current !== check.generation || currentUser.current?.uid !== check.uid) return;
        deniedGeneration.current = check.generation;
        commitGate({ state: "denied" });
      })
      .finally(() => {
        if (inFlightHealthCheck.current?.generation === check.generation && inFlightHealthCheck.current.uid === check.uid) {
          inFlightHealthCheck.current = null;
        }
      });
  }, [api, commitGate, config, session]);

  useEffect(() => {
    mounted.current = true;
    if (config.configurationError || !session || !api) {
      commitGate({ state: "configuration" });
      return () => { mounted.current = false; };
    }
    const unsubscribe = session.subscribe((user) => {
      authGeneration.current += 1;
      currentUser.current = user;
      inFlightHealthCheck.current = null;
      deniedGeneration.current = null;
      if (!user) {
        commitGate({ state: "signed-out" });
        return;
      }
      commitGate({ state: "checking" });
      revalidateHealth();
    });
    return () => {
      mounted.current = false;
      authGeneration.current += 1;
      inFlightHealthCheck.current = null;
      unsubscribe();
    };
  }, [api, commitGate, config, revalidateHealth, session]);

  useEffect(() => {
    if (config.configurationError || !session || !api) return undefined;
    const checkWhenVisible = (): void => {
      if (document.visibilityState === "visible") revalidateHealth();
    };
    window.addEventListener("focus", checkWhenVisible);
    document.addEventListener("visibilitychange", checkWhenVisible);
    const interval = window.setInterval(checkWhenVisible, HEALTH_REVALIDATION_INTERVAL_MS);
    return () => {
      window.removeEventListener("focus", checkWhenVisible);
      document.removeEventListener("visibilitychange", checkWhenVisible);
      window.clearInterval(interval);
    };
  }, [api, config.configurationError, revalidateHealth, session]);

  const signOutAndClear = useCallback(async (): Promise<void> => {
    invalidateSession();
    if (!session) return;
    try {
      await session.signOut();
    } catch {
      // The visible session is already cleared; never restore protected UI on a sign-out failure.
    }
  }, [invalidateSession, session]);

  if (gate.state === "checking") return <LoadingBoundary />;
  if (gate.state === "configuration") return <ConfigurationUnavailable />;
  if (gate.state === "signed-out") return session ? <SignInPanel session={session} /> : <ConfigurationUnavailable />;
  if (gate.state === "denied") return <AccessDenied onRenew={() => { void signOutAndClear(); }} />;
  if (gate.state !== "allowed") return <AccessDenied onRenew={() => { void signOutAndClear(); }} />;

  const value: StaffAccess = { user: gate.user, health: gate.health, retryStaffCheck: revalidateHealth, signOut: signOutAndClear };

  return <StaffAccessContext.Provider value={value}>{children}</StaffAccessContext.Provider>;
}

function LoadingBoundary() {
  return (
    <main className="boundary-page" aria-busy="true" aria-live="polite">
      <div className="boundary-page__mark" aria-hidden="true" />
      <p className="eyebrow">KitchenSync administration</p>
      <h1>Verifying staff access</h1>
      <p>Checking the authenticated session and staff access record.</p>
    </main>
  );
}

function ConfigurationUnavailable() {
  return (
    <main className="boundary-page">
      <div className="boundary-page__mark boundary-page__mark--warning" aria-hidden="true" />
      <p className="eyebrow">Console unavailable</p>
      <h1>This build is not configured.</h1>
      <p>The administration console cannot establish a trusted service boundary. No customer data has been requested.</p>
    </main>
  );
}

function AccessDenied({ onRenew }: { readonly onRenew: () => void }) {
  return (
    <main className="boundary-page">
      <div className="boundary-page__mark boundary-page__mark--warning" aria-hidden="true" />
      <p className="eyebrow">Access denied</p>
      <h1>This account cannot access the administration console.</h1>
      <p>Staff access could not be verified. No administrative data is available in this session. Sign out and complete a new staff sign-in, including any required second factor.</p>
      <button className="button button--secondary" type="button" onClick={onRenew}>Sign out and sign in again</button>
    </main>
  );
}

export function SignInPanel({ session }: { readonly session: SessionGateway }) {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [failed, setFailed] = useState(false);
  const [factors, setFactors] = useState<readonly PhoneMfaFactor[] | null>(null);
  const [selectedFactor, setSelectedFactor] = useState("");
  const [challengeSent, setChallengeSent] = useState(false);
  const [verificationCode, setVerificationCode] = useState("");
  const verifierContainer = useRef<HTMLDivElement>(null);

  async function submit(event: FormEvent<HTMLFormElement>): Promise<void> {
    event.preventDefault();
    setSubmitting(true);
    setFailed(false);
    try {
      const outcome = await session.signIn(email.trim(), password);
      if (outcome.kind === "mfa-required") {
        setFactors(outcome.factors);
        setSelectedFactor(outcome.factors[0]?.id ?? "");
        setPassword("");
        setSubmitting(false);
      }
    } catch {
      setFailed(true);
      setSubmitting(false);
    }
  }

  async function sendPhoneChallenge(event: FormEvent<HTMLFormElement>): Promise<void> {
    event.preventDefault();
    if (!selectedFactor || !verifierContainer.current) {
      setFailed(true);
      return;
    }
    setSubmitting(true);
    setFailed(false);
    try {
      await session.beginPhoneMfa(selectedFactor, verifierContainer.current);
      setChallengeSent(true);
    } catch {
      setFailed(true);
    } finally {
      setSubmitting(false);
    }
  }

  async function completePhoneChallenge(event: FormEvent<HTMLFormElement>): Promise<void> {
    event.preventDefault();
    if (!/^\d{6,8}$/.test(verificationCode)) {
      setFailed(true);
      return;
    }
    setSubmitting(true);
    setFailed(false);
    try {
      await session.completePhoneMfa(verificationCode);
      setVerificationCode("");
    } catch {
      setFailed(true);
      setSubmitting(false);
    }
  }

  function resetPhoneChallenge(): void {
    session.resetMfaChallenge();
    setChallengeSent(false);
    setVerificationCode("");
    setFailed(false);
  }

  function cancelMfa(): void {
    session.cancelMfa();
    setFactors(null);
    setSelectedFactor("");
    setChallengeSent(false);
    setVerificationCode("");
    setFailed(false);
  }

  return (
    <main className="boundary-page boundary-page--signin">
      <div className="boundary-page__mark" aria-hidden="true" />
      <p className="eyebrow">KitchenSync administration</p>
      <h1>{factors ? "Verify your second factor" : "Sign in with your staff account"}</h1>
      <p>{factors ? "Choose an enrolled phone factor and enter its verification code to finish signing in." : "Access is verified against the authoritative staff service after authentication."}</p>
      {!factors ? (
        <form className="signin-form" onSubmit={submit} noValidate>
          <label>
            <span>Email</span>
            <input type="email" value={email} onChange={(event) => setEmail(event.target.value)} autoComplete="username" required />
          </label>
          <label>
            <span>Password</span>
            <input type="password" value={password} onChange={(event) => setPassword(event.target.value)} autoComplete="current-password" required />
          </label>
          <button className="button" type="submit" disabled={submitting}>{submitting ? "Signing in" : "Sign in"}</button>
          {failed ? <p className="form-error" role="alert">Sign-in could not be completed. Check your credentials and try again.</p> : null}
        </form>
      ) : !challengeSent ? (
        <form className="signin-form" onSubmit={sendPhoneChallenge} noValidate>
          {factors.length > 1 ? <fieldset className="mfa-factor-list"><legend>Choose a phone factor</legend>{factors.map((factor) => <label key={factor.id}><input type="radio" name="phone-factor" value={factor.id} checked={selectedFactor === factor.id} onChange={() => setSelectedFactor(factor.id)} /> <span>{factor.label}</span></label>)}</fieldset> : <p className="mfa-factor-note">{factors[0]?.label}</p>}
          <div className="mfa-recaptcha" ref={verifierContainer} aria-live="polite" />
          <button className="button" type="submit" disabled={submitting}>{submitting ? "Sending code" : "Send verification code"}</button>
          <button className="button button--secondary" type="button" onClick={cancelMfa}>Cancel</button>
          {failed ? <p className="form-error" role="alert">The second-factor challenge could not be completed. Try again or use a new staff sign-in.</p> : null}
        </form>
      ) : (
        <form className="signin-form" onSubmit={completePhoneChallenge} noValidate>
          <label>
            <span>Verification code</span>
            <input value={verificationCode} onChange={(event) => setVerificationCode(event.target.value.replace(/\D/g, ""))} inputMode="numeric" autoComplete="one-time-code" maxLength={8} required />
          </label>
          <div className="mfa-recaptcha" ref={verifierContainer} aria-live="polite" />
          <button className="button" type="submit" disabled={submitting}>{submitting ? "Verifying" : "Verify and sign in"}</button>
          <button className="button button--secondary" type="button" onClick={resetPhoneChallenge}>Send a new code</button>
          <button className="button button--secondary" type="button" onClick={cancelMfa}>Cancel</button>
          {failed ? <p className="form-error" role="alert">The verification code could not be accepted. Try again or use a new staff sign-in.</p> : null}
        </form>
      )}
    </main>
  );
}
