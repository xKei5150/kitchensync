interface StatusPillProps {
  readonly state: string;
}

function tone(state: string): "good" | "warning" | "danger" | "neutral" {
  if (["healthy", "allowed", "valid", "coherent_trial", "complete", "supported", "evidenced"].includes(state)) return "good";
  if (["degraded", "current_state_heuristic", "missing", "unknown", "not_applicable", "unsupported_paid_or_unreconciled"].includes(state)) return "warning";
  if (["unavailable", "denied", "malformed", "inconsistent", "incomplete", "expired_trial", "unsupported"].includes(state)) return "danger";
  return "neutral";
}

export function StatusPill({ state }: StatusPillProps) {
  return <span className={`status-pill status-pill--${tone(state)}`}>{state.replaceAll("_", " ")}</span>;
}
