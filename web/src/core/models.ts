export type ExerciseCategory = 'arms' | 'pull' | 'push' | 'legs';

export interface ExerciseCategoryInfo {
  id: ExerciseCategory;
  name: string;
  icon: string;
}

export const EXERCISE_CATEGORIES: ExerciseCategoryInfo[] = [
  { id: 'pull', name: 'Back & Pull', icon: '🚣‍♂️' },
  { id: 'arms', name: 'Arms', icon: '💪' },
  { id: 'push', name: 'Chest & Shoulders', icon: '🏋️‍♂️' },
  { id: 'legs', name: 'Legs & Lower Body', icon: '🦵' },
];

export type ExerciseType =
  | 'seatedRow'
  | 'chestSupportedRow'
  | 'facePull'
  | 'straightArmPulldown'
  | 'bicepsCurl'
  | 'tricepsPushdown'
  | 'chestPress'
  | 'shoulderPress'
  | 'squat'
  | 'legPress'
  | 'calfExtension';

export type CameraViewType = 'side' | 'front45' | 'front';

export interface ExerciseDefinition {
  id: ExerciseType;
  name: string;
  subtitle: string;
  category: ExerciseCategory;
  recommendedView: CameraViewType;
  supportedViews: CameraViewType[];
  keyMetrics: string[];
}

export const EXERCISES: Record<ExerciseType, ExerciseDefinition> = {
  seatedRow: {
    id: 'seatedRow',
    name: 'Seated Cable Row',
    subtitle: 'Cable / Machine Row',
    category: 'pull',
    recommendedView: 'side',
    supportedViews: ['side', 'front45', 'front'],
    keyMetrics: ['Retraction ROM', 'Torso Stability', 'Tempo', 'Rep Count']
  },
  chestSupportedRow: {
    id: 'chestSupportedRow',
    name: 'Chest Supported Incline Row',
    subtitle: 'Incline Dumbbell / Machine Row',
    category: 'pull',
    recommendedView: 'side',
    supportedViews: ['side', 'front45'],
    keyMetrics: ['Peak Retraction', 'Eccentric Control', 'Tempo', 'Rep Count']
  },
  facePull: {
    id: 'facePull',
    name: 'Face Pull',
    subtitle: 'High Cable Rope Face Pull',
    category: 'pull',
    recommendedView: 'front',
    supportedViews: ['front', 'front45', 'side'],
    keyMetrics: ['Elbow Height Level', 'External Rotation', 'Tempo', 'Rep Count']
  },
  straightArmPulldown: {
    id: 'straightArmPulldown',
    name: 'Rope Straight Arm Pulldown',
    subtitle: 'High Cable Lat Pulldown',
    category: 'pull',
    recommendedView: 'side',
    supportedViews: ['side', 'front45'],
    keyMetrics: ['Arm Arc ROM', 'Elbow Lock Stability', 'Tempo', 'Rep Count']
  },
  bicepsCurl: {
    id: 'bicepsCurl',
    name: 'Bicep Curls',
    subtitle: 'Dumbbell / Barbell Curl',
    category: 'arms',
    recommendedView: 'side',
    supportedViews: ['side', 'front45', 'front'],
    keyMetrics: ['Elbow ROM', 'Shoulder Drift', 'Tempo', 'Rep Count']
  },
  tricepsPushdown: {
    id: 'tricepsPushdown',
    name: 'Triceps Pushdown',
    subtitle: 'Cable Rope / Bar Extension',
    category: 'arms',
    recommendedView: 'side',
    supportedViews: ['side', 'front45', 'front'],
    keyMetrics: ['Lockout ROM', 'Pinned Elbow Stability', 'Tempo', 'Rep Count']
  },
  chestPress: {
    id: 'chestPress',
    name: 'Chest Press Machine',
    subtitle: 'Machine / Dumbbell Press',
    category: 'push',
    recommendedView: 'side',
    supportedViews: ['side', 'front45'],
    keyMetrics: ['Chest Depth ROM', 'Lockout Extension', 'Tempo', 'Rep Count']
  },
  shoulderPress: {
    id: 'shoulderPress',
    name: 'Shoulder Press',
    subtitle: 'Overhead Press',
    category: 'push',
    recommendedView: 'front',
    supportedViews: ['front', 'front45', 'side'],
    keyMetrics: ['Lockout ROM', 'Press Symmetry', 'Tempo', 'Rep Count']
  },
  squat: {
    id: 'squat',
    name: 'Squat',
    subtitle: 'Bodyweight / Barbell Squat',
    category: 'legs',
    recommendedView: 'side',
    supportedViews: ['side', 'front45', 'front'],
    keyMetrics: ['Knee Depth / ROM', 'Torso Incline', 'Tempo', 'Rep Count']
  },
  legPress: {
    id: 'legPress',
    name: 'Leg Press Machine',
    subtitle: '45° / Horizontal Leg Press',
    category: 'legs',
    recommendedView: 'side',
    supportedViews: ['side', 'front45'],
    keyMetrics: ['Knee Flexion Depth', 'Controlled Extension', 'Tempo', 'Rep Count']
  },
  calfExtension: {
    id: 'calfExtension',
    name: 'Calf Extension / Raise',
    subtitle: 'Machine / Leg Press Calf Raise',
    category: 'legs',
    recommendedView: 'side',
    supportedViews: ['side', 'front45', 'front'],
    keyMetrics: ['Ankle ROM', 'Peak Stretch & Squeeze', 'Tempo', 'Rep Count']
  }
};

export interface Point2D {
  x: number; // 0 to 1
  y: number; // 0 to 1
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
  primaryROM: number; // e.g. angle in degrees
  secondaryROM?: number; // e.g. cheat angle / asymmetry
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

export interface SetAnalysis {
  overallScore: number;
  romScore: number;
  consistencyScore: number;
  tempoScore: number;
  symmetryScore?: number;
  primaryObservation: string;
  observations: FormObservation[];
  repCount: number;
  meanROM: number;
  meanDuration: number;
  earlyLateROMDelta?: number;
}

export interface RecordedSet {
  id: string;
  exercise: ExerciseType;
  view: CameraViewType;
  date: string;
  reps: Repetition[];
  analysis: SetAnalysis;
}

export interface WorkoutSessionAnalysis {
  totalSets: number;
  totalReps: number;
  fatigueIndex: number; // 0 - 100
  romTrend: 'stable' | 'degrading' | 'improving';
  tempoTrend: 'stable' | 'slowing' | 'accelerating';
  sessionObservations: FormObservation[];
  setBreakdowns: {
    setNumber: number;
    repCount: number;
    meanROM: number;
    meanDuration: number;
    qualityScore: number;
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
