import type { HybridObject } from "react-native-nitro-modules";
import type { ARAnchor } from "./ARAnchor.nitro";

export interface ARMeasurement extends HybridObject<{ ios: "swift" }> {
  readonly start: ARAnchor;
  readonly end: ARAnchor;

  readonly length: number;
  readonly isValid: boolean;
}
