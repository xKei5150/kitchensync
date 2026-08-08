import { createRoot } from "react-dom/client";
import { App, SafeAppErrorBoundary } from "./App";
import { runtimeConfig } from "./config/runtime";
import { createFirebaseConsoleServices } from "./firebase";
import "./styles.css";

const services = createFirebaseConsoleServices(runtimeConfig);

createRoot(document.getElementById("root")!).render(
  <SafeAppErrorBoundary>
    <App config={runtimeConfig} session={services?.session ?? null} api={services?.api ?? null} />
  </SafeAppErrorBoundary>,
);
