import Foundation

/// One child agent run under a parent session: a Claude `Task` tool spawn or
/// a Codex subagent run, tracked purely from the parent's hook events (the
/// child has no hooks of its own).
struct AgentChatChildRun: Sendable, Equatable {
    /// Correlation id: the hook `requestId` when present, else synthesized.
    let id: String
    /// Human label: the Task description / subagent type, when the payload
    /// carried one.
    var label: String?
    let startedAt: Date
    var endedAt: Date?

    var isRunning: Bool { endedAt == nil }

    /// How long a settled child stays in the record before pruning.
    static let settledRetention: TimeInterval = 15 * 60
    /// Bound on children kept per session (oldest settled dropped first).
    static let capacity = 16
}
