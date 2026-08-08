import { useState, type FormEvent } from "react";
import { isCaseIdentifier } from "../api/dtos";
import type { SupportCaseContext } from "../api/callable";

interface CaseContextFormProps {
  readonly submitLabel: string;
  readonly isSubmitting: boolean;
  readonly onSubmit: (context: SupportCaseContext) => void;
}

export function CaseContextForm({ submitLabel, isSubmitting, onSubmit }: CaseContextFormProps) {
  const [caseId, setCaseId] = useState("");
  const [invalid, setInvalid] = useState(false);

  function submit(event: FormEvent<HTMLFormElement>): void {
    event.preventDefault();
    const normalized = caseId.trim();
    if (!isCaseIdentifier(normalized)) {
      setInvalid(true);
      return;
    }
    setInvalid(false);
    onSubmit({ purpose: "support_case", caseId: normalized });
  }

  return (
    <form className="case-form" onSubmit={submit} noValidate>
      <div className="case-form__fixed">
        <span className="detail-label">Purpose</span>
        <strong>Support case</strong>
      </div>
      <label>
        <span>Case ID</span>
        <input
          value={caseId}
          onChange={(event) => setCaseId(event.target.value)}
          autoComplete="off"
          inputMode="text"
          maxLength={128}
          aria-invalid={invalid}
          aria-describedby={invalid ? "case-id-error" : undefined}
          required
        />
      </label>
      <button className="button" type="submit" disabled={isSubmitting}>{isSubmitting ? "Checking" : submitLabel}</button>
      {invalid ? <p className="form-error" id="case-id-error">Enter a valid support case identifier.</p> : null}
    </form>
  );
}
