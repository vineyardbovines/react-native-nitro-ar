import type { HybridObject } from "react-native-nitro-modules";

export type WorldMappingStatus = "notAvailable" | "limited" | "extending" | "mapped";

export interface ARWorldMap extends HybridObject<{ ios: "swift" }> {
  /** Unique identifier for this world map */
  readonly identifier: string;

  /** Center of the mapped area in world coordinates [x, y, z] */
  readonly center: number[];

  /** Approximate extent/radius of the mapped area in meters [x, y, z] */
  readonly extent: number[];

  /** Number of anchors stored in this world map */
  readonly anchorCount: number;

  /** Serialized world map data as base64 string */
  getData(): string;
}
