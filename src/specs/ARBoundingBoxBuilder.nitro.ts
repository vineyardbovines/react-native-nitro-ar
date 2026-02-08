import type { HybridObject } from "react-native-nitro-modules";
import type { ARAnchor } from "./ARAnchor.nitro";
import type { ARVolume } from "./ARVolume.nitro";

export interface ARBoundingBoxBuilder extends HybridObject<{ ios: "swift" }> {
  addBaseAnchor(anchor: ARAnchor): void;

  readonly canBuild: boolean;

  build(): ARVolume;
}
