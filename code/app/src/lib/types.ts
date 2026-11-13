// Defines the shapes of saved data used by the app. These types help pages agree on field
// names; they do not load or change data.

export type ManifestSeriesMeta = {
  sensor: string;
  pollutant: string;
  n_full: number;
  t0: string;
  t1: string;
  freq: string;
  units: string;
  stats: { mean: number | null; sd: number | null; min: number | null; max: number | null };
  file: string;
};

export type ManifestDataset = {
  sensor: string;
  default_pollutant: string;
  pollutants: string[];
  series: Record<string, ManifestSeriesMeta>;
};

export type Manifest = {
  app: string;
  paper: string;
  paper_code: string;
  links: { cpcb: string; caaqms: string };
  datasets: Record<string, ManifestDataset>;
  notes: { id1?: string; scores?: string; series?: string };
};

export type Series = {
  sensor: string;
  pollutant: string;
  n_full: number;
  t: string[];
  y: number[];
  stats: ManifestSeriesMeta["stats"];
  units?: string;
  t0?: string;
  t1?: string;
};

export type ScoreRow = {
  sensor: string;
  pollutant: string;
  horizon: string;
  method: string;
  MASE: number;
  MAE: number;
  RMSE: number;
  protocol?: string;
};

export type Conformal = {
  provenance: string;
  note?: string;
  sensor: string;
  pollutant: string;
  horizon: string;
  y: number[];
  yhat: number[];
  abs_resid?: number[];
  q95?: number;
  lower?: number[] | null;
  upper?: number[] | null;
  alpha?: number;
};

export type EdaDecision = {
  EDA_finding?: string;
  Pipeline_choice?: string;
};
