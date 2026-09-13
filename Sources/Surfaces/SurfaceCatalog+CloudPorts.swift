import CmuxFoundation
import Foundation

extension CmuxTuiSnapshotParser {
    /// One local socket binding from `ss -ltn` or `netstat -ltn`.
    struct ListeningPortBinding: Hashable, Sendable {
        let port: Int
        let address: String

        /// Loopback-only listeners cannot be reached through a machine's
        /// private network address. A port with any wildcard/non-loopback
        /// binding remains reachable even if another process also binds loopback.
        var isLoopbackOnly: Bool {
            let normalized = address
                .trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
                .split(separator: "%", maxSplits: 1, omittingEmptySubsequences: true)
                .first
                .map(String.init)
                .map { $0.lowercased() } ?? ""
            if normalized == "localhost" || normalized == "::1" { return true }
            // Linux may print an IPv4 loopback listener as an IPv4-mapped IPv6
            // address (`::ffff:127.0.0.1`). Treat every mapped 127/8 address
            // as loopback before deciding that a private-address preview is
            // reachable.
            if let mappedIPv4 = normalized.split(separator: ":").last,
               mappedIPv4.split(separator: ".").count == 4 {
                let octets = mappedIPv4.split(separator: ".")
                if octets.first == "127" { return true }
            }
            let octets = normalized.split(separator: ".")
            return octets.count == 4 && octets[0] == "127"
        }
    }

    /// Parses local address/port pairs while retaining the bind address for
    /// providers that open services directly over a private network.
    static func listeningPortBindings(fromSocketListing text: String) -> [ListeningPortBinding] {
        var byPort: [Int: Set<String>] = [:]
        for line in text.split(separator: "\n") {
            let columns = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
            guard columns.count >= 4 else { continue }
            // `ss`: State Recv-Q Send-Q Local:Port …; `netstat`: Proto Recv-Q
            // Send-Q Local:Port … . The first numeric port in the local prefix
            // is the local endpoint; peer ports are intentionally ignored.
            for column in columns.prefix(5) {
                guard let colon = column.lastIndex(of: ":"),
                      let port = Int(column[column.index(after: colon)...]),
                      (1...65_535).contains(port) else { continue }
                let address = String(column[..<colon])
                byPort[port, default: []].insert(address)
                break
            }
        }
        return byPort
            .flatMap { entry in
                entry.value.map { address in
                    ListeningPortBinding(port: entry.key, address: address)
                }
            }
            .sorted {
                $0.port != $1.port ? $0.port < $1.port : $0.address < $1.address
            }
    }

    /// Whether a listener is reachable through a private machine address.
    /// Kept pure so the provider can apply it before publishing a resource.
    static func reachableListeningPorts(
        fromSocketListing text: String,
        privateAddress: String?
    ) -> [Int] {
        var loopbackOnlyByPort: [Int: Bool] = [:]
        for binding in listeningPortBindings(fromSocketListing: text) {
            loopbackOnlyByPort[binding.port] =
                (loopbackOnlyByPort[binding.port] ?? true) && binding.isLoopbackOnly
        }
        return loopbackOnlyByPort.keys
            .filter { privateAddress == nil || loopbackOnlyByPort[$0] == false }
            .sorted()
    }
}

extension SurfaceResourceID {
    /// The numeric port encoded by the canonical cloud forwarded-port identity.
    /// Snapshot browser views that visit localhost are normalized to this key so
    /// the machine port and its workspace row share one resource identity.
    var forwardedPort: Int? {
        guard kind == .browser, key.hasPrefix("port:") else { return nil }
        let value = key.dropFirst("port:".count)
        guard let port = Int(value), (1...65_535).contains(port) else { return nil }
        guard key == SurfaceResourceID.portKey(port) else { return nil }
        return port
    }

    /// Whether this id is the machine-level forwarded-port resource.
    var isForwardedPort: Bool { forwardedPort != nil }
}

extension SurfaceCatalog {
    /// Localized destination error shared by the sidebar and socket open paths.
    nonisolated static func portDestinationUnavailableMessage(machine: SurfaceMachineID) -> String {
        String(
            format: String(
                localized: "cloudTree.port.noLocalWorkspace",
                defaultValue: "No local workspace is showing %@; select a workspace and retry."
            ),
            machine.rawValue
        )
    }

    /// Localized explanation used by both the sidebar and socket port-open paths.
    nonisolated static func portPreviewUnavailableMessage(machineID: String) -> String {
        String(
            format: String(
                localized: "cloudTree.port.unsupported",
                defaultValue: "%@’s provider cannot open machine ports as previews; reach the service from inside the machine with `cmux vm exec %@ -- …`."
            ),
            machineID,
            machineID
        )
    }

