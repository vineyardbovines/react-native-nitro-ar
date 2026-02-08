import type { HybridObject } from "react-native-nitro-modules";

export interface ARLightEstimate extends HybridObject<{ ios: "swift" }> {
  /** Ambient light intensity in lumens (0-2000 typical) */
  readonly ambientIntensity: number;

  /** Color temperature in Kelvin (6500 = neutral daylight) */
  readonly ambientColorTemperature: number;
}

export interface ARDirectionalLightEstimate extends ARLightEstimate {
  /** Primary light direction as normalized vector [x, y, z] */
  readonly primaryLightDirection: number[];

  /** Primary light intensity in lumens */
  readonly primaryLightIntensity: number;

  /** Spherical harmonics coefficients for advanced lighting (27 values: 9 RGB triplets) */
  readonly sphericalHarmonicsCoefficients: number[];
}
