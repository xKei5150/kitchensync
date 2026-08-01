import { createContext, useContext } from "react";
import type { CallableEnvelope, HealthDto } from "../api/dtos";
import type { SessionUser } from "./session";

export interface StaffAccess {
  readonly user: SessionUser;
  readonly health: CallableEnvelope<HealthDto>;
  readonly retryStaffCheck: () => void;
  readonly signOut: () => Promise<void>;
}

export const StaffAccessContext = createContext<StaffAccess | null>(null);

export function useStaffAccess(): StaffAccess {
  const value = useContext(StaffAccessContext);
  if (!value) throw new Error("Staff access is only available after the staff boundary.");
  return value;
}
