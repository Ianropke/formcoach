import Foundation

/// Severity / nature of a biomechanical observation
public enum ObservationSeverity: String, Codable, Sendable {
    case positive
    case info
    case warning
    case critical
}

/// Explainable feedback observation linked to metric evidence
public struct FormObservation: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public let title: String
    public let detail: String
    public let evidence: String
    public let severity: ObservationSeverity
    public let affectedRepIndices: [Int]
    
    public init(
        id: String,
        title: String,
        detail: String,
        evidence: String,
        severity: ObservationSeverity,
        affectedRepIndices: [Int] = []
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.evidence = evidence
        self.severity = severity
        self.affectedRepIndices = affectedRepIndices
    }
}
