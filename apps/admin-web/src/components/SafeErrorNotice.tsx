import type { SafeErrorInfo } from "../api/dtos";

interface SafeErrorNoticeProps {
  readonly error: SafeErrorInfo;
  readonly onRetry?: () => void;
}

const messages: Record<SafeErrorInfo["appCode"], string> = {
  invalid_argument: "The requested lookup could not be completed.",
  permission_denied: "You are not authorized to view this information.",
  not_found: "The requested information is unavailable.",
  failed_precondition: "The requested information is unavailable in its current state.",
  rate_limited: "This service is temporarily limiting requests.",
  dependency_unavailable: "This service is temporarily unavailable.",
  internal: "The requested information is currently unavailable.",
};

export function SafeErrorNotice({ error, onRetry }: SafeErrorNoticeProps) {
  return (
    <section className="safe-error" role="alert" aria-live="assertive">
      <div>
        <p className="eyebrow">Request unavailable</p>
        <p className="safe-error__message">{messages[error.appCode]}</p>
        <p className="safe-error__reference">
          {error.requestId ? <>Request ID: <code>{error.requestId}</code></> : "Request ID unavailable"}
        </p>
      </div>
      {onRetry && error.retryable ? (
        <button className="button button--secondary" type="button" onClick={onRetry}>
          Try again
        </button>
      ) : null}
    </section>
  );
}
