import type { HybridObject } from "react-native-nitro-modules";

export type RaycastTarget =
  | "existingPlaneGeometry"
  | "existingPlaneInfinite"
  | "estimatedPlane"
  | "any";

export type RaycastAlignment = "horizontal" | "vertical" | "any";

export interface RaycastQuery {
  /** Screen X coordinate (0-1 normalized or pixel) */
  x: number;
  /** Screen Y coordinate (0-1 normalized or pixel) */
  y: number;
  /** What surfaces to hit */
  target: RaycastTarget;
  /** Plane alignment filter */
  alignment: RaycastAlignment;
}

export interface ARRaycastResult extends HybridObject<{ ios: "swift" }> {
  /** Position [x, y, z] */
  readonly position: number[];
  /** Rotation as quaternion [x, y, z, w] */
  readonly rotation: number[];
  readonly distance: number;
  readonly target: RaycastTarget;

  /** Anchor identifier if hit an existing plane */
  readonly anchorId: string | undefined;
}
