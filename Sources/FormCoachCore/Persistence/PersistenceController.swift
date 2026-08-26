import Foundation

@MainActor
public final class PersistenceController: ObservableObject {
    public static let shared = PersistenceController()
    
    @Published public private(set) var sets: [ExerciseSetModel] = []
    
    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "com.formcoach.persistence.queue", qos: .userInitiated)
    
    private var historyFileURL: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Data", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent("history.json")
    }
    
    public init() {
        loadHistory()
    }
    
    private func loadHistory() {
        guard fileManager.fileExists(atPath: historyFileURL.path),
              let data = try? Data(contentsOf: historyFileURL),
              let decoded = try? JSONDecoder().decode([ExerciseSetModel].self, from: data) else {
            self.sets = []
            return
        }
        self.sets = decoded.sorted(by: { $0.recordedAt > $1.recordedAt })
    }
    
    private func persistHistoryToDisk() {
        let setsToSave = self.sets
        let url = self.historyFileURL
        queue.async {
            if let data = try? JSONEncoder().encode(setsToSave) {
                try? data.write(to: url, options: .atomic)
            }
        }
    }
    
    /// Persists a fully analyzed set with reps and observations into local store
    public func saveSet(
        setId: UUID,
        exerciseType: ExerciseType,
        cameraView: CameraViewType,
        reps: [Repetition],
        analysis: SetAnalysis,
        timeSeries: PoseTimeSeries,
        videoURL: URL?
    ) throws -> ExerciseSetModel {
        // 1. Save PoseTimeSeries to disk
        try PoseTimeSeriesStore.shared.save(timeSeries: timeSeries, setId: setId)
        
        // 2. Create RepModels
        let repModels = reps.map { rep in
            RepModel(
                id: rep.id,
                index: rep.index,
                startTime: rep.startTime,
                inflectionTime: rep.inflectionTime,
                endTime: rep.endTime,
                duration: rep.duration,
                eccentricDuration: rep.eccentricDuration,
                concentricDuration: rep.concentricDuration,
                pauseDuration: rep.pauseDuration,
                primaryROM: rep.primaryROM,
                secondaryROM: rep.secondaryROM,
                torsoAngleMean: rep.torsoAngleMean,
                confidence: rep.confidence,
                isComplete: rep.isComplete
            )
        }
        
        // 3. Create AnalysisModel
        let observationsJson = (try? String(data: JSONEncoder().encode(analysis.observations), encoding: .utf8)) ?? "[]"
        let analysisModel = SetAnalysisModel(
            id: UUID(),
            overallQualityScore: analysis.overallQualityScore,
            romScore: analysis.romScore,
            consistencyScore: analysis.consistencyScore,
            tempoScore: analysis.tempoScore,
            symmetryScore: analysis.symmetryScore,
            primaryObservation: analysis.primaryObservation,
            observationsJson: observationsJson
        )
        
        // 4. Create ExerciseSetModel
        let setModel = ExerciseSetModel(
            id: setId,
            exerciseTypeRaw: exerciseType.rawValue,
            cameraViewRaw: cameraView.rawValue,
            recordedAt: Date(),
            videoPath: videoURL?.lastPathComponent,
            poseDataPath: "\(setId.uuidString).pose.json",
            repCount: reps.count,
            trackingConfidence: analysis.trackingConfidence.overallScore,
            analyzerVersion: 1,
            ruleVersion: 1,
            reps: repModels,
            analysis: analysisModel
        )
        
        self.sets.insert(setModel, at: 0)
        persistHistoryToDisk()
        return setModel
    }
    
    /// Deletes a set record and associated physical files from disk
    public func deleteSet(setModel: ExerciseSetModel) throws {
        let setId = setModel.id
        
        // Delete physical files
        try? PoseTimeSeriesStore.shared.delete(setId: setId)
        if let _ = setModel.videoPath {
            let videoURL = LocalVideoStorage.shared.createVideoURL(setId: setId)
            try? LocalVideoStorage.shared.deleteVideo(at: videoURL)
        }
        
        self.sets.removeAll(where: { $0.id == setId })
        persistHistoryToDisk()
    }
}
