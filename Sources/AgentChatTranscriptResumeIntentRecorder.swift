import CMUXAgentLaunch

/// Bridges restore bindings into the local session registry without remote transcript sync.
struct AgentChatTranscriptResumeIntentRecorder: AgentChatResumeIntentRecording, LocalAgentSessionRecordsReading {
    let registry: AgentChatSessionRegistry?

    nonisolated init(registry: AgentChatSessionRegistry? = nil) {
        self.registry = registry
    }

    @MainActor
    func record(_ intent: AgentChatResumeIntent) {
        registry?.noteResumeInitiated(
            sessionID: intent.sessionID,
            source: intent.source,
            surfaceID: intent.surfaceID,
            workspaceID: intent.workspaceID,
            workingDirectory: intent.workingDirectory
        )
    }

    @MainActor
    func sessionRecords(workspaceID: String?) -> [AgentChatSessionRecord] {
        registry?.sessions(workspaceID: workspaceID) ?? []
    }
}
