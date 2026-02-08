import { StatusBar } from "expo-status-bar";
import { useCallback, useEffect, useRef, useState } from "react";
import {
  Animated,
  Easing,
  type GestureResponderEvent,
  type LayoutChangeEvent,
  Platform,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from "react-native";
import { type ARObjectMeasurement, ARView, type ARViewMethods } from "react-native-nitro-ar";
import { callback } from "react-native-nitro-modules";

type MeasureMode = "line" | "box" | "object";

type BoxDimension = "width" | "height" | "depth";

interface BoxMeasurement {
  width: number | null;
  height: number | null;
  depth: number | null;
}

interface MeasurementPoint {
  id: string;
  x: number;
  y: number;
  z: number;
}

interface Measurement {
  startPoint: MeasurementPoint;
  endPoint: MeasurementPoint;
  distance: number;
  distanceAway: number;
  angle: number;
}

// Pure utility functions
const calculateDistance = (p1: MeasurementPoint, p2: MeasurementPoint): number => {
  return Math.sqrt((p2.x - p1.x) ** 2 + (p2.y - p1.y) ** 2 + (p2.z - p1.z) ** 2);
};

const calculateDistanceFromCamera = (p: { x: number; y: number; z: number }): number => {
  return Math.sqrt(p.x ** 2 + p.y ** 2 + p.z ** 2);
};

const calculateAngle = (p1: MeasurementPoint, p2: MeasurementPoint): number => {
  const dx = p2.x - p1.x;
  const dy = p2.y - p1.y;
  const dz = p2.z - p1.z;
  const horizontalDistance = Math.sqrt(dx ** 2 + dz ** 2);
  const angleRad = Math.atan2(dy, horizontalDistance);
  return Math.abs(angleRad * (180 / Math.PI));
};

const formatDistance = (meters: number): { imperial: string; metric: string } => {
  const inches = meters * 39.3701;
  const cm = meters * 100;

  let imperial: string;
  if (inches >= 12) {
    const feet = Math.floor(inches / 12);
    const remainingInches = Math.round(inches % 12);
    imperial = remainingInches > 0 ? `${feet}'${remainingInches}"` : `${feet}'`;
  } else {
    imperial = `${Math.round(inches)}"`;
  }

  let metric: string;
  if (cm >= 100) {
    metric = `${(cm / 100).toFixed(2)} m`;
  } else {
    metric = `${Math.round(cm)} cm`;
  }

  return { imperial, metric };
};

// Calculate distance between two 3D points
const calculateDistanceRaw = (
  p1: { x: number; y: number; z: number },
  p2: { x: number; y: number; z: number }
): number => {
  return Math.sqrt((p2.x - p1.x) ** 2 + (p2.y - p1.y) ** 2 + (p2.z - p1.z) ** 2);
};

const getDimensionLabel = (dim: BoxDimension): string => {
  switch (dim) {
    case "width":
      return "Width";
    case "height":
      return "Height";
    case "depth":
      return "Depth";
  }
};

const getNextDimension = (current: BoxDimension): BoxDimension | null => {
  switch (current) {
    case "width":
      return "height";
    case "height":
      return "depth";
    case "depth":
      return null;
  }
};

const boxDimensionColors: Record<BoxDimension, string> = {
  width: "#FF6B6B",
  height: "#4ECDC4",
  depth: "#45B7D1",
};

export default function App() {
  const arViewRef = useRef<ARViewMethods | null>(null);
  const [isRunning, setIsRunning] = useState(false);
  const [points, setPoints] = useState<MeasurementPoint[]>([]);
  const [currentMeasurement, setCurrentMeasurement] = useState<Measurement | null>(null);
  const [showMeasurementCard, setShowMeasurementCard] = useState(false);
  const [hasSurface, setHasSurface] = useState(false);
  const [liveDistance, setLiveDistance] = useState<number | null>(null);
  const [currentHitPoint, setCurrentHitPoint] = useState<{
    x: number;
    y: number;
    z: number;
  } | null>(null);

  // LiDAR state
  const [hasLiDAR, setHasLiDAR] = useState(false);
  const [showMesh, setShowMesh] = useState(false);

  // Measurement mode
  const [measureMode, setMeasureMode] = useState<MeasureMode>("line");
  const [objectMeasurement, setObjectMeasurement] = useState<ARObjectMeasurement | null>(null);
  const [isMeasuringObject, setIsMeasuringObject] = useState(false);
  const [viewLayout, setViewLayout] = useState({ width: 0, height: 0 });
  const [objectMeasureStatus, setObjectMeasureStatus] = useState<string | null>(null);

  // Box measurement mode
  const [boxMeasurement, setBoxMeasurement] = useState<BoxMeasurement>({
    width: null,
    height: null,
    depth: null,
  });
  const [currentBoxDimension, setCurrentBoxDimension] = useState<BoxDimension>("width");
  const [boxPoints, setBoxPoints] = useState<MeasurementPoint[]>([]);

  // Animation for the reticle
  const rotateAnim = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    if (isRunning) {
      // Continuous rotation animation for the reticle
      const animation = Animated.loop(
        Animated.timing(rotateAnim, {
          toValue: 1,
          duration: 2000,
          easing: Easing.linear,
          useNativeDriver: true,
        })
      );
      animation.start();
      return () => animation.stop();
    }
  }, [isRunning, rotateAnim]);

  // Check for surface at center and calculate live distance
  useEffect(() => {
    if (!isRunning) return;

    const liveLineId = "live_preview_line";

    const interval = setInterval(() => {
      const arView = arViewRef.current;
      if (!arView) return;

      // Check center of screen for surface
      const hit = arView.raycast(0.5, 0.5);
      setHasSurface(!!hit);
      setCurrentHitPoint(hit ?? null);

      // Calculate live distance for line mode
      if (measureMode === "line" && hit && points.length === 1) {
        const distance = calculateDistanceRaw(points[0], hit);
        setLiveDistance(distance);
        const p1 = points[0];
        arView.addLine(liveLineId, p1.x, p1.y, p1.z, hit.x, hit.y, hit.z, "#FFFFFF");
      }
      // Calculate live distance for box mode
      else if (measureMode === "box" && hit && boxPoints.length === 1) {
        const distance = calculateDistanceRaw(boxPoints[0], hit);
        setLiveDistance(distance);
        const p1 = boxPoints[0];
        arView.addLine(
          liveLineId,
          p1.x,
          p1.y,
          p1.z,
          hit.x,
          hit.y,
          hit.z,
          boxDimensionColors[currentBoxDimension]
        );
      } else {
        setLiveDistance(null);
        // Remove preview line when not measuring
        if (points.length !== 1 && boxPoints.length !== 1) {
          arView.removeLine(liveLineId);
        }
      }
    }, 50);

    return () => {
      clearInterval(interval);
      const arView = arViewRef.current;
      if (arView) {
        arView.removeLine(liveLineId);
      }
    };
  }, [isRunning, points, boxPoints, measureMode, currentBoxDimension]);

  const startSession = useCallback(() => {
    const arView = arViewRef.current;
    if (!arView) return;

    try {
      // Check for LiDAR support BEFORE starting session
      const lidarAvailable = arView.isLiDARAvailable();
      setHasLiDAR(lidarAvailable);
      if (lidarAvailable) {
        console.log("LiDAR detected - enabling scene reconstruction and depth");
      }

      // Start the session - but we need to wait for the sceneDepth prop to update
      // Use a small delay to ensure React has updated the props
      setTimeout(() => {
        console.log("Starting AR session with LiDAR:", lidarAvailable);
        arView.startSession();
        setIsRunning(true);
      }, 100);
    } catch (e) {
      console.error("Error starting session:", e);
    }
  }, []);

  const clearMeasurements = useCallback(() => {
    const arView = arViewRef.current;
    if (!arView) return;

    arView.clearAllVisuals();
    setPoints([]);
    setCurrentMeasurement(null);
    setShowMeasurementCard(false);
  }, []);

  const undoLastPoint = useCallback(() => {
    const arView = arViewRef.current;
    if (!arView || points.length === 0) return;

    // Remove last point visualization
    const lastPoint = points[points.length - 1];
    arView.removeMeasurementPoint(lastPoint.id);

    // If we had 2 points, we need to remove the line and label too
    if (points.length >= 2) {
      // Clear all and re-add remaining points
      arView.clearAllVisuals();
      const remainingPoints = points.slice(0, -1);
      remainingPoints.forEach((p) => {
        arView.addMeasurementPoint(p.id, p.x, p.y, p.z, "#FFEB3B");
      });
      setCurrentMeasurement(null);
      setShowMeasurementCard(false);
    }

    setPoints(points.slice(0, -1));
  }, [points]);

  const addPointAtCenter = useCallback(() => {
    const arView = arViewRef.current;
    if (!arView || !isRunning) return;

    try {
      // Raycast from center of screen
      const hit = arView.raycast(0.5, 0.5);

      if (hit) {
        const pointId = `point_${Date.now()}`;
        const newPoint: MeasurementPoint = {
          id: pointId,
          x: hit.x,
          y: hit.y,
          z: hit.z,
        };

        // Add measurement point visualization
        arView.addMeasurementPoint(pointId, hit.x, hit.y, hit.z, "#FFEB3B");

        const newPoints = [...points, newPoint];
        setPoints(newPoints);

        // If we have 2 points, create a measurement
        if (newPoints.length >= 2) {
          const p1 = newPoints[newPoints.length - 2];
          const p2 = newPoints[newPoints.length - 1];

          // Remove the preview line
          arView.removeLine("live_preview_line");

          const distance = calculateDistance(p1, p2);
          const midPoint = {
            x: (p1.x + p2.x) / 2,
            y: (p1.y + p2.y) / 2,
            z: (p1.z + p2.z) / 2,
          };
          const distanceAway = calculateDistanceFromCamera(midPoint);
          const angle = calculateAngle(p1, p2);

          // Draw final line
          const lineId = `line_${Date.now()}`;
          arView.addLine(lineId, p1.x, p1.y, p1.z, p2.x, p2.y, p2.z, "#FFFFFF");

          setCurrentMeasurement({
            startPoint: p1,
            endPoint: p2,
            distance,
            distanceAway,
            angle,
          });
          setShowMeasurementCard(true);
        }
      }
    } catch (e) {
      console.error("Error adding point:", e);
    }
  }, [isRunning, points]);

  const closeMeasurementCard = useCallback(() => {
    setShowMeasurementCard(false);
    setObjectMeasurement(null);
  }, []);

  // Box measurement functions
  const addBoxPointAtCenter = useCallback(() => {
    const arView = arViewRef.current;
    if (!arView || !isRunning) return;

    try {
      const hit = arView.raycast(0.5, 0.5);

      if (hit) {
        const pointId = `box_point_${Date.now()}`;
        const newPoint: MeasurementPoint = {
          id: pointId,
          x: hit.x,
          y: hit.y,
          z: hit.z,
        };

        // Add measurement point visualization with dimension-specific color
        arView.addMeasurementPoint(
          pointId,
          hit.x,
          hit.y,
          hit.z,
          boxDimensionColors[currentBoxDimension]
        );

        const newBoxPoints = [...boxPoints, newPoint];
        setBoxPoints(newBoxPoints);

        // If we have 2 points, complete this dimension
        if (newBoxPoints.length === 2) {
          const p1 = newBoxPoints[0];
          const p2 = newBoxPoints[1];
          const distance = calculateDistance(p1, p2);

          // Remove the preview line
          arView.removeLine("live_preview_line");

          // Draw the measurement line
          const lineId = `box_line_${currentBoxDimension}`;
          arView.addLine(
            lineId,
            p1.x,
            p1.y,
            p1.z,
            p2.x,
            p2.y,
            p2.z,
            boxDimensionColors[currentBoxDimension]
          );

          // Update box measurement
          setBoxMeasurement((prev) => ({
            ...prev,
            [currentBoxDimension]: distance,
          }));

          // Move to next dimension or show results
          const nextDim = getNextDimension(currentBoxDimension);
          if (nextDim) {
            setCurrentBoxDimension(nextDim);
            setBoxPoints([]);
          } else {
            // All dimensions measured - show results
            setShowMeasurementCard(true);
          }
        }
      }
    } catch (e) {
      console.error("Error adding box point:", e);
    }
  }, [isRunning, boxPoints, currentBoxDimension]);

  const clearBoxMeasurement = useCallback(() => {
    const arView = arViewRef.current;
    if (!arView) return;

    arView.clearAllVisuals();
    setBoxMeasurement({ width: null, height: null, depth: null });
    setCurrentBoxDimension("width");
    setBoxPoints([]);
    setShowMeasurementCard(false);
  }, []);

  const undoBoxPoint = useCallback(() => {
    const arView = arViewRef.current;
    if (!arView) return;

    if (boxPoints.length > 0) {
      // Remove last point
      const lastPoint = boxPoints[boxPoints.length - 1];
      arView.removeMeasurementPoint(lastPoint.id);
      setBoxPoints(boxPoints.slice(0, -1));
    } else if (currentBoxDimension !== "width") {
      // Go back to previous dimension
      const prevDim: BoxDimension = currentBoxDimension === "depth" ? "height" : "width";
      arView.removeLine(`box_line_${prevDim}`);
      setBoxMeasurement((prev) => ({ ...prev, [prevDim]: null }));
      setCurrentBoxDimension(prevDim);
    }
  }, [boxPoints, currentBoxDimension]);

  // Handle layout changes to get accurate view dimensions
  const handleLayout = useCallback((event: LayoutChangeEvent) => {
    const { width, height } = event.nativeEvent.layout;
    setViewLayout({ width, height });
  }, []);

  // Handle tap for object measurement
  const handleObjectMeasure = useCallback(
    async (event: GestureResponderEvent) => {
      const arView = arViewRef.current;
      if (!arView || !isRunning || measureMode !== "object" || isMeasuringObject) return;

      // Get normalized coordinates from touch
      const { locationX, locationY } = event.nativeEvent;

      // Use tracked view dimensions, fallback to reasonable defaults
      const viewWidth = viewLayout.width > 0 ? viewLayout.width : 390;
      const viewHeight = viewLayout.height > 0 ? viewLayout.height : 844;
      const normalizedX = locationX / viewWidth;
      const normalizedY = locationY / viewHeight;

      console.log(
        `[ObjectMeasure] Tap at (${locationX.toFixed(0)}, ${locationY.toFixed(0)}) -> normalized (${normalizedX.toFixed(3)}, ${normalizedY.toFixed(3)})`
      );
      console.log(`[ObjectMeasure] View dimensions: ${viewWidth} x ${viewHeight}`);

      setIsMeasuringObject(true);
      setObjectMeasureStatus("Analyzing...");
      try {
        console.log("[ObjectMeasure] Calling measureObject...");
        const result = await arView.measureObject(normalizedX, normalizedY);
        console.log("[ObjectMeasure] Result:", result);
        if (result) {
          setObjectMeasurement(result);
          setShowMeasurementCard(true);
          setObjectMeasureStatus(null);
        } else {
          setObjectMeasureStatus("No object detected. Try tapping directly on an object.");
          setTimeout(() => setObjectMeasureStatus(null), 3000);
        }
      } catch (e) {
        console.error("[ObjectMeasure] Error:", e);
        setObjectMeasureStatus(`Error: ${e}`);
        setTimeout(() => setObjectMeasureStatus(null), 3000);
      } finally {
        setIsMeasuringObject(false);
      }
    },
    [isRunning, measureMode, isMeasuringObject, viewLayout]
  );

  if (Platform.OS !== "ios") {
    return (
      <View style={styles.container}>
        <Text style={styles.title}>AR is only available on iOS</Text>
        <StatusBar style="auto" />
      </View>
    );
  }

  const distanceDisplay = currentMeasurement ? formatDistance(currentMeasurement.distance) : null;
  const distanceAwayDisplay = currentMeasurement
    ? formatDistance(currentMeasurement.distanceAway)
    : null;

  const rotateInterpolate = rotateAnim.interpolate({
    inputRange: [0, 1],
    outputRange: ["0deg", "360deg"],
  });

  return (
    <View style={styles.container}>
      <StatusBar style="light" />

      <ARView
        style={styles.arView}
        showPlanes={true}
        showFeaturePoints={false}
        autoenablesDefaultLighting={true}
        // LiDAR features (only work on devices with LiDAR)
        sceneReconstruction={hasLiDAR ? "mesh" : undefined}
        showSceneMesh={showMesh}
        sceneDepth={hasLiDAR}
        hybridRef={callback((ref) => {
          arViewRef.current = ref;
        })}
        onLayout={handleLayout}
        onTouchEnd={measureMode === "object" ? handleObjectMeasure : undefined}
      />

      {/* Top toolbar */}
      <View style={styles.topToolbar}>
        <TouchableOpacity style={styles.toolbarButton}>
          <Text style={styles.toolbarIcon}>☰</Text>
        </TouchableOpacity>
        <View style={styles.toolbarSpacer} />
        <TouchableOpacity style={styles.toolbarButton} onPress={clearMeasurements}>
          <Text style={styles.toolbarIcon}>🗑</Text>
        </TouchableOpacity>
      </View>

      {/* Center reticle (line and box modes) */}
      {isRunning && !showMeasurementCard && (measureMode === "line" || measureMode === "box") && (
        <View style={styles.reticleContainer}>
          {/* Outer rotating circle */}
          <Animated.View
            style={[
              styles.reticleOuter,
              {
                transform: [{ rotate: rotateInterpolate }],
                borderColor: hasSurface ? "#FFFFFF" : "rgba(255, 255, 255, 0.4)",
              },
            ]}
          />
          {/* Center dot */}
          <View
            style={[
              styles.reticleDot,
              {
                backgroundColor: hasSurface ? "#FFFFFF" : "rgba(255, 255, 255, 0.4)",
              },
            ]}
          />
          {/* Live distance label when measuring */}
          {liveDistance !== null && currentHitPoint && (
            <View style={styles.liveDistanceLabel}>
              <Text style={styles.liveDistanceText}>{formatDistance(liveDistance).imperial}</Text>
            </View>
          )}
        </View>
      )}

      {/* Box mode instruction */}
      {isRunning && !showMeasurementCard && measureMode === "box" && (
        <View style={styles.boxModeContainer}>
          {/* Progress indicator */}
          <View style={styles.boxProgressRow}>
            <View
              style={[
                styles.boxProgressItem,
                boxMeasurement.width !== null && styles.boxProgressItemComplete,
                currentBoxDimension === "width" && styles.boxProgressItemActive,
              ]}
            >
              <View
                style={[styles.boxProgressDot, { backgroundColor: boxDimensionColors.width }]}
              />
              <Text style={styles.boxProgressText}>W</Text>
            </View>
            <View style={styles.boxProgressConnector} />
            <View
              style={[
                styles.boxProgressItem,
                boxMeasurement.height !== null && styles.boxProgressItemComplete,
                currentBoxDimension === "height" && styles.boxProgressItemActive,
              ]}
            >
              <View
                style={[styles.boxProgressDot, { backgroundColor: boxDimensionColors.height }]}
              />
              <Text style={styles.boxProgressText}>H</Text>
            </View>
            <View style={styles.boxProgressConnector} />
            <View
              style={[
                styles.boxProgressItem,
                boxMeasurement.depth !== null && styles.boxProgressItemComplete,
                currentBoxDimension === "depth" && styles.boxProgressItemActive,
              ]}
            >
              <View
                style={[styles.boxProgressDot, { backgroundColor: boxDimensionColors.depth }]}
              />
              <Text style={styles.boxProgressText}>D</Text>
            </View>
          </View>

          {/* Current instruction */}
          <View style={styles.boxModeInstruction}>
            <View
              style={[
                styles.dimensionIndicator,
                { backgroundColor: boxDimensionColors[currentBoxDimension] },
              ]}
            />
            <Text style={styles.boxModeText}>
              Measure {getDimensionLabel(currentBoxDimension)}
              {boxPoints.length === 1 ? " - Place second point" : " - Place first point"}
            </Text>
          </View>
        </View>
      )}

      {/* Object mode instruction */}
      {isRunning && !showMeasurementCard && measureMode === "object" && (
        <View style={styles.objectModeInstruction}>
          <Text style={styles.objectModeText}>
            {objectMeasureStatus ??
              (isMeasuringObject ? "Analyzing..." : "Tap on an object to measure")}
          </Text>
        </View>
      )}

      {/* Start button when not running */}
      {!isRunning && (
        <View style={styles.startContainer}>
          <TouchableOpacity style={styles.startButton} onPress={startSession}>
            <Text style={styles.startButtonText}>Start AR</Text>
          </TouchableOpacity>
        </View>
      )}

      {/* Bottom controls (line mode) */}
      {isRunning && !showMeasurementCard && measureMode === "line" && (
        <View style={styles.bottomControls}>
          <TouchableOpacity
            style={[styles.controlButton, points.length === 0 && styles.controlButtonDisabled]}
            onPress={undoLastPoint}
            disabled={points.length === 0}
          >
            <Text style={styles.undoIcon}>↩</Text>
          </TouchableOpacity>

          <TouchableOpacity
            style={[styles.addButton, !hasSurface && styles.addButtonDisabled]}
            onPress={addPointAtCenter}
            disabled={!hasSurface}
          >
            <Text style={styles.addButtonIcon}>+</Text>
          </TouchableOpacity>

          <TouchableOpacity style={styles.controlButton}>
            <View style={styles.screenshotIcon} />
          </TouchableOpacity>
        </View>
      )}

      {/* Bottom controls (box mode) */}
      {isRunning && !showMeasurementCard && measureMode === "box" && (
        <View style={styles.bottomControls}>
          <TouchableOpacity
            style={[
              styles.controlButton,
              boxPoints.length === 0 &&
                currentBoxDimension === "width" &&
                styles.controlButtonDisabled,
            ]}
            onPress={undoBoxPoint}
            disabled={boxPoints.length === 0 && currentBoxDimension === "width"}
          >
            <Text style={styles.undoIcon}>↩</Text>
          </TouchableOpacity>

          <TouchableOpacity
            style={[styles.addButton, !hasSurface && styles.addButtonDisabled]}
            onPress={addBoxPointAtCenter}
            disabled={!hasSurface}
          >
            <Text style={styles.addButtonIcon}>+</Text>
          </TouchableOpacity>

          <TouchableOpacity style={styles.controlButton} onPress={clearBoxMeasurement}>
            <Text style={styles.undoIcon}>🗑</Text>
          </TouchableOpacity>
        </View>
      )}

      {/* Mode selector (Line/Box/Object) */}
      {isRunning && (
        <View style={styles.modeSelector}>
          <View style={styles.modeSelectorInner}>
            <TouchableOpacity
              style={[styles.modeButton, measureMode === "line" && styles.modeButtonActive]}
              onPress={() => setMeasureMode("line")}
            >
              <Text style={styles.modeIcon}>📏</Text>
              <Text style={measureMode === "line" ? styles.modeText : styles.modeTextInactive}>
                Line
              </Text>
            </TouchableOpacity>
            <TouchableOpacity
              style={[styles.modeButton, measureMode === "box" && styles.modeButtonActive]}
              onPress={() => setMeasureMode("box")}
            >
              <Text style={styles.modeIcon}>📦</Text>
              <Text style={measureMode === "box" ? styles.modeText : styles.modeTextInactive}>
                Box
              </Text>
            </TouchableOpacity>
            <TouchableOpacity
              style={[styles.modeButton, measureMode === "object" && styles.modeButtonActive]}
              onPress={() => setMeasureMode("object")}
              disabled={!hasLiDAR}
            >
              <Text style={[styles.modeIcon, !hasLiDAR && styles.modeIconDisabled]}>🔍</Text>
              <Text
                style={[
                  measureMode === "object" ? styles.modeText : styles.modeTextInactive,
                  !hasLiDAR && styles.modeTextDisabled,
                ]}
              >
                Auto
              </Text>
            </TouchableOpacity>
          </View>
        </View>
      )}

      {/* Line Measurement card overlay */}
      {showMeasurementCard && currentMeasurement && distanceDisplay && distanceAwayDisplay && (
        <View style={styles.measurementCard}>
          <View style={styles.cardHandle} />

          <View style={styles.cardHeader}>
            <Text style={styles.cardTitle}>Measurement</Text>
            <TouchableOpacity style={styles.closeButton} onPress={closeMeasurementCard}>
              <Text style={styles.closeButtonText}>✕</Text>
            </TouchableOpacity>
          </View>

          {/* Visual line representation */}
          <View style={styles.lineVisual}>
            <View style={styles.lineDot} />
            <View style={styles.lineBar} />
            <View style={styles.lineDot} />
          </View>

          {/* Main measurement */}
          <View style={styles.mainMeasurement}>
            <Text style={styles.mainMeasurementValue}>{distanceDisplay.imperial}</Text>
            <Text style={styles.mainMeasurementMetric}>{distanceDisplay.metric}</Text>
          </View>

          {/* Distance away */}
          <View style={styles.measurementRow}>
            <Text style={styles.measurementLabel}>Distance Away</Text>
          </View>
          <View style={styles.measurementValues}>
            <Text style={styles.measurementValueLarge}>{distanceAwayDisplay.imperial}</Text>
            <Text style={styles.measurementValueSmall}>{distanceAwayDisplay.metric}</Text>
          </View>

          {/* Angle */}
          <View style={styles.measurementRow}>
            <Text style={styles.measurementLabel}>Angle</Text>
          </View>
          <View style={styles.measurementValues}>
            <Text style={styles.measurementValueLarge}>
              {Math.round(currentMeasurement.angle)}°
            </Text>
          </View>

          {/* Copy button */}
          <TouchableOpacity style={styles.copyButton}>
            <Text style={styles.copyButtonText}>Copy</Text>
          </TouchableOpacity>

          {/* New measurement button */}
          <TouchableOpacity style={styles.newMeasurementButton} onPress={clearMeasurements}>
            <Text style={styles.newMeasurementText}>New Measurement</Text>
          </TouchableOpacity>
        </View>
      )}

      {/* Box Measurement card overlay */}
      {showMeasurementCard &&
        measureMode === "box" &&
        boxMeasurement.width !== null &&
        boxMeasurement.height !== null &&
        boxMeasurement.depth !== null && (
          <View style={styles.measurementCard}>
            <View style={styles.cardHandle} />

            <View style={styles.cardHeader}>
              <Text style={styles.cardTitle}>Box Dimensions</Text>
              <TouchableOpacity style={styles.closeButton} onPress={clearBoxMeasurement}>
                <Text style={styles.closeButtonText}>✕</Text>
              </TouchableOpacity>
            </View>

            {/* Visual box representation */}
            <View style={styles.boxVisual}>
              <Text style={styles.boxIcon}>📦</Text>
            </View>

            {/* Dimensions grid */}
            <View style={styles.dimensionsGrid}>
              <View
                style={[
                  styles.dimensionItem,
                  { borderLeftColor: boxDimensionColors.width, borderLeftWidth: 3 },
                ]}
              >
                <Text style={styles.dimensionLabel}>Width</Text>
                <Text style={styles.dimensionValue}>
                  {formatDistance(boxMeasurement.width).imperial}
                </Text>
                <Text style={styles.dimensionMetric}>
                  {formatDistance(boxMeasurement.width).metric}
                </Text>
              </View>
              <View
                style={[
                  styles.dimensionItem,
                  { borderLeftColor: boxDimensionColors.height, borderLeftWidth: 3 },
                ]}
              >
                <Text style={styles.dimensionLabel}>Height</Text>
                <Text style={styles.dimensionValue}>
                  {formatDistance(boxMeasurement.height).imperial}
                </Text>
                <Text style={styles.dimensionMetric}>
                  {formatDistance(boxMeasurement.height).metric}
                </Text>
              </View>
              <View
                style={[
                  styles.dimensionItem,
                  { borderLeftColor: boxDimensionColors.depth, borderLeftWidth: 3 },
                ]}
              >
                <Text style={styles.dimensionLabel}>Depth</Text>
                <Text style={styles.dimensionValue}>
                  {formatDistance(boxMeasurement.depth).imperial}
                </Text>
                <Text style={styles.dimensionMetric}>
                  {formatDistance(boxMeasurement.depth).metric}
                </Text>
              </View>
            </View>

            {/* Copy button */}
            <TouchableOpacity style={styles.copyButton}>
              <Text style={styles.copyButtonText}>Copy All</Text>
            </TouchableOpacity>

            {/* New measurement button */}
            <TouchableOpacity style={styles.newMeasurementButton} onPress={clearBoxMeasurement}>
              <Text style={styles.newMeasurementText}>New Box Measurement</Text>
            </TouchableOpacity>
          </View>
        )}

      {/* Object Measurement card overlay (Auto mode) */}
      {showMeasurementCard && objectMeasurement && (
        <View style={styles.measurementCard}>
          <View style={styles.cardHandle} />

          <View style={styles.cardHeader}>
            <Text style={styles.cardTitle}>Object Dimensions</Text>
            <TouchableOpacity style={styles.closeButton} onPress={closeMeasurementCard}>
              <Text style={styles.closeButtonText}>✕</Text>
            </TouchableOpacity>
          </View>

          {/* Visual box representation */}
          <View style={styles.boxVisual}>
            <Text style={styles.boxIcon}>📦</Text>
          </View>

          {/* Dimensions grid */}
          <View style={styles.dimensionsGrid}>
            <View style={styles.dimensionItem}>
              <Text style={styles.dimensionLabel}>Width</Text>
              <Text style={styles.dimensionValue}>
                {formatDistance(objectMeasurement.width).imperial}
              </Text>
              <Text style={styles.dimensionMetric}>
                {formatDistance(objectMeasurement.width).metric}
              </Text>
            </View>
            <View style={styles.dimensionItem}>
              <Text style={styles.dimensionLabel}>Height</Text>
              <Text style={styles.dimensionValue}>
                {formatDistance(objectMeasurement.height).imperial}
              </Text>
              <Text style={styles.dimensionMetric}>
                {formatDistance(objectMeasurement.height).metric}
              </Text>
            </View>
            <View style={styles.dimensionItem}>
              <Text style={styles.dimensionLabel}>Depth</Text>
              <Text style={styles.dimensionValue}>
                {formatDistance(objectMeasurement.depth).imperial}
              </Text>
              <Text style={styles.dimensionMetric}>
                {formatDistance(objectMeasurement.depth).metric}
              </Text>
            </View>
          </View>

          {/* Confidence indicator */}
          <View style={styles.confidenceRow}>
            <Text style={styles.confidenceLabel}>Confidence</Text>
            <Text style={styles.confidenceValue}>
              {Math.round(objectMeasurement.confidence * 100)}%
            </Text>
          </View>

          {/* Point count info */}
          <View style={styles.infoRow}>
            <Text style={styles.infoText}>
              Based on {Math.round(objectMeasurement.pointCount)} depth points
            </Text>
          </View>

          {/* New measurement button */}
          <TouchableOpacity
            style={styles.newMeasurementButton}
            onPress={() => {
              setObjectMeasurement(null);
              setShowMeasurementCard(false);
            }}
          >
            <Text style={styles.newMeasurementText}>Measure Another Object</Text>
          </TouchableOpacity>
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: "#000",
  },
  arView: {
    ...StyleSheet.absoluteFillObject,
  },
  topToolbar: {
    position: "absolute",
    top: 60,
    left: 20,
    right: 20,
    flexDirection: "row",
    alignItems: "center",
  },
  toolbarButton: {
    width: 44,
    height: 44,
    borderRadius: 22,
    backgroundColor: "rgba(60, 60, 60, 0.8)",
    alignItems: "center",
    justifyContent: "center",
  },
  toolbarIcon: {
    fontSize: 20,
    color: "#fff",
  },
  toolbarSpacer: {
    flex: 1,
  },
  startContainer: {
    position: "absolute",
    bottom: 100,
    left: 0,
    right: 0,
    alignItems: "center",
  },
  startButton: {
    backgroundColor: "#007AFF",
    paddingHorizontal: 40,
    paddingVertical: 16,
    borderRadius: 12,
  },
  startButtonText: {
    color: "#fff",
    fontSize: 18,
    fontWeight: "600",
  },
  // Reticle styles
  reticleContainer: {
    position: "absolute",
    top: "50%",
    left: "50%",
    marginTop: -40,
    marginLeft: -40,
    width: 80,
    height: 80,
    alignItems: "center",
    justifyContent: "center",
  },
  reticleOuter: {
    position: "absolute",
    width: 80,
    height: 80,
    borderRadius: 40,
    borderWidth: 3,
    borderColor: "#FFFFFF",
    // Gap at bottom using border style trick
    borderBottomColor: "transparent",
    borderRightColor: "transparent",
  },
  reticleDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: "#FFFFFF",
  },
  liveDistanceLabel: {
    position: "absolute",
    bottom: -50,
    backgroundColor: "rgba(0, 0, 0, 0.75)",
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 20,
  },
  liveDistanceText: {
    color: "#FFFFFF",
    fontSize: 20,
    fontWeight: "600",
  },
  // Bottom controls
  bottomControls: {
    position: "absolute",
    bottom: 120,
    left: 0,
    right: 0,
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    paddingHorizontal: 40,
  },
  controlButton: {
    width: 60,
    height: 60,
    borderRadius: 30,
    backgroundColor: "rgba(60, 60, 60, 0.8)",
    alignItems: "center",
    justifyContent: "center",
    marginHorizontal: 20,
  },
  controlButtonDisabled: {
    opacity: 0.4,
  },
  undoIcon: {
    fontSize: 24,
    color: "#fff",
  },
  addButton: {
    width: 70,
    height: 70,
    borderRadius: 35,
    backgroundColor: "rgba(80, 80, 80, 0.9)",
    alignItems: "center",
    justifyContent: "center",
    marginHorizontal: 20,
  },
  addButtonDisabled: {
    opacity: 0.5,
  },
  addButtonIcon: {
    fontSize: 40,
    color: "#fff",
    fontWeight: "300",
    marginTop: -2,
  },
  screenshotIcon: {
    width: 24,
    height: 24,
    borderRadius: 4,
    borderWidth: 2,
    borderColor: "#fff",
  },
  // Mode selector
  modeSelector: {
    position: "absolute",
    bottom: 40,
    left: 0,
    right: 0,
    alignItems: "center",
  },
  modeSelectorInner: {
    flexDirection: "row",
    backgroundColor: "rgba(60, 60, 60, 0.9)",
    borderRadius: 25,
    padding: 4,
  },
  modeButton: {
    flexDirection: "row",
    alignItems: "center",
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 20,
  },
  modeButtonActive: {
    backgroundColor: "rgba(100, 100, 100, 0.8)",
  },
  modeIcon: {
    fontSize: 16,
    marginRight: 6,
  },
  modeText: {
    color: "#fff",
    fontSize: 14,
    fontWeight: "500",
  },
  modeTextInactive: {
    color: "rgba(255, 255, 255, 0.6)",
    fontSize: 14,
    fontWeight: "500",
  },
  modeIconDisabled: {
    opacity: 0.4,
  },
  modeTextDisabled: {
    opacity: 0.4,
  },
  boxModeContainer: {
    position: "absolute",
    top: 110,
    left: 0,
    right: 0,
    alignItems: "center",
  },
  boxProgressRow: {
    flexDirection: "row",
    alignItems: "center",
    backgroundColor: "rgba(0, 0, 0, 0.7)",
    borderRadius: 20,
    paddingHorizontal: 16,
    paddingVertical: 8,
    marginBottom: 10,
  },
  boxProgressItem: {
    flexDirection: "row",
    alignItems: "center",
    opacity: 0.5,
  },
  boxProgressItemComplete: {
    opacity: 1,
  },
  boxProgressItemActive: {
    opacity: 1,
  },
  boxProgressDot: {
    width: 10,
    height: 10,
    borderRadius: 5,
    marginRight: 4,
  },
  boxProgressText: {
    color: "#FFFFFF",
    fontSize: 14,
    fontWeight: "600",
  },
  boxProgressConnector: {
    width: 20,
    height: 2,
    backgroundColor: "rgba(255, 255, 255, 0.3)",
    marginHorizontal: 8,
  },
  boxModeInstruction: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
  },
  dimensionIndicator: {
    width: 12,
    height: 12,
    borderRadius: 6,
    marginRight: 8,
  },
  boxModeText: {
    color: "#FFFFFF",
    fontSize: 16,
    fontWeight: "600",
    backgroundColor: "rgba(0, 0, 0, 0.7)",
    paddingHorizontal: 16,
    paddingVertical: 10,
    borderRadius: 20,
    overflow: "hidden",
  },
  objectModeInstruction: {
    position: "absolute",
    top: "45%",
    left: 0,
    right: 0,
    alignItems: "center",
  },
  objectModeText: {
    color: "#FFFFFF",
    fontSize: 18,
    fontWeight: "500",
    backgroundColor: "rgba(0, 0, 0, 0.6)",
    paddingHorizontal: 20,
    paddingVertical: 12,
    borderRadius: 25,
    overflow: "hidden",
  },
  // Measurement card
  measurementCard: {
    position: "absolute",
    bottom: 0,
    left: 0,
    right: 0,
    backgroundColor: "rgba(40, 40, 40, 0.95)",
    borderTopLeftRadius: 20,
    borderTopRightRadius: 20,
    paddingHorizontal: 24,
    paddingBottom: 40,
  },
  cardHandle: {
    width: 36,
    height: 5,
    backgroundColor: "rgba(255, 255, 255, 0.3)",
    borderRadius: 3,
    alignSelf: "center",
    marginTop: 10,
    marginBottom: 16,
  },
  cardHeader: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    marginBottom: 20,
  },
  cardTitle: {
    fontSize: 20,
    fontWeight: "600",
    color: "#fff",
  },
  closeButton: {
    width: 30,
    height: 30,
    borderRadius: 15,
    backgroundColor: "rgba(100, 100, 100, 0.8)",
    alignItems: "center",
    justifyContent: "center",
  },
  closeButtonText: {
    color: "#fff",
    fontSize: 14,
    fontWeight: "bold",
  },
  lineVisual: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    marginBottom: 16,
  },
  lineDot: {
    width: 12,
    height: 12,
    borderRadius: 6,
    backgroundColor: "#fff",
    borderWidth: 2,
    borderColor: "#666",
  },
  lineBar: {
    width: 200,
    height: 2,
    backgroundColor: "#fff",
  },
  mainMeasurement: {
    flexDirection: "row",
    alignItems: "baseline",
    justifyContent: "center",
    marginBottom: 24,
  },
  mainMeasurementValue: {
    fontSize: 72,
    fontWeight: "300",
    color: "#fff",
  },
  mainMeasurementMetric: {
    fontSize: 24,
    color: "rgba(255, 255, 255, 0.6)",
    marginLeft: 16,
  },
  measurementRow: {
    borderTopWidth: StyleSheet.hairlineWidth,
    borderTopColor: "rgba(255, 255, 255, 0.2)",
    paddingTop: 12,
  },
  measurementLabel: {
    fontSize: 14,
    color: "rgba(255, 255, 255, 0.6)",
    marginBottom: 4,
  },
  measurementValues: {
    flexDirection: "row",
    alignItems: "baseline",
    marginBottom: 16,
  },
  measurementValueLarge: {
    fontSize: 32,
    fontWeight: "300",
    color: "#fff",
  },
  measurementValueSmall: {
    fontSize: 16,
    color: "rgba(255, 255, 255, 0.6)",
    marginLeft: 12,
  },
  copyButton: {
    backgroundColor: "rgba(100, 100, 100, 0.6)",
    paddingVertical: 14,
    borderRadius: 10,
    alignItems: "center",
    marginTop: 8,
  },
  copyButtonText: {
    color: "#fff",
    fontSize: 17,
    fontWeight: "500",
  },
  newMeasurementButton: {
    paddingVertical: 14,
    alignItems: "center",
    marginTop: 8,
  },
  newMeasurementText: {
    color: "#007AFF",
    fontSize: 17,
    fontWeight: "500",
  },
  // Object measurement styles
  boxVisual: {
    alignItems: "center",
    marginBottom: 20,
  },
  boxIcon: {
    fontSize: 48,
  },
  dimensionsGrid: {
    flexDirection: "row",
    justifyContent: "space-between",
    marginBottom: 20,
  },
  dimensionItem: {
    flex: 1,
    alignItems: "center",
    paddingVertical: 12,
    backgroundColor: "rgba(60, 60, 60, 0.6)",
    marginHorizontal: 4,
    borderRadius: 12,
  },
  dimensionLabel: {
    fontSize: 12,
    color: "rgba(255, 255, 255, 0.6)",
    marginBottom: 4,
  },
  dimensionValue: {
    fontSize: 24,
    fontWeight: "500",
    color: "#FFFFFF",
  },
  dimensionMetric: {
    fontSize: 12,
    color: "rgba(255, 255, 255, 0.5)",
    marginTop: 2,
  },
  confidenceRow: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
    paddingVertical: 12,
    borderTopWidth: StyleSheet.hairlineWidth,
    borderTopColor: "rgba(255, 255, 255, 0.2)",
  },
  confidenceLabel: {
    fontSize: 14,
    color: "rgba(255, 255, 255, 0.6)",
  },
  confidenceValue: {
    fontSize: 16,
    fontWeight: "500",
    color: "#FFFFFF",
  },
  infoRow: {
    alignItems: "center",
    paddingVertical: 8,
  },
  infoText: {
    fontSize: 12,
    color: "rgba(255, 255, 255, 0.4)",
  },
  title: {
    fontSize: 28,
    fontWeight: "bold",
    color: "#fff",
    textAlign: "center",
    marginTop: 100,
  },
});
