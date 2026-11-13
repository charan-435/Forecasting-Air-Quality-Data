// Connects each URL to its page. DataProvider shares the saved data, and Layout supplies
// the common navigation around every page.

import { HashRouter, Navigate, Route, Routes } from "react-router-dom";
import Layout from "./components/Layout";
import { DataProvider } from "./state/DataContext";
import Start from "./pages/Start";
import DataPage from "./pages/DataPage";
import EdaPage from "./pages/EdaPage";
import ModwtPage from "./pages/ModwtPage";
import PlaygroundPage from "./pages/PlaygroundPage";
import CatboostPage from "./pages/CatboostPage";
import ResultsPage from "./pages/ResultsPage";
import ConformalPage from "./pages/ConformalPage";
import ExtensionsPage from "./pages/ExtensionsPage";
import CreditsPage from "./pages/CreditsPage";

export default function App() {
  return (
    <DataProvider>
      <HashRouter>
        <Routes>
          <Route element={<Layout />}>
            <Route index element={<Start />} />
            <Route path="data" element={<DataPage />} />
            <Route path="eda" element={<EdaPage />} />
            <Route path="modwt" element={<ModwtPage />} />
            <Route path="playground" element={<PlaygroundPage />} />
            <Route path="catboost" element={<CatboostPage />} />
            <Route path="results" element={<ResultsPage />} />
            <Route path="conformal" element={<ConformalPage />} />
            <Route path="extensions" element={<ExtensionsPage />} />
            <Route path="credits" element={<CreditsPage />} />
            <Route path="*" element={<Navigate to="/" replace />} />
          </Route>
        </Routes>
      </HashRouter>
    </DataProvider>
  );
}
