import {
  getMultiFactorResolver,
  onAuthStateChanged,
  PhoneAuthProvider,
  PhoneMultiFactorGenerator,
  RecaptchaVerifier,
  signInWithEmailAndPassword,
  signOut,
  type Auth,
  type MultiFactorError,
  type MultiFactorResolver,
  type PhoneMultiFactorInfo,
} from "firebase/auth";

export interface SessionUser {
  readonly uid: string;
  readonly email: string | null;
}

export interface PhoneMfaFactor {
  readonly id: string;
  readonly label: string;
}

export type SignInOutcome =
  | { readonly kind: "signed-in" }
  | { readonly kind: "mfa-required"; readonly factors: readonly PhoneMfaFactor[] };

export interface SessionGateway {
  subscribe(listener: (user: SessionUser | null) => void): () => void;
  signIn(email: string, password: string): Promise<SignInOutcome>;
  beginPhoneMfa(factorId: string, verifierContainer: HTMLElement): Promise<void>;
  completePhoneMfa(code: string): Promise<void>;
  resetMfaChallenge(): void;
  cancelMfa(): void;
  signOut(): Promise<void>;
}

interface PendingMfaSignIn {
  readonly resolver: MultiFactorResolver;
  readonly factors: readonly PhoneMultiFactorInfo[];
  verifier: RecaptchaVerifier | null;
  verificationId: string | null;
}

function isMfaRequired(error: unknown): error is MultiFactorError {
  return typeof error === "object"
    && error !== null
    && "code" in error
    && (error as { readonly code?: unknown }).code === "auth/multi-factor-auth-required";
}

function maskedPhoneFactorLabel(phoneNumber: string, index: number): string {
  const ending = phoneNumber.replace(/\D/g, "").slice(-2);
  return ending.length === 2 ? `Phone factor ${index + 1} ending in **${ending}` : `Phone factor ${index + 1}`;
}

function clearVerifier(flow: PendingMfaSignIn | null): void {
  if (!flow?.verifier) return;
  flow.verifier.clear();
  flow.verifier = null;
}

export function createFirebaseSessionGateway(auth: Auth): SessionGateway {
  let pendingMfa: PendingMfaSignIn | null = null;

  return {
    subscribe(listener) {
      return onAuthStateChanged(auth, (user) => {
        listener(user ? { uid: user.uid, email: user.email } : null);
      });
    },
    async signIn(email, password) {
      try {
        await signInWithEmailAndPassword(auth, email, password);
        return { kind: "signed-in" };
      } catch (error) {
        if (!isMfaRequired(error)) throw error;
        const resolver = getMultiFactorResolver(auth, error);
        const factors = resolver.hints.filter(
          (hint): hint is PhoneMultiFactorInfo => hint.factorId === PhoneMultiFactorGenerator.FACTOR_ID && "phoneNumber" in hint,
        );
        if (factors.length === 0) throw new Error("No supported second factor is available.");
        pendingMfa = { resolver, factors, verifier: null, verificationId: null };
        return {
          kind: "mfa-required",
          factors: factors.map((factor, index) => ({ id: factor.uid, label: maskedPhoneFactorLabel(factor.phoneNumber, index) })),
        };
      }
    },
    async beginPhoneMfa(factorId, verifierContainer) {
      const flow = pendingMfa;
      const factor = flow?.factors.find((candidate) => candidate.uid === factorId);
      if (!flow || !factor) throw new Error("Second-factor challenge is unavailable.");
      clearVerifier(flow);
      const verifier = new RecaptchaVerifier(auth, verifierContainer, { size: "invisible" });
      flow.verifier = verifier;
      try {
        flow.verificationId = await new PhoneAuthProvider(auth).verifyPhoneNumber(
          { multiFactorHint: factor, session: flow.resolver.session },
          verifier,
        );
      } catch (error) {
        clearVerifier(flow);
        flow.verificationId = null;
        throw error;
      }
    },
    async completePhoneMfa(code) {
      const flow = pendingMfa;
      if (!flow?.verificationId) throw new Error("Second-factor verification is unavailable.");
      const credential = PhoneAuthProvider.credential(flow.verificationId, code);
      const assertion = PhoneMultiFactorGenerator.assertion(credential);
      await flow.resolver.resolveSignIn(assertion);
      clearVerifier(flow);
      pendingMfa = null;
    },
    resetMfaChallenge() {
      if (!pendingMfa) return;
      clearVerifier(pendingMfa);
      pendingMfa.verificationId = null;
    },
    cancelMfa() {
      clearVerifier(pendingMfa);
      pendingMfa = null;
    },
    async signOut() {
      clearVerifier(pendingMfa);
      pendingMfa = null;
      await signOut(auth);
    },
  };
}
