import { onAuthStateChanged, signInWithEmailAndPassword, signOut, type Auth } from "firebase/auth";

export interface SessionUser {
  readonly uid: string;
  readonly email: string | null;
}

export interface SessionGateway {
  subscribe(listener: (user: SessionUser | null) => void): () => void;
  signIn(email: string, password: string): Promise<void>;
  signOut(): Promise<void>;
}

export interface PasswordSignInDependencies {
  readonly signInWithEmailAndPassword: (auth: Auth, email: string, password: string) => Promise<unknown>;
}

const firebasePasswordSignInDependencies: PasswordSignInDependencies = {
  signInWithEmailAndPassword,
};

function isMultiFactorRequired(error: unknown): boolean {
  return typeof error === "object"
    && error !== null
    && "code" in error
    && (error as { readonly code?: unknown }).code === "auth/multi-factor-auth-required";
}

export class PasswordOnlySignInError extends Error {
  public constructor() {
    super("Sign-in could not be completed.");
    this.name = "PasswordOnlySignInError";
  }
}

export function createFirebaseSessionGateway(
  auth: Auth,
  dependencies: PasswordSignInDependencies = firebasePasswordSignInDependencies,
): SessionGateway {
  return {
    subscribe(listener) {
      return onAuthStateChanged(auth, (user) => {
        listener(user ? { uid: user.uid, email: user.email } : null);
      });
    },
    async signIn(email, password) {
      try {
        await dependencies.signInWithEmailAndPassword(auth, email, password);
      } catch (error) {
        if (isMultiFactorRequired(error)) throw new PasswordOnlySignInError();
        throw error;
      }
    },
    async signOut() {
      await signOut(auth);
    },
  };
}
