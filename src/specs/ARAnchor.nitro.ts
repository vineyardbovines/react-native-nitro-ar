import type { HybridObject } from "react-native-nitro-modules";

export interface ARAnchor extends HybridObject<{ ios: "swift" }> {
  /** Unique identifier */
  readonly identifier: string;

  /** Position in world coordinates [x, y, z] */
  readonly position: number[];

  /** Rotation as quaternion [x, y, z, w] */
  readonly rotation: number[];

  /** Full 4x4 transform matrix (column-major, 16 values) */
  readonly transform: number[];

  /** Whether anchor is currently being tracked */
  readonly isTracked: boolean;

  /** Optional label for user-created anchors */
  readonly label: string | undefined;
}
