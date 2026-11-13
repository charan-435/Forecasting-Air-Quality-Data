// Reusable katex display component.

import katex from "katex";

/** Renders TeX as HTML only (no MathML twin that overlaps in some browsers). */
export default function Katex({ tex, display = false }: { tex: string; display?: boolean }) {
  const html = katex.renderToString(tex, {
    throwOnError: false,
    displayMode: display,
    output: "html",
  });
  if (display) {
    return (
      <div className="eq-line" dangerouslySetInnerHTML={{ __html: html }} />
    );
  }
  return <span dangerouslySetInnerHTML={{ __html: html }} />;
}

export function EqBlock({ children }: { children: React.ReactNode }) {
  return <div className="eq">{children}</div>;
}
