// Configures app builds and the hosting base path.

import { defineConfig, loadEnv } from "vite";
import react from "@vitejs/plugin-react";

// Use a relative base locally; set VITE_BASE_PATH for a hosted project subpath.
export default defineConfig(({ mode }) => ({
  plugins: [react()],
  base: loadEnv(mode, ".", "VITE_").VITE_BASE_PATH || "./",
}));
