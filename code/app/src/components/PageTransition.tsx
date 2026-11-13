// Reusable pagetransition display component.

import { useEffect } from "react";
import { useLocation } from "react-router-dom";

/** Fade/slide in on route change + scroll to top. */
export default function PageTransition({ children }: { children: React.ReactNode }) {
  const loc = useLocation();

  useEffect(() => {
    window.scrollTo({ top: 0, behavior: "smooth" });
  }, [loc.pathname]);

  return (
    <div key={loc.pathname} className="page-transition">
      {children}
    </div>
  );
}
