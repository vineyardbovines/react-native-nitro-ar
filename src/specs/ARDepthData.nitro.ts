import type { HybridObject } from "react-native-nitro-modules";

export interface ARDepthData extends HybridObject<{ ios: "swift" }> {
  /** Width of the depth map in pixels */
  readonly width: number;

  /** Height of the depth map in pixels */
  readonly height: number;

  /**
   * Depth values in meters (row-major, width * height floats).
   * Values are distance from camera plane.
   */
  readonly depthMap: number[];

  /**
   * Confidence values (0-2):
   * 0 = low confidence
   * 1 = medium confidence
   * 2 = high confidence
   */
  readonly confidenceMap: number[];

  /** Get depth at normalized screen coordinate (0-1) */
  getDepthAt(x: number, y: number): number;

  /** Get confidence at normalized screen coordinate (0-1) */
  getConfidenceAt(x: number, y: number): number;
}
