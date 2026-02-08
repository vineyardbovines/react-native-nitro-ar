import type { HybridObject } from "react-native-nitro-modules";
import type { ARLightEstimate, ARDirectionalLightEstimate } from "./ARLightEstimate.nitro";
import type { ARDepthData } from "./ARDepthData.nitro";

export interface ARFrame extends HybridObject<{ ios: "swift" }> {
  /** Timestamp of this frame in seconds */
  readonly timestamp: number;

  /** Camera position in world space [x, y, z] */
  readonly cameraPosition: number[];

  /** Camera rotation as quaternion [x, y, z, w] */
  readonly cameraRotation: number[];

  /** Camera projection matrix (4x4, column-major, 16 values) */
  readonly projectionMatrix: number[];

  /** Camera view matrix (4x4, column-major, 16 values) */
  readonly viewMatrix: number[];

  /** Camera intrinsics [fx, fy, cx, cy] */
  readonly cameraIntrinsics: number[];

  /** Image resolution [width, height] */
  readonly imageResolution: number[];

  /** Light estimate if available */
  readonly lightEstimate: ARLightEstimate | undefined;

  /** Directional light estimate (face tracking only) */
  readonly directionalLightEstimate: ARDirectionalLightEstimate | undefined;

  /** Scene depth data if available (requires LiDAR) */
  readonly sceneDepth: ARDepthData | undefined;

  /** Smoothed scene depth if available */
  readonly smoothedSceneDepth: ARDepthData | undefined;

  /** Captured image as base64 JPEG (quality 0-1) */
  getCapturedImage(quality: number): string;
}
