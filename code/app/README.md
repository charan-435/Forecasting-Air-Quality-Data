# WaveCatBoost Lab

A React/TypeScript viewer for the project's saved data, scores and uncertainty examples. Browser calculations illustrate decomposition; training remains in the R pipelines.

From the repository root, refresh current app data if needed:

```sh
Rscript code/app/data_tools/export_app_assets.R
python code/app/data_tools/export_app_series.py
```

Then, with Node.js 22 or later:

```sh
cd code/app
npm ci
npm run dev
```

`npm run build` checks TypeScript and creates `dist/`; `npm run preview` serves that build locally. Vite uses a relative base by default. For a hosted subdirectory, set `VITE_BASE_PATH=/your-project/` in the build environment.

| Folder | Purpose |
|---|---|
| src/pages/ | Report sections and interactive examples. |
| src/components/ | Shared layout, charts and controls. |
| src/lib/ | Data loading, statistics, date formatting and browser wavelet helpers. |
| src/state/ | Selected station/pollutant and fetched-data cache. |
| public/data/ | JSON/CSV exports from recorded project results. |

The app loads only its own `public/data/` assets. It does not depend on the removed static viewer or on a running R service. Keep `package-lock.json` with dependency changes so `npm ci` installs the same app dependency graph.
