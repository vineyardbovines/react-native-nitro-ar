# react-native-nitro-ar

A high-performance [Nitro module](https://nitro.margelo.com/) that provides ARKit functionality for React Native on iOS.

## Features

- **AR Session Management** - Start, pause, and reset AR sessions with full configuration control
- **Plane Detection** - Detect horizontal and vertical planes with classification (floor, wall, ceiling, table, seat, window, door)
- **Raycasting** - Hit-test against detected planes and estimated surfaces
- **Anchors** - Create and track anchors in 3D space
- **Measurements** - Measure distances between anchor points
- **Bounding Boxes** - Calculate oriented bounding boxes (OBB) using PCA
- **Light Estimation** - Access ambient and directional light data with spherical harmonics
- **LiDAR Depth** - Access scene depth and smoothed depth data (iOS 14+, LiDAR devices)
- **World Maps** - Save and restore AR world maps for persistent AR experiences
- **Camera Data** - Access camera pose, intrinsics, projection/view matrices

## Requirements

- React Native 0.78.0+
- Node 18.0.0+
- iOS 13.0+ (iOS 14.0+ for LiDAR depth features)

## Installation

```bash
npm install react-native-nitro-ar react-native-nitro-modules
```

### Expo

If you're using Expo, add the plugin to your `app.json`:

```json
{
  "expo": {
    "plugins": ["react-native-nitro-ar"]
  }
}
```

Then run prebuild:

```bash
npx expo prebuild
```

### Bare React Native

Add camera usage description to your `Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>This app uses the camera for AR experiences</string>
```

Then install pods:

```bash
cd ios && pod install
```

## Usage

### Basic Session

```typescript
import { createARSession } from "react-native-nitro-ar";

const session = createARSession();

// Start with default configuration
session.start();

// Or with custom configuration
session.start({
  planeDetection: ["horizontal", "vertical"],
  lightEstimation: true,
  environmentTexturing: "automatic",
  worldAlignment: "gravity",
});

// Pause/resume
session.pause();
session.start();

// Reset tracking
session.reset();
```

### Plane Detection

```typescript
// Get all detected planes
const planes = session.planeAnchors;

for (const plane of planes) {
  console.log("Plane:", plane.identifier);
  console.log("Classification:", plane.classification); // floor, wall, table, etc.
  console.log("Alignment:", plane.alignment); // horizontal or vertical
  console.log("Extent:", plane.extent); // [width, height]
  console.log("Center:", plane.center); // [x, y, z]

  // Access plane geometry for rendering
  const geo = plane.geometry;
  console.log("Vertices:", geo.vertices);
  console.log("Indices:", geo.triangleIndices);
}

// Subscribe to plane updates
const unsubscribe = session.onPlanesUpdated((added, updated, removedIds) => {
  console.log("Added planes:", added.length);
  console.log("Updated planes:", updated.length);
  console.log("Removed plane IDs:", removedIds);
});

// Later: unsubscribe()
```

### Raycasting

```typescript
// Simple raycast (normalized screen coordinates 0-1)
const hit = session.raycast(0.5, 0.5);

if (hit) {
  console.log("Hit position:", hit.position);
  console.log("Hit rotation:", hit.rotation);
  console.log("Distance:", hit.distance);

  // Create an anchor at the hit location
  const anchor = session.createAnchor(hit);
}

// Advanced raycast with options
const results = session.raycastWithQuery({
  x: 0.5,
  y: 0.5,
  target: "existingPlaneGeometry", // or 'existingPlaneInfinite', 'estimatedPlane', 'any'
  alignment: "horizontal", // or 'vertical', 'any'
});
```

### Anchors

```typescript
// Create anchor from raycast
const anchor = session.createAnchor(raycastResult);

// Create anchor at specific position
const anchor = session.createAnchorAtPosition(
  [0, 0, -1], // position [x, y, z]
  [0, 0, 0, 1], // rotation quaternion [x, y, z, w]
);

// Access anchor properties
console.log("ID:", anchor.identifier);
console.log("Position:", anchor.position);
console.log("Rotation:", anchor.rotation);
console.log("Is tracked:", anchor.isTracked);

// Remove anchor
session.removeAnchor(anchor);

// Subscribe to anchor updates
const unsubscribe = session.onAnchorsUpdated((added, updated, removedIds) => {
  // Handle anchor changes
});
```

### Measurements

```typescript
// Create measurement between two anchors
const measurement = session.createMeasurement(startAnchor, endAnchor);

console.log("Length (meters):", measurement.length);
console.log("Is valid:", measurement.isValid);
```

### Frame Updates

```typescript
// Subscribe to frame updates
const unsubscribe = session.onFrameUpdate((frame) => {
  console.log("Timestamp:", frame.timestamp);
  console.log("Camera position:", frame.cameraPosition);
  console.log("Camera rotation:", frame.cameraRotation);

  // Light estimation
  if (frame.lightEstimate) {
    console.log("Ambient intensity:", frame.lightEstimate.ambientIntensity);
    console.log("Color temperature:", frame.lightEstimate.ambientColorTemperature);
  }

  // Directional light (for realistic lighting)
  if (frame.directionalLightEstimate) {
    console.log("Light direction:", frame.directionalLightEstimate.primaryLightDirection);
    console.log(
      "Spherical harmonics:",
      frame.directionalLightEstimate.sphericalHarmonicsCoefficients,
    );
  }

  // LiDAR depth (iOS 14+, devices with LiDAR)
  if (frame.sceneDepth) {
    const depth = frame.sceneDepth;
    console.log("Depth map size:", depth.width, "x", depth.height);

    // Get depth at specific point
    const depthValue = depth.getDepthAt(0.5, 0.5);
    const confidence = depth.getConfidenceAt(0.5, 0.5);
  }

  // Capture camera image
  const base64Image = frame.getCapturedImage(0.8); // quality 0-1
});
```

### Tracking State

```typescript
// Check current state
console.log("Is running:", session.isRunning);
console.log("Tracking state:", session.trackingState); // 'normal', 'limited', 'notAvailable'
console.log("Tracking reason:", session.trackingStateReason); // 'none', 'initializing', 'excessiveMotion', etc.
console.log("World mapping:", session.worldMappingStatus); // 'notAvailable', 'limited', 'extending', 'mapped'

// Subscribe to tracking changes
const unsubscribe = session.onTrackingStateChanged((state, reason) => {
  if (state === "limited") {
    console.log("Tracking limited:", reason);
  }
});
```

### World Map Persistence

```typescript
// Save world map (for relocalization later)
const worldMap = await session.getCurrentWorldMap();
const mapData = worldMap.getData(); // base64 encoded

// Store mapData somewhere (file, cloud, etc.)
await saveToStorage(mapData);

// Later: restore session with saved map
const savedMapData = await loadFromStorage();
session.start({
  initialWorldMap: savedMapData,
});
```

### Bounding Box Builder

```typescript
import { createARBoundingBoxBuilder } from "react-native-nitro-ar";

const builder = createARBoundingBoxBuilder();

// Add points (from raycasts, anchors, etc.)
builder.addPoint([x, y, z]);
builder.addPoints([
  [x1, y1, z1],
  [x2, y2, z2],
  [x3, y3, z3],
]);

// Get oriented bounding box (uses PCA for optimal orientation)
const obb = builder.getOrientedBoundingBox();
console.log("Center:", obb.center);
console.log("Half extents:", obb.halfExtents);
console.log("Axes:", obb.axes); // 3 orthogonal direction vectors

// Reset for new calculation
builder.clear();
```

## API Reference

### ARSession

| Property/Method                     | Type                  | Description                       |
| ----------------------------------- | --------------------- | --------------------------------- |
| `start(config?)`                    | `void`                | Start AR session                  |
| `pause()`                           | `void`                | Pause AR session                  |
| `reset()`                           | `void`                | Reset tracking and remove anchors |
| `isRunning`                         | `boolean`             | Session running state             |
| `trackingState`                     | `TrackingState`       | Current tracking quality          |
| `trackingStateReason`               | `TrackingStateReason` | Reason for limited tracking       |
| `worldMappingStatus`                | `WorldMappingStatus`  | World map quality                 |
| `getCameraPose()`                   | `CameraPose`          | Current camera position/rotation  |
| `currentFrame`                      | `ARFrame?`            | Latest frame data                 |
| `raycast(x, y)`                     | `ARRaycastResult?`    | Hit-test at screen point          |
| `raycastWithQuery(query)`           | `ARRaycastResult[]`   | Advanced hit-test                 |
| `createAnchor(hit)`                 | `ARAnchor`            | Create anchor from raycast        |
| `createAnchorAtPosition(pos, rot?)` | `ARAnchor`            | Create anchor at position         |
| `removeAnchor(anchor)`              | `void`                | Remove anchor                     |
| `anchors`                           | `ARAnchor[]`          | All anchors                       |
| `planeAnchors`                      | `ARPlaneAnchor[]`     | Detected planes                   |
| `createMeasurement(start, end)`     | `ARMeasurement`       | Measure between anchors           |
| `getCurrentWorldMap()`              | `Promise<ARWorldMap>` | Get world map for persistence     |
| `onFrameUpdate(callback)`           | `() => void`          | Subscribe to frame updates        |
| `onTrackingStateChanged(callback)`  | `() => void`          | Subscribe to tracking changes     |
| `onAnchorsUpdated(callback)`        | `() => void`          | Subscribe to anchor changes       |
| `onPlanesUpdated(callback)`         | `() => void`          | Subscribe to plane changes        |

### ARSessionConfiguration

| Property               | Type                    | Default                      | Description                 |
| ---------------------- | ----------------------- | ---------------------------- | --------------------------- |
| `planeDetection`       | `PlaneDetectionMode[]?` | `['horizontal', 'vertical']` | Planes to detect            |
| `lightEstimation`      | `boolean?`              | `true`                       | Enable light estimation     |
| `environmentTexturing` | `EnvironmentTexturing?` | -                            | Environment texturing mode  |
| `worldAlignment`       | `WorldAlignment?`       | `'gravity'`                  | World coordinate alignment  |
| `sceneDepth`           | `boolean?`              | `false`                      | Enable LiDAR depth          |
| `smoothedSceneDepth`   | `boolean?`              | `false`                      | Enable smoothed depth       |
| `initialWorldMap`      | `string?`               | -                            | Base64 world map to restore |

## Development

```bash
# Install dependencies
bun install

# Run codegen (generates Nitro bridge code)
bun run codegen

# Type check and build
bun run build
```

To run the example app:

```bash
# from root
bun link
cd example
bun install
bun run ios --device
```

Physical devices are required.

## License

[MIT](./LICENSE)
