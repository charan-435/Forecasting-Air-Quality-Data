// Loads the shared logo asset and uses the requested size for its width and height.

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
