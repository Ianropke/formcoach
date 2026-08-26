import Foundation
import SwiftUI
import CoreMedia
import FormCoachCore

public enum SessionFlowState: Sendable, Equatable {
    case idle
    case exerciseSelection
    case cameraSetup(exercise: ExerciseType, view: CameraViewType)
    case countdown(exercise: ExerciseType, view: CameraViewType, secondsRemaining: Int)
    case recording(exercise: ExerciseType, view: CameraViewType, startTime: Date)
    case analyzing(exercise: ExerciseType, progressText: String)
    case results(setId: UUID, exercise: ExerciseType, view: CameraViewType)
    case workoutSummary(sessionAnalysis: WorkoutSessionAnalysis)
}

@MainActor
public final class WorkoutSessionCoordinator: ObservableObject, CameraFrameDelegate {
    @Published public var state: SessionFlowState = .exerciseSelection
    @Published public var livePoseFrame: PoseFrame?
    @Published public var setupValidation: CameraSetupValidation?
    @Published public var recordedFrames: [PoseFrame] = []
    
    // Multi-Set Workout Session
    @Published public var activeWorkoutSets: [ExerciseSetModel] = []
    
    // Active Set Data
    @Published public var currentSetId: UUID = UUID()
    @Published public var currentReps: [Repetition] = []
    @Published public var currentAnalysis: SetAnalysis?
    @Published public var currentTimeSeries: PoseTimeSeries?
    @Published public var currentVideoURL: URL?
    
    public let cameraService = CameraService()
    public let poseService = VisionPoseService()
    public let videoRecorder = VideoRecorder()
    public let poseSmoother = PoseSmoother()
    
    private let squatAnalyzer = SquatAnalyzer()
    private let bicepsCurlAnalyzer = BicepsCurlAnalyzer()
    private let shoulderPressAnalyzer = ShoulderPressAnalyzer()
    
    public func analyzer(for exercise: ExerciseType) -> any ExerciseAnalyzerProtocol {
        switch exercise {
        case .squat: return squatAnalyzer
        case .bicepsCurl: return bicepsCurlAnalyzer
        case .shoulderPress: return shoulderPressAnalyzer
        }
    }
    
    private var countdownTimer: Timer?
    private var liveRepCount = 0
    
    public init() {
        cameraService.delegate = self
        cameraService.configureSession()
    }
    
    public func startSessionFlow(exercise: ExerciseType = .squat) {
        self.activeWorkoutSets = []
        self.state = .cameraSetup(exercise: exercise, view: exercise.recommendedView)
        cameraService.startSession()
    }
    
    public func logNextSet(exercise: ExerciseType, view: CameraViewType) {
        self.state = .cameraSetup(exercise: exercise, view: view)
        cameraService.startSession()
    }
    
    public func finishWorkout(exercise: ExerciseType) {
        cameraService.stopSession()
        let analysis = CrossSetFatigueAnalyzer.analyzeSession(
            sets: self.activeWorkoutSets,
            exerciseType: exercise
        )
        self.state = .workoutSummary(sessionAnalysis: analysis)
    }
    
    public func startCountdown() {
        guard case .cameraSetup(let exercise, let view) = state else { return }
        
        var remaining = 3
        state = .countdown(exercise: exercise, view: view, secondsRemaining: remaining)
        
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else { return }
            Task { @MainActor in
                remaining -= 1
                if remaining > 0 {
                    self.state = .countdown(exercise: exercise, view: view, secondsRemaining: remaining)
                } else {
                    timer.invalidate()
                    self.startRecording(exercise: exercise, view: view)
                }
            }
        }
    }
    
    public func startRecording(exercise: ExerciseType, view: CameraViewType) {
        let setId = UUID()
        self.currentSetId = setId
        self.recordedFrames = []
        self.liveRepCount = 0
        
        let videoURL = LocalVideoStorage.shared.createVideoURL(setId: setId)
        self.currentVideoURL = videoURL
        
        try? videoRecorder.startRecording(to: videoURL)
        self.state = .recording(exercise: exercise, view: view, startTime: Date())
    }
    
    public func stopRecording() {
        guard case .recording(let exercise, let view, _) = state else { return }
        
        self.state = .analyzing(exercise: exercise, progressText: "Finalizing video capture…")
        
        Task {
            // 1. Stop video recorder
            try? await videoRecorder.stopRecording()
            
            // 2. Run deterministic Biomechanics Pipeline
            self.state = .analyzing(exercise: exercise, progressText: "Smoothing pose landmarks…")
            let smoothedFrames = self.poseSmoother.smooth(frames: self.recordedFrames)
            let timeSeries = PoseTimeSeries(frames: smoothedFrames)
            self.currentTimeSeries = timeSeries
            
            let activeAnalyzer = self.analyzer(for: exercise)
            
            self.state = .analyzing(exercise: exercise, progressText: "Segmenting repetitions…")
            let reps = activeAnalyzer.segmentReps(timeSeries: timeSeries, view: view)
            self.currentReps = reps
            
            self.state = .analyzing(exercise: exercise, progressText: "Computing biomechanics & consistency…")
            let analysis = activeAnalyzer.analyzeSet(reps: reps, timeSeries: timeSeries, view: view)
            self.currentAnalysis = analysis
            
            // 3. Persist to Local Store & track in active session
            if let savedModel = try? PersistenceController.shared.saveSet(
                setId: self.currentSetId,
                exerciseType: exercise,
                cameraView: view,
                reps: reps,
                analysis: analysis,
                timeSeries: timeSeries,
                videoURL: self.currentVideoURL
            ) {
                self.activeWorkoutSets.append(savedModel)
            }
            
            // 4. Present Results
            self.state = .results(setId: self.currentSetId, exercise: exercise, view: view)
        }
    }
    
    public func resetToHome() {
        countdownTimer?.invalidate()
        cameraService.stopSession()
        self.state = .exerciseSelection
        self.livePoseFrame = nil
        self.setupValidation = nil
        self.activeWorkoutSets = []
    }
    
    // MARK: - CameraFrameDelegate
    public nonisolated func cameraService(
        _ service: CameraService,
        didOutput sampleBuffer: CMSampleBuffer,
        timestamp: TimeInterval
    ) {
        Task { @MainActor in
            // Feed frame to video recorder if active
            if case .recording = self.state {
                self.videoRecorder.appendSampleBuffer(sampleBuffer)
            }
            
            // Extract pose frame with Apple Vision
            if let rawPose = try? await self.poseService.processFrame(
                sampleBuffer: sampleBuffer,
                timestamp: timestamp,
                orientation: .up
            ) {
                self.livePoseFrame = rawPose
                
                switch self.state {
                case .cameraSetup(let exercise, let view):
                    let activeAnalyzer = self.analyzer(for: exercise)
                    self.setupValidation = activeAnalyzer.validateCameraSetup(frame: rawPose, view: view)
                    
                case .recording:
                    self.recordedFrames.append(rawPose)
                    
                default:
                    break
                }
            }
        }
    }
}
