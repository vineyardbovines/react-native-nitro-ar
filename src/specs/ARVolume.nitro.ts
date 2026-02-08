import type { HybridObject } from "react-native-nitro-modules";

export interface ARVolume extends HybridObject<{ ios: "swift" }> {
  /** Center position [x, y, z] */
  readonly center: number[];

  readonly width: number;
  readonly height: number;
  readonly depth: number;

  /** Rotation as quaternion [x, y, z, w] */
  readonly rotation: number[];

  readonly isStable: boolean;
}
