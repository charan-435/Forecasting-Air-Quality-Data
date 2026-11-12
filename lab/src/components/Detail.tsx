/** Expandable deep-dive used across lessons. */
export default function Detail({
  title,
  children,
  open = false,
}: {
  title: string;
  children: React.ReactNode;
  open?: boolean;
}) {
  return (
    <details className="more" open={open || undefined}>
      <summary>{title}</summary>
      <div className="detail-body">{children}</div>
    </details>
  );
}
