import { getHostComponent, NitroModules } from "react-native-nitro-modules";
import ARViewConfig from "../nitrogen/generated/shared/json/ARViewConfig.json";
import type { ARBoundingBoxBuilder } from "./specs/ARBoundingBoxBuilder.nitro";
import type { ARSession } from "./specs/ARSession.nitro";
import type { ARViewMethods, ARViewProps } from "./specs/ARView.nitro";

export type { ARAnchor } from "./specs/ARAnchor.nitro";
export type { ARBoundingBoxBuilder } from "./specs/ARBoundingBoxBuilder.nitro";
export type { ARDepthData } from "./specs/ARDepthData.nitro";
export type { ARFrame } from "./specs/ARFrame.nitro";
export type {
  ARDirectionalLightEstimate,
  ARLightEstimate,
} from "./specs/ARLightEstimate.nitro";
export type { ARMeasurement } from "./specs/ARMeasurement.nitro";

export type {
  ARPlaneAnchor,
  ARPlaneGeometry,
  PlaneAlignment,
  PlaneClassification,
} from "./specs/ARPlaneAnchor.nitro";
export type {
  ARRaycastResult,
  RaycastAlignment,
  RaycastQuery,
  RaycastTarget,
} from "./specs/ARRaycastResult.nitro";
export type {
  ARMeshAnchor,
  LiDARCapabilities,
  MeshClassification,
  SceneReconstructionMode,
} from "./specs/ARSceneMesh.nitro";
// Re-export all types
export type {
  ARSession,
  ARSessionConfiguration,
  CameraPose,
  EnvironmentTexturing,
  PlaneDetectionMode,
  TrackingState,
  TrackingStateReason,
  WorldAlignment,
} from "./specs/ARSession.nitro";
export type { ARViewHitResult, ARViewMethods, ARViewProps } from "./specs/ARView.nitro";
export type { ARVolume } from "./specs/ARVolume.nitro";
export type { ARWorldMap, WorldMappingStatus } from "./specs/ARWorldMap.nitro";

// ARView Component
export const ARView = getHostComponent<ARViewProps, ARViewMethods>("ARView", () => ARViewConfig);

// Factory functions
export function createARSession(): ARSession {
  return NitroModules.createHybridObject<ARSession>("ARSession");
}

export function createARBoundingBoxBuilder(): ARBoundingBoxBuilder {
  return NitroModules.createHybridObject<ARBoundingBoxBuilder>("ARBoundingBoxBuilder");
}