    /// Opens one canonical cloud port through the catalog's provider and
    /// projection path.
    ///
    /// The resource is inserted when a caller names a port before the next
    /// discovery pass. Its identity is always `<machine>/browser/port:<n>`;
    /// refreshing the provider can therefore replace its metadata without
    /// changing the row, projection, or CLI address.
    @discardableResult
    func openCloudPort(
        machine: SurfaceMachineID,
        port: Int,
        into destination: SurfaceDestination,
        focus: Bool,
        reuseExisting: Bool,
        reuseInWorkspace: UUID? = nil
    ) async throws -> (projection: SurfaceProjection, reused: Bool) {
        guard case .cloud = machine, (1...65_535).contains(port) else {
            throw SurfaceCatalogError.unsupported(
                String(localized: "cloudTree.port.invalidMachine", defaultValue: "Ports can only be opened on a cloud machine.")
            )
        }
        guard let provider = provider(for: machine) else {
            throw SurfaceCatalogError.noProvider(machine)
        }
        guard provider.supportsPortPreviews else {
            throw SurfaceCatalogError.unsupported(Self.portPreviewUnavailableMessage(machineID: machine.rawValue))
        }

        let id = SurfaceResourceID(machine: machine, kind: .browser, key: SurfaceResourceID.portKey(port))
        let directURL = provider.info.privateAddress.map {
            CmuxInternalHostnames.directPortURL(privateAddress: $0, port: port)
        }
        if var existing = resources[id] {
            // A machine address can be assigned after the first catalog pass.
            // Refresh the URL in place while preserving workspace/view metadata.
            if existing.port != port || existing.url != directURL {
                existing.port = port
                existing.url = directURL
                upsert(existing)
            }
        } else {
            upsert(CmuxTuiSnapshotParser.portBrowser(machine: machine, port: port, directURL: directURL))
        }
        return try await project(
            id,
            into: destination,
            focus: focus,
            reuseExisting: reuseExisting,
            reuseInWorkspace: reuseInWorkspace
        )
    }

    /// Chooses the local workspace that already shows the cloud machine's
    /// resources, falling back to the caller's captured workspace. When a
    /// resource carries remote-workspace membership, only sibling resources in
    /// those remote workspaces participate in the vote; this keeps a port from
    /// following an unrelated machine workspace.
    func preferredLocalWorkspaceID(
        for resourceID: SurfaceResourceID,
        fallback: UUID?
    ) -> UUID? {
        // Keep the lookup useful when a refresh retired the resource after a row
        // was rendered: a live projection still gives us an unambiguous owner.
        let resource = resources[resourceID]
        if let resource {
            return preferredLocalWorkspaceID(for: resource, fallback: fallback)
        }
        return projections.first(where: { $0.resource == resourceID })?.workspaceID ?? fallback
    }

    /// Resolves the local workspace for a value captured from a tree snapshot.
    /// Callers that begin an asynchronous open use this overload before yielding
    /// so a later catalog replacement cannot erase the remote-workspace context.
    func preferredLocalWorkspaceID(
        for resource: SurfaceResource,
        fallback: UUID?
    ) -> UUID? {
        let machine = resource.machine
        let remoteWorkspaceIDs = Set(resource.remoteWorkspaces.map(\.id))
        guard !remoteWorkspaceIDs.isEmpty else {
            // A machine-pool port has no remote workspace owner. Never infer one
            // from unrelated projections on the same machine.
            return projections.first(where: { $0.resource == resource.id })?.workspaceID ?? fallback
        }
        var relatedIDs = Set([resource.id])
        relatedIDs.formUnion(resources.values.compactMap { candidate -> SurfaceResourceID? in
            guard candidate.machine == machine else { return nil }
            return candidate.remoteWorkspaces.contains { remoteWorkspaceIDs.contains($0.id) }
                ? candidate.id
                : nil
        })

        var projectionCounts: [UUID: Int] = [:]
        for projection in projections where relatedIDs.contains(projection.resource) {
            projectionCounts[projection.workspaceID, default: 0] += 1
        }
        // Select the same highest-count/lowest-UUID winner as
        // `CloudTreeNodeBuilder.localWorkspaceShowing`, but in one pass. This
        // path runs for every port-row open, so sorting all local workspaces
        // needlessly turns a linear vote into O(W log W).
        var winner: (id: UUID, count: Int)?
        for (id, count) in projectionCounts {
            guard let current = winner else {
                winner = (id, count)
                continue
            }
            if count > current.count
                || (count == current.count && id.uuidString < current.id.uuidString) {
                winner = (id, count)
            }
        }
        return winner?.id ?? fallback
    }

    /// Keeps a port that was added or reopened while a provider refresh was
    /// suspended. `replaceResources` is intentionally authoritative for the
    /// provider snapshot, but it must not erase a just-started open (or a pane
    /// that is still live) between the scan and publication of that snapshot.
    func preservingConcurrentPortResources(
        _ refreshed: [SurfaceResource],
        on machine: SurfaceMachineID,
        since previous: [SurfaceResource]
    ) -> [SurfaceResource] {
        let refreshedIDs = Set(refreshed.map(\.id))
        let previousIDs = Set(previous.map(\.id))
        let projectedResourceIDs = Set(projections.map(\.resource))
        var result = refreshed
        for candidate in snapshot.resources(on: machine)
        where candidate.id.isForwardedPort
            && !CmuxTuiSnapshotParser.internalPorts.contains(candidate.id.forwardedPort ?? -1)
            && !refreshedIDs.contains(candidate.id) {
            let wasAddedDuringRefresh = !previousIDs.contains(candidate.id)
            let remainsProjected = projectedResourceIDs.contains(candidate.id)
            guard wasAddedDuringRefresh || remainsProjected else { continue }
            result.append(candidate)
        }
        return result
    }
}
