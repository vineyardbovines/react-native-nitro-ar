import type { HybridObject } from "react-native-nitro-modules";

/** Result of measuring an object in 3D space */
export interface ARObjectMeasurement {
  /** Width in meters (X axis) */
  width: number;
  /** Height in meters (Y axis) */
  height: number;
  /** Depth in meters (Z axis) */
  depth: number;
  /** Center position in world space [x, y, z] */
  center: number[];
  /** Orientation axes (3x3 matrix as 9 values) */
  axes: number[];
  /** Confidence score 0-1 */
  confidence: number;
  /** Number of 3D points used for measurement */
  pointCount: number;
}

/** Result of object segmentation */
export interface ARSegmentationResult extends HybridObject<{ ios: "swift" }> {
  /** Whether segmentation was successful */
  readonly success: boolean;
  /** Bounding box in normalized coordinates [x, y, width, height] */
  readonly boundingBox: number[];
  /** Number of pixels in the mask */
  readonly maskPixelCount: number;
  /** Get 3D points within the segmented region (requires LiDAR) */
  getDepthPoints(): number[];
  /** Measure the segmented object */
  measure(): ARObjectMeasurement | undefined;
}
