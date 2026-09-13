import Foundation

/// Reads immutable local session records for sidebar projection without starting I/O.
@MainActor
protocol LocalAgentSessionRecordsReading {
    func sessionRecords(workspaceID: String?) -> [AgentChatSessionRecord]
}
