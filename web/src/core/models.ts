export type ExerciseCategory = 'arms' | 'push' | 'legs';

export interface ExerciseCategoryInfo {
  id: ExerciseCategory;
  name: string;
  icon: string;
}

export const EXERCISE_CATEGORIES: ExerciseCategoryInfo[] = [
  { id: 'arms', name: 'Arme', icon: '💪' },
  { id: 'legs', name: 'Ben & Underkrop', icon: '🦵' },
  { id: 'push', name: 'Skuldre & Bryst', icon: '🏋️‍♂️' },
];

export type ExerciseType =
  | 'bicepsCurl'
  | 'tricepsPushdown'
  | 'squat'
  | 'legPress'
  | 'shoulderPress';

export type CameraViewType = 'side' | 'front45' | 'front';

export type ExerciseTier = 'TIER_A_SUPPORTED' | 'TIER_B_EXPERIMENTAL';

export interface ExerciseDefinition {
  id: ExerciseType;
  name: string;
  subtitle: string;
  category: ExerciseCategory;
  recommendedView: CameraViewType;
  supportedViews: CameraViewType[];
  keyMetrics: string[];
  status: 'ACTIVE' | 'IN_DEVELOPMENT';
  tier: ExerciseTier;
}

export const EXERCISES: Record<ExerciseType, ExerciseDefinition> = {
  bicepsCurl: {
    id: 'bicepsCurl',
    name: 'Bicep Curls',
    subtitle: 'Håndvægte / Vægtstang',
    category: 'arms',
    recommendedView: 'side',
    supportedViews: ['side', 'front45', 'front'],
    keyMetrics: ['Bevægelsesbane (ROM)', 'Skuldersvaj (Δθ)', 'Tempo (Løft/Sænk)', 'Gentagelser'],
    status: 'ACTIVE',
    tier: 'TIER_A_SUPPORTED'
  },
  tricepsPushdown: {
    id: 'tricepsPushdown',
    name: 'Triceps Pushdown',
    subtitle: 'Kabeltræk med reb eller stang',
    category: 'arms',
    recommendedView: 'side',
    supportedViews: ['side', 'front45', 'front'],
    keyMetrics: ['Albuevinkel / ROM', 'Overarms-stabilitet', 'Tempo (Løft/Sænk)', 'Gentagelser'],
    status: 'ACTIVE',
    tier: 'TIER_A_SUPPORTED'
  },
  squat: {
    id: 'squat',
    name: 'Squat',
    subtitle: 'Kropsvægt / Vægtstang på ryg',
    category: 'legs',
    recommendedView: 'side',
    supportedViews: ['side', 'front45', 'front'],
    keyMetrics: ['Knævinkel / ROM', 'Ensartethed (±σ)', 'ROM-ændring', 'Gentagelser'],
    status: 'ACTIVE',
    tier: 'TIER_A_SUPPORTED'
  },
  legPress: {
    id: 'legPress',
    name: 'Benpres Maskine',
    subtitle: '45° / Vandret benpres',
    category: 'legs',
    recommendedView: 'side',
    supportedViews: ['side', 'front45'],
    keyMetrics: ['Knævinkel / ROM', 'Ensartethed', 'Tempo', 'Gentagelser'],
    status: 'ACTIVE',
    tier: 'TIER_A_SUPPORTED'
  },
  shoulderPress: {
    id: 'shoulderPress',
    name: 'Skulderpres',
    subtitle: 'Overhead press / Håndvægte',
    category: 'push',
    recommendedView: 'front',
    supportedViews: ['front', 'front45', 'side'],
    keyMetrics: ['Albuevinkel / ROM', 'Højre/Venstre forskel', 'Tempo', 'Gentagelser'],
    status: 'ACTIVE',
    tier: 'TIER_A_SUPPORTED'
  }
};

export interface Point2D {
  x: number;
  y: number;
  score: number;
}

export interface Point3D {
  x: number;
  y: number;
  z?: number;
  score: number;
}

export type JointName =
  | 'nose'
  | 'left_shoulder' | 'right_shoulder'
  | 'left_elbow' | 'right_elbow'
  | 'left_wrist' | 'right_wrist'
  | 'left_hip' | 'right_hip'
  | 'left_knee' | 'right_knee'
  | 'left_ankle' | 'right_ankle';

export interface PoseFrame {
  timestamp: number;
  joints: Partial<Record<JointName, Point2D>>;
  aspectRatio?: number;
  worldJoints?: Partial<Record<JointName, Point3D>>;
  confidence: number;
}

export interface Repetition {
  index: number;
  startTime: number;
  inflectionTime: number;
  endTime: number;
  duration: number;
  concentricDuration: number;
  eccentricDuration: number;
  primaryROM: number;
  secondaryROM?: number;
  confidence: number;
}

export interface FormObservation {
  id: string;
  title: string;
  detail: string;
  evidence: string;
  severity: 'positive' | 'warning' | 'info';
  affectedReps: number[];
}

export type FormStabilityStatus = 'STRICT_STABILITY' | 'MODERATE_VARIANCE' | 'HIGH_DEVIATION' | 'INSUFFICIENT_DATA';

export interface SetAnalysis {
  overallScore: number;
  romScore: number;
  consistencyScore: number;
  tempoScore: number;
  symmetryScore?: number;
  secondaryMetricsAvailable?: boolean;
  primaryObservation: string;
  observations: FormObservation[];
  repCount: number;
  meanROM: number;
  romStdDev: number;
  meanDuration: number;
  tempoStdDev: number;
  concentricMean: number;
  eccentricMean: number;
  peakRelativeDrift?: number;
  meanAsymmetry?: number;
  earlyLateROMDelta?: number;
  stabilityStatus: FormStabilityStatus;
}

export interface CameraTelemetry {
  cameraFPS: number;
  inferenceFPS: number;
  medianLatencyMs: number;
  p95LatencyMs: number;
  droppedFrames: number;
}

export interface RecordedSet {
  id: string;
  exercise: ExerciseType;
  view: CameraViewType;
  date: string;
  reps: Repetition[];
  analysis: SetAnalysis;
  videoUrl?: string;
}

export interface WorkoutSessionAnalysis {
  totalSets: number;
  totalReps: number;
  fatigueIndex: number | null;
  romTrend: 'stable' | 'degrading' | 'improving';
  tempoTrend: 'stable' | 'slowing' | 'accelerating';
  sessionObservations: FormObservation[];
  setBreakdowns: {
    setNumber: number;
    repCount: number;
    meanROM: number;
    meanDuration: number;
    qualityScore: number | null;
  }[];
}

export interface PersonalBaseline {
  exercise: ExerciseType;
  totalSessions: number;
  totalReps: number;
  baselineROMMean: number;
  baselineROMStdDev: number;
  personalBestROM: number;
  hasSufficientData: boolean;
}
