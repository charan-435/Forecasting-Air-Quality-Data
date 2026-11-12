# WaveCatBoost Lab

Interactive educational front-end for the ATSA WaveCatBoost project.

- Stack: React · TypeScript · Vite · Plotly · KaTeX
- Hosting: GitHub Pages (`/wavecatboost-learn/`)
- Data: committed JSON from R (`public/data/`)

## Develop

```bash
# from repo root — refresh data
Rscript scripts/figures/export_lab_assets.R

cd lab
npm install
npm run dev
```

## Build

```bash
cd lab
npm run build
```

Output: `lab/dist/` (base path `/wavecatboost-learn/`).

## Deploy

GitHub Actions builds on push to `main` when this folder is the Pages source, or publish `dist/` into [Charanponaganti/wavecatboost-learn](https://github.com/Charanponaganti/wavecatboost-learn).

No sign-in. No backend.
