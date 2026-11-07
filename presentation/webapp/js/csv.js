(function (global) {
  function splitLine(line) {
    const out = [];
    let cur = "";
    let q = false;
    for (let i = 0; i < line.length; i++) {
      const c = line[i];
      if (c === '"') {
        if (q && line[i + 1] === '"') { cur += '"'; i++; }
        else q = !q;
      } else if (c === "," && !q) {
        out.push(cur); cur = "";
      } else cur += c;
    }
    out.push(cur);
    return out.map((s) => s.trim());
  }

  function parseCsv(text) {
    const raw = text.replace(/^\uFEFF/, "").replace(/\r\n/g, "\n").replace(/\r/g, "\n");
    const lines = raw.split("\n").filter((l) => l.trim().length);
    if (lines.length < 2) throw new Error("CSV needs a header and at least one row.");
    const headers = splitLine(lines[0]);
    const rows = [];
    for (let i = 1; i < lines.length; i++) {
      const cells = splitLine(lines[i]);
      if (cells.every((c) => !c)) continue;
      const obj = {};
      headers.forEach((h, j) => { obj[h] = cells[j] ?? ""; });
      rows.push(obj);
    }
    return { headers, rows };
  }

  function findTimeCol(headers) {
    const prefs = ["datetime", "timestamp", "date", "time", "ds", "t"];
    const lower = headers.map((h) => h.toLowerCase());
    for (const p of prefs) {
      const i = lower.indexOf(p);
      if (i >= 0) return headers[i];
    }
    for (let i = 0; i < lower.length; i++) {
      if (/date|time/.test(lower[i])) return headers[i];
    }
    return headers[0];
  }

  function numericCols(headers, rows, timeCol) {
    return headers.filter((h) => {
      if (h === timeCol) return false;
      let n = 0, ok = 0;
      for (const r of rows) {
        const v = r[h];
        if (v === "" || v == null) continue;
        n++;
        if (!Number.isNaN(Number(v))) ok++;
      }
      return n > 0 && ok / n > 0.8;
    });
  }

  function seriesFrom(rows, timeCol, valueCol) {
    const pts = [];
    for (const r of rows) {
      const y = Number(r[valueCol]);
      if (Number.isNaN(y)) continue;
      pts.push({ t: r[timeCol], y });
    }
    return pts;
  }

  // ŷ_{t+h} = y_{t+h-S}
  function seasonalNaive(y, h, S) {
    const n = y.length;
    if (n <= h + S) throw new Error(`Need more than ${h + S} observations for h=${h}, S=${S}.`);
    const train = y.slice(0, n - h);
    const test = y.slice(n - h);
    const yhat = new Float64Array(h);
    for (let i = 0; i < h; i++) {
      const idx = train.length - S + (i % S);
      yhat[i] = train[idx];
    }
    return { train, test, yhat };
  }

  function mae(a, b) {
    let s = 0;
    for (let i = 0; i < a.length; i++) s += Math.abs(a[i] - b[i]);
    return s / a.length;
  }
  function rmse(a, b) {
    let s = 0;
    for (let i = 0; i < a.length; i++) {
      const e = a[i] - b[i];
      s += e * e;
    }
    return Math.sqrt(s / a.length);
  }
  function mase(test, yhat, train, S) {
    let denom = 0, c = 0;
    for (let i = S; i < train.length; i++) {
      denom += Math.abs(train[i] - train[i - S]);
      c++;
    }
    denom = denom / Math.max(1, c);
    if (denom < 1e-12) return NaN;
    return mae(test, yhat) / denom;
  }

  global.CSVTOOLS = {
    parseCsv,
    findTimeCol,
    numericCols,
    seriesFrom,
    seasonalNaive,
    mae,
    rmse,
    mase,
  };
})(window);
