import type { RuntimeConfig } from "../config/runtime";

const environmentLabel = {
  development: "Development",
  preview: "Preview",
  production: "Production",
} as const;

interface EnvironmentBannerProps {
  readonly config: RuntimeConfig;
}

export function EnvironmentBanner({ config }: EnvironmentBannerProps) {
  return (
    <aside className={`environment-banner environment-banner--${config.environment}`} aria-label="Build environment">
      <div className="environment-banner__identity">
        <span className="environment-banner__marker" aria-hidden="true" />
        <strong>{environmentLabel[config.environment]}</strong>
        <span className="environment-banner__notice">
          {config.environment === "production" ? "Live customer environment" : "Non-production environment"}
        </span>
      </div>
      <dl className="environment-banner__metadata">
        <div>
          <dt>Project</dt>
          <dd>{config.projectId}</dd>
        </div>
        <div>
          <dt>API</dt>
          <dd>{config.apiVersion}</dd>
        </div>
        <div>
          <dt>App</dt>
          <dd>{config.appVersion}</dd>
        </div>
      </dl>
    </aside>
  );
}
