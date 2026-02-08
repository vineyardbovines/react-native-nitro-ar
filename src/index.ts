import { NitroModules, getHostComponent } from "react-native-nitro-modules";
import type { ARSession } from "./specs/ARSession.nitro";
import type { ARBoundingBoxBuilder } from "./specs/ARBoundingBoxBuilder.nitro";
import type { ARViewProps, ARViewMethods } from "./specs/ARView.nitro";
import ARViewConfig from "../nitrogen/generated/shared/json/ARViewConfig.json";

// Re-export all types
export type {
  ARSession,
  CameraPose,
  TrackingState,
  TrackingStateReason,
  ARSessionConfiguration,
  PlaneDetectionMode,
  EnvironmentTexturing,
  WorldAlignment,
} from "./specs/ARSession.nitro";

export type { ARAnchor } from "./specs/ARAnchor.nitro";

export type {
  ARRaycastResult,
  RaycastTarget,
  RaycastAlignment,
  RaycastQuery,
} from "./specs/ARRaycastResult.nitro";

export type { ARMeasurement } from "./specs/ARMeasurement.nitro";

export type { ARVolume } from "./specs/ARVolume.nitro";

export type { ARBoundingBoxBuilder } from "./specs/ARBoundingBoxBuilder.nitro";

export type {
  ARPlaneAnchor,
  ARPlaneGeometry,
  PlaneAlignment,
  PlaneClassification,
} from "./specs/ARPlaneAnchor.nitro";

export type {
  ARLightEstimate,
  ARDirectionalLightEstimate,
} from "./specs/ARLightEstimate.nitro";

export type { ARDepthData } from "./specs/ARDepthData.nitro";

export type { ARFrame } from "./specs/ARFrame.nitro";

export type {
  ARMeshAnchor,
  MeshClassification,
  SceneReconstructionMode,
  LiDARCapabilities,
} from "./specs/ARSceneMesh.nitro";

export type { ARWorldMap, WorldMappingStatus } from "./specs/ARWorldMap.nitro";

export type { ARViewProps, ARViewMethods, ARViewHitResult } from "./specs/ARView.nitro";

// ARView Component
export const ARView = getHostComponent<ARViewProps, ARViewMethods>(
  "ARView",
  () => ARViewConfig
);

// Factory functions
export function createARSession(): ARSession {
  return NitroModules.createHybridObject<ARSession>("ARSession");
}

export function createARBoundingBoxBuilder(): ARBoundingBoxBuilder {
  return NitroModules.createHybridObject<ARBoundingBoxBuilder>(
    "ARBoundingBoxBuilder"
  );
}
