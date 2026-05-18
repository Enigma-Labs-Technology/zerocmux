import Foundation

private enum WorkspaceRemoteSSHOptionFilter {
    private static let transientControlSocketKeys: Set<String> = [
        "controlmaster",
        "controlpath",
        "controlpersist",
    ]

    static func durableOptions(_ options: [String]) -> [String] {
        options.compactMap { option in
            let trimmed = option.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }.filter { option in
            guard let key = optionKey(option) else { return true }
            return !transientControlSocketKeys.contains(key)
        }
    }

    static func normalizedOptional(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func normalizedIdentityPath(_ value: String?) -> String? {
        guard let trimmed = normalizedOptional(value) else { return nil }
        guard trimmed.hasPrefix("~") else { return trimmed }
        return normalizedOptional((trimmed as NSString).expandingTildeInPath) ?? trimmed
    }

    static func hasOptionKey(_ options: [String], key: String) -> Bool {
        let loweredKey = key.lowercased()
        return options.contains { option in
            optionKey(option) == loweredKey
        }
    }

    private static func optionKey(_ option: String) -> String? {
        let trimmed = option.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed
            .split(whereSeparator: { $0 == "=" || $0.isWhitespace })
            .first
            .map(String.init)?
            .lowercased()
    }
}

nonisolated struct SessionRemoteWorkspaceSnapshot: Codable, Equatable, Sendable {
    var transport: WorkspaceRemoteTransport
    var destination: String
    var port: Int?
    var identityFile: String?
    var sshOptions: [String]
    var skipDaemonBootstrap: Bool?
}

extension SessionRemoteWorkspaceSnapshot {
    func workspaceConfiguration() -> WorkspaceRemoteConfiguration? {
        guard transport == .ssh else { return nil }
        let normalizedDestination = destination.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedDestination.isEmpty else { return nil }
        let normalizedPort = port.flatMap { port in
            (1...65535).contains(port) ? port : nil
        }

        return WorkspaceRemoteConfiguration(
            transport: transport,
            destination: normalizedDestination,
            port: normalizedPort,
            identityFile: Self.normalizedIdentityPath(identityFile),
            sshOptions: Self.normalizedSSHOptions(sshOptions),
            localProxyPort: nil,
            relayPort: nil,
            relayID: nil,
            relayToken: nil,
            localSocketPath: nil,
            terminalStartupCommand: sshReconnectCommand(
                destination: normalizedDestination,
                port: normalizedPort
            ),
            foregroundAuthToken: nil,
            daemonWebSocketEndpoint: nil,
            skipDaemonBootstrap: skipDaemonBootstrap == true
        )
    }

    private func sshReconnectCommand(
        destination normalizedDestination: String,
        port normalizedPort: Int?
    ) -> String? {
        var arguments = ["ssh"]
        if let normalizedPort {
            arguments += ["-p", String(normalizedPort)]
        }
        if let identityFile = Self.normalizedIdentityPath(identityFile) {
            arguments += ["-i", identityFile]
        }
        let normalizedOptions = Self.normalizedSSHOptions(sshOptions)
        for option in normalizedOptions {
            arguments += ["-o", option]
        }
        if !Self.hasSSHOptionKey(normalizedOptions, key: "RequestTTY") {
            arguments.append("-tt")
        }
        arguments.append(normalizedDestination)
        return arguments.map(Self.shellQuote).joined(separator: " ")
    }

    private static func normalizedIdentityPath(_ value: String?) -> String? {
        WorkspaceRemoteSSHOptionFilter.normalizedIdentityPath(value)
    }

    private static func normalizedSSHOptions(_ options: [String]) -> [String] {
        WorkspaceRemoteSSHOptionFilter.durableOptions(options)
    }

    private static func hasSSHOptionKey(_ options: [String], key: String) -> Bool {
        WorkspaceRemoteSSHOptionFilter.hasOptionKey(options, key: key)
    }

    private static func shellQuote(_ value: String) -> String {
        let safePattern = "^[A-Za-z0-9_@%+=:,./-]+$"
        if value.range(of: safePattern, options: .regularExpression) != nil {
            return value
        }
        return "'" + value.replacingOccurrences(of: "'", with: "'\"'\"'") + "'"
    }
}

extension WorkspaceRemoteConfiguration {
    func sessionSnapshot() -> SessionRemoteWorkspaceSnapshot? {
        guard transport == .ssh else { return nil }
        let normalizedDestination = destination.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedDestination.isEmpty else { return nil }

        return SessionRemoteWorkspaceSnapshot(
            transport: transport,
            destination: normalizedDestination,
            port: port,
            identityFile: WorkspaceRemoteSSHOptionFilter.normalizedIdentityPath(identityFile),
            sshOptions: WorkspaceRemoteSSHOptionFilter.durableOptions(sshOptions),
            skipDaemonBootstrap: skipDaemonBootstrap
        )
    }
}
