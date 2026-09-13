import Foundation

extension AppDelegate {
    /// Wires the local agent roster into the existing restore and hook-event owners.
    func configureLocalAgentSessions(for manager: TabManager) {
        guard let recorder = manager.agentChatResumeIntentRecorder as? AgentChatTranscriptResumeIntentRecorder,
              let registry = recorder.registry,
              TerminalController.shared.localAgentSessionRegistry !== registry else { return }
        TerminalController.shared.localAgentSessionRegistry = registry
        registry.onRecordChanged = { [weak self] record, previous in
            self?.refreshLocalAgentSessionSidebar(record: record, previous: previous)
        }
        registry.onRecordRemoved = { [weak self] record in
            self?.refreshLocalAgentSessionSidebar(record: record, previous: nil)
        }
        Task { await registry.seedFromHookStores() }
    }

    private func refreshLocalAgentSessionSidebar(
        record: AgentChatSessionRecord,
        previous: AgentChatSessionRecord?
    ) {
        let workspaceIDs = Set([record.workspaceID, previous?.workspaceID].compactMap { $0 })
        let surfaceIDs = Set([record.surfaceID, previous?.surfaceID].compactMap { $0 }.compactMap(UUID.init(uuidString:)))
        var visited = Set<UUID>()
        for context in mainWindowContexts.values {
            for workspace in context.tabManager.tabs where visited.insert(workspace.id).inserted {
                guard workspaceIDs.contains(workspace.id.uuidString)
                    || !surfaceIDs.isDisjoint(with: workspace.panels.keys) else { continue }
                // Workspace is still a legacy ObservableObject. Publish only from an
                // authoritative registry mutation, never from the snapshot projection.
                workspace.objectWillChange.send()
            }
        }
    }
}
