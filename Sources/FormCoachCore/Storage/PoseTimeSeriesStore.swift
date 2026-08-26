import Foundation

/// Manages serialization and deserialization of PoseTimeSeries JSON files
public final class PoseTimeSeriesStore: @unchecked Sendable {
    public static let shared = PoseTimeSeriesStore()
    
    private let fileManager = FileManager.default
    
    private var setsDirectory: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Sets", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
    
    public init() {}
    
    public func url(for setId: UUID) -> URL {
        setsDirectory.appendingPathComponent("\(setId.uuidString).pose.json")
    }
    
    /// Saves pose time series to disk as compact JSON
    public func save(timeSeries: PoseTimeSeries, setId: UUID) throws {
        let fileURL = url(for: setId)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(timeSeries)
        try data.write(to: fileURL, options: .atomic)
    }
    
    /// Loads pose time series from disk
    public func load(setId: UUID) throws -> PoseTimeSeries {
        let fileURL = url(for: setId)
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        return try decoder.decode(PoseTimeSeries.self, from: data)
    }
    
    /// Deletes stored pose data
    public func delete(setId: UUID) throws {
        let fileURL = url(for: setId)
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
    }
    
    /// Deletes all stored pose time series files
    public func deleteAll() throws {
        guard let files = try? fileManager.contentsOfDirectory(at: setsDirectory, includingPropertiesForKeys: nil) else {
            return
        }
        for file in files {
            try? fileManager.removeItem(at: file)
        }
    }
}
