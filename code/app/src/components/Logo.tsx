import { asset } from "../lib/paths";

export default function Logo({ size = 28 }: { size?: number }) {
  return (
    <img
      src={asset("logo.svg")}
      alt=""
      width={size}
      height={size}
      className="brand-logo"
      draggable={false}
    />
  );
}
