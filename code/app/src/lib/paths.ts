/** Prefix public assets for GitHub Pages base. */
export function asset(path: string): string {
  const base = import.meta.env.BASE_URL || "/";
  const p = path.replace(/^\//, "");
  return `${base}${p}`;
}

export async function loadJson<T>(path: string): Promise<T> {
  const res = await fetch(asset(path));
  if (!res.ok) throw new Error(`Failed to load ${path}: ${res.status}`);
  return res.json() as Promise<T>;
}
