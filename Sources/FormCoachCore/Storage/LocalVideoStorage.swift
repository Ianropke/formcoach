import Foundation

/// Manages sandboxed MP4 video files on local disk
public final class LocalVideoStorage: @unchecked Sendable {
    public static let shared = LocalVideoStorage()
    
    private let fileManager = FileManager.default
    
    private var videosDirectory: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Videos", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
    
    public init() {}
    
    /// Generates a local sandbox destination URL for a new recording
    public func createVideoURL(setId: UUID) -> URL {
        videosDirectory.appendingPathComponent("\(setId.uuidString).mp4")
    }
    
    /// Checks if a video file exists
    public func videoExists(at url: URL) -> Bool {
        fileManager.fileExists(atPath: url.path)
    }
    
    /// Deletes a video file from local sandbox
    public func deleteVideo(at url: URL) throws {
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }
    
    /// Deletes video for a specific set ID
    public func deleteVideo(for setId: UUID) throws {
        let url = createVideoURL(setId: setId)
        try deleteVideo(at: url)
    }
    
    /// Calculates total storage used by local videos in bytes
    public func calculateStorageUsed() -> Int64 {
        guard let files = try? fileManager.contentsOfDirectory(at: videosDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        
        var total: Int64 = 0
        for file in files {
            if let resources = try? file.resourceValues(forKeys: [.fileSizeKey]), let size = resources.fileSize {
                total += Int64(size)
            }
        }
        return total
    }
    
    /// Deletes all locally stored video files
    public func deleteAllVideos() throws {
        guard let files = try? fileManager.contentsOfDirectory(at: videosDirectory, includingPropertiesForKeys: nil) else {
            return
        }
        for file in files {
            try? fileManager.removeItem(at: file)
        }
    }
}
