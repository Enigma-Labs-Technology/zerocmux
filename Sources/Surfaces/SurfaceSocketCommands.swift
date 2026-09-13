import CmuxControlSocket
import CmuxSettings
import Foundation

// The socket face of the surface catalog: `surface.catalog`, `surface.project`,
// `surface.new_terminal`, and the `vm.tree` / `vm.terminal_open` / `vm.terminal_new` /
// `vm.desktop_open` / `vm.port_open` / `vm.link_socket` verbs that are now thin wrappers
// over the same catalog. Every entrypoint (sidebar, CLI, agents) opens a surface through
// `SurfaceCatalog.project`, so "is it open?" and "where does it land?" have one answer.
//
// Lane (ControlCommandExecutionPolicy): socket worker. These await main-actor catalog work
// that can sit on the network (a cloud provider materializing a pane), so they must never
// hold the main actor; `v2VmCall` parks the worker while the catalog runs on the main actor.
// Focus policy: `focus` defaults to true for explicit opens (the caller asked for a pane)
// and false for desktop/port opens; the catalog never activates the app either way.
extension TerminalController {
    private nonisolated func cloudDisabledSocketError(id: Any?) -> String? {
        hostedSurfaceUnavailable(id: id)
    }

    nonisolated func hostedSurfaceUnavailable(id: Any?) -> String {
        v2Error(id: id, code: "unavailable", message: VMClientUnavailable.message)
    }

    nonisolated func socketWorkerSurfaceResponse(method: String, id: Any?, params: [String: Any]) -> String {
        switch method {
        case "surface.catalog":
            let machine = Self.surfaceMachineFilter(params["machine"])
            if let machine, machine.cloudMachineID != nil, let error = cloudDisabledSocketError(id: id) { return error }
            let refresh = Self.surfaceBool(params["refresh"]) ?? false
            return v2VmCall(id: id, timeoutSeconds: 120) {
                let query = await Self.surfaceCatalogQuery(catalog: .shared)
                let export = await query.read(machine: machine, refresh: refresh)
                return Self.surfaceCatalogPayload(export, machine: machine)
            }

        case "surface.project":
            guard let raw = Self.surfaceString(params["resource"]), let resource = SurfaceResourceID(rawValue: raw) else {
                return v2Error(id: id, code: "invalid_params", message: "surface.project requires `resource` (an id from `cmux surface ls --json`, e.g. vivid-newt/terminal/term_…).")
            }
            if resource.machine.cloudMachineID != nil, let error = cloudDisabledSocketError(id: id) { return error }
            let focus = Self.surfaceBool(params["focus"]) ?? true
            let reuse = Self.surfaceBool(params["reuse"]) ?? true
            let remoteTabID = Self.surfaceString(params["remote_tab_id"])
            let remoteWorkspaceID = Self.surfaceString(params["remote_workspace_id"])
            guard let workspaceID = surfaceTargetWorkspaceID(params) else {
                return v2Error(id: id, code: "invalid_params", message: "surface.project: no target workspace (pass `workspace_id`, or select one).")
            }
            let destination = Self.surfaceDestination(surfaceResolvedParams(params), workspaceID: workspaceID)
            return v2VmCall(id: id, timeoutSeconds: 180) {
                let catalog = await SurfaceCatalog.shared
                let remoteView = try await catalog.remoteView(
                    for: resource,
                    tabID: remoteTabID,
                    workspaceID: remoteWorkspaceID
                )
                let opened = try await catalog.project(
                    resource,
                    into: destination,
                    focus: focus,
                    reuseExisting: reuse,
                    remoteView: remoteView
                )
                return Self.surfaceProjectPayload(opened.projection, reused: opened.reused)
            }

        case "surface.new_terminal":
            guard let machineRaw = Self.surfaceString(params["machine"]), !machineRaw.isEmpty else {
                return v2Error(id: id, code: "invalid_params", message: "surface.new_terminal requires `machine` (\"local\" or a cloud machine id).")
            }
            let machine = SurfaceMachineID(rawValue: machineRaw)
            if machine.cloudMachineID != nil, let error = cloudDisabledSocketError(id: id) { return error }
            let command = Self.surfaceStringArray(params["command"])
            let cwd = Self.surfaceString(params["cwd"])
            let name = Self.surfaceString(params["name"])
            let remoteWorkspaceID = Self.surfaceString(params["remote_workspace_id"])
            let open = Self.surfaceBool(params["open"]) ?? true
            let focus = Self.surfaceBool(params["focus"]) ?? true
            let workspaceID = open ? surfaceTargetWorkspaceID(params) : nil
            if open, workspaceID == nil {
                return v2Error(id: id, code: "invalid_params", message: "surface.new_terminal: no target workspace to open into (pass `workspace_id`, select one, or send `open: false`).")
            }
            let destination = workspaceID.map { Self.surfaceDestination(surfaceResolvedParams(params), workspaceID: $0) }
            return v2VmCall(id: id, timeoutSeconds: 240) {
                try await Self.surfaceNewTerminal(
                    machine: machine,
                    command: command.isEmpty ? nil : command,
                    cwd: cwd,
                    name: name,
                    remoteWorkspaceID: remoteWorkspaceID,
                    destination: destination,
                    focus: focus
                )
            }

        default:
            return v2Error(id: id, code: "method_not_found", message: "Unknown method")
        }
    }

    // MARK: - vm.* wrappers (kept for existing callers; same catalog underneath)

    /// `vm.tree {id?, refresh?}`: the catalog payload restricted to cloud machines.
    nonisolated func socketWorkerVMTreeResponse(id: Any?, params: [String: Any]) -> String {
        hostedSurfaceUnavailable(id: id)
    }

    /// `vm.terminal_open {id, terminal_id, workspace_id?, placement?, focus?, pane_id?, direction?, tab_index?}`
    /// → `{surface_id, workspace_id, reused}`.
    nonisolated func socketWorkerVMTerminalOpenResponse(id: Any?, params: [String: Any]) -> String {
        hostedSurfaceUnavailable(id: id)
    }

    /// `vm.terminal_new {id, workspace_id?: ws_… (remote), command?, cwd?, name?, open?, local_workspace_id?, focus?, …dest}`
    /// → `{terminal_id, workspace_id (remote ws_…), surface_id?, resource}`.
    nonisolated func socketWorkerVMTerminalNewResponse(id: Any?, params: [String: Any]) -> String {
        hostedSurfaceUnavailable(id: id)
    }

    /// `vm.desktop_open {id, workspace_id?, focus?, …dest}` → `{surface_id, workspace_id, url, open_url}`;
    /// an empty object when the machine has no desktop.
    nonisolated func socketWorkerVMDesktopOpenResponse(id: Any?, params: [String: Any]) -> String {
        hostedSurfaceUnavailable(id: id)
    }

    /// `vm.port_open {id, port, workspace_id?, …dest}` → `{surface_id, workspace_id, url, open_url}`.
    nonisolated func socketWorkerVMPortOpenResponse(id: Any?, params: [String: Any]) -> String {
        hostedSurfaceUnavailable(id: id)
    }

    /// `vm.link_socket {id}` → `{socket_path, session}`.
    nonisolated func socketWorkerVMLinkSocketResponse(id: Any?, params: [String: Any]) -> String {
        hostedSurfaceUnavailable(id: id)
    }

    /// `vm.workspace_new {id, name?, focus?, open?}` → creates a cmux-tui workspace on the
    /// machine and, when opened, gives it a starter terminal and projects it locally. A
    /// headless request stages that same workspace without projecting it locally.
    nonisolated func socketWorkerVMWorkspaceNewResponse(id: Any?, params: [String: Any]) -> String {
        hostedSurfaceUnavailable(id: id)
    }

    /// Opens an existing machine workspace as a new local workspace the way
    /// `vm.workspace_open` does, giving an EMPTY workspace a starter terminal first (the
    /// ⌘N contract), so `vm workspace new --reuse` always lands the caller somewhere.

    /// `vm.workspace_open {id, workspace_id, here?, …dest}` → the remote workspace's terminals
    /// and browsers. Default: a new local workspace, every one its own pane (what clicking
    /// the row does). `here: true`: into an existing local workspace the way "Open All Here"
    /// / "Open All in New Tabs" / a drop onto a pane edge do — one pane at the destination
    /// (`target_workspace_id`, `pane_id` + `direction`, `placement: split|tab`), the rest as
    /// tabs in it.
    nonisolated func socketWorkerVMWorkspaceOpenResponse(id: Any?, params: [String: Any]) -> String {
        hostedSurfaceUnavailable(id: id)
    }

    /// `vm.workspace_close {id, workspace_id}` → closes the cmux-tui workspace; its
    /// terminals KEEP RUNNING and detach into the Terminals pool (the sidebar's "Close
    /// Workspace (Keep Terminals)"). Use `vm.workspace_delete` to also kill them.
    nonisolated func socketWorkerVMWorkspaceCloseResponse(id: Any?, params: [String: Any]) -> String {
        hostedSurfaceUnavailable(id: id)
    }

    /// `vm.workspace_delete {id, workspace_id}` → kills every terminal viewed in the
    /// workspace, then closes it — the sidebar's "Delete Workspace and Terminals…",
    /// over the same `CloudTreeNodeActions.deleteWorkspaceAndTerminals` the row runs.
    nonisolated func socketWorkerVMWorkspaceDeleteResponse(id: Any?, params: [String: Any]) -> String {
        hostedSurfaceUnavailable(id: id)
    }

    /// `vm.workspace_rename {id, workspace_id, name}` → renames the cmux-tui workspace
    /// (the sidebar's "Rename…", through the catalog's shared mutation lane).
    nonisolated func socketWorkerVMWorkspaceRenameResponse(id: Any?, params: [String: Any]) -> String {
        hostedSurfaceUnavailable(id: id)
    }

    /// `vm.terminal_rename {id, terminal_id, name}` → names the terminal's daemon tab
    /// view(s) on the machine; every client shows it in place of the PTY title.
    nonisolated func socketWorkerVMTerminalRenameResponse(id: Any?, params: [String: Any]) -> String {
        hostedSurfaceUnavailable(id: id)
    }

    /// Async socket counterpart for `vm.terminal_rename`. The legacy synchronous
    /// entrypoint remains for in-process callers, while real socket connections use
    /// this method so the worker pool stays available during the cloud round trip.
    @MainActor
    func socketWorkerVMTerminalRenameResponseAsync(_ request: ControlRequest) async -> String {
        hostedSurfaceUnavailable(id: request.id?.foundationObject)
    }

    /// `vm.tab_rename {id, tab_id, name}` → renames exactly one placement-local
    /// daemon tab. Terminal identity is intentionally not accepted here because a
    /// terminal can be present in several tabs with different names.
    nonisolated func socketWorkerVMTabRenameResponse(id: Any?, params: [String: Any]) -> String {
        hostedSurfaceUnavailable(id: id)
    }

    @MainActor
    func socketWorkerVMTabRenameResponseAsync(_ request: ControlRequest) async -> String {
        hostedSurfaceUnavailable(id: request.id?.foundationObject)
    }

    /// Socket callers need a stable, actionable message. Provider and catalog
    /// errors can contain machine, workspace, or tunnel identifiers, so keep
    /// those details in the local debug log only.
    private nonisolated func cloudRenameSocketError(id: Any?, operation: String, error: Error) -> String {
        #if DEBUG
        cmuxDebugLog("cloud.socket.rename.failed operation=\(operation) error=\(String(reflecting: error))")
        #endif
        return v2Error(
            id: id,
            code: "vm_error",
            message: String(
                localized: "socket.vm.renameFailed",
                defaultValue: "The remote name could not be changed. Refresh and try again."
            )
        )
    }

    /// `vm.terminal_close {id, terminal_id}` → ends that terminal on the machine.
    nonisolated func socketWorkerVMTerminalCloseResponse(id: Any?, params: [String: Any]) -> String {
        hostedSurfaceUnavailable(id: id)
    }

    // MARK: - Headless terminal I/O (agent primitives)

    /// The cmux-tui provider for a cloud machine; the local machine and any provider
    /// without a remote session have no headless terminal I/O.

    /// `vm.env_set {id, entries: [{key, value}]}` → the machine's `~/.config/cmux/env`
    /// gains (or overwrites) those variables. Values travel over the machine's link into
    /// the in-VM `cmux env receive` (see `CloudEnvDelivery`): never through `vm.exec`, a
    /// command line, or a terminal's visible screen. The result names keys only.
    nonisolated func socketWorkerVMEnvSetResponse(id: Any?, params: [String: Any]) -> String {
        hostedSurfaceUnavailable(id: id)
    }

    /// `vm.terminal_write {id, terminal_id, text?, keys?}` → types `text` (as-is, no
    /// newline) and then presses `keys` (named: enter, escape, tab, up; chords join with
    /// `+`: ctrl+c — verified live, `ctrl-c` is rejected) in the remote terminal.
    /// Nothing is attached or focused; the terminal's panes, if any, simply show it.
    nonisolated func socketWorkerVMTerminalWriteResponse(id: Any?, params: [String: Any]) -> String {
        hostedSurfaceUnavailable(id: id)
    }

    /// `vm.terminal_read {id, terminal_id}` → the remote terminal's visible screen:
    /// `{text, rows, cols, cursor_row, cursor_col, cursor_visible}`.
    nonisolated func socketWorkerVMTerminalReadResponse(id: Any?, params: [String: Any]) -> String {
        hostedSurfaceUnavailable(id: id)
    }

    /// `vm.terminal_wait {id, terminal_id, pattern, timeout_ms?}` → blocks until the
    /// screen matches the regex (default 30 s): `{matched, text}`.
    nonisolated func socketWorkerVMTerminalWaitResponse(id: Any?, params: [String: Any]) -> String {
        hostedSurfaceUnavailable(id: id)
    }

    /// `vm.terminal_wait_exit {id, terminal_id, timeout_ms?}` → blocks until the terminal's
    /// PROCESS exits (default 30 s, at most an hour): `{state: "exited", outcome: {kind:
    /// exit, code} | {kind: signal, signal, core_dumped} | {kind: unknown, reason},
    /// exited_at, …}` or `{state: "pending", lifecycle, …}` when it is still running.
    nonisolated func socketWorkerVMTerminalWaitExitResponse(id: Any?, params: [String: Any]) -> String {
        hostedSurfaceUnavailable(id: id)
    }

    /// `vm.terminal_output {id, terminal_id, after?, max_bytes?}` → the terminal's retained
    /// output: `{text, start_offset, next_offset, complete}`. `after` is a `next_offset`
    /// from an earlier call (read only what is new); `max_bytes` caps one window
    /// (1…4 MiB, daemon default 256 KiB).
    nonisolated func socketWorkerVMTerminalOutputResponse(id: Any?, params: [String: Any]) -> String {
        hostedSurfaceUnavailable(id: id)
    }

    // MARK: - Shared pieces

    /// The catalog's provider for `machine`; a cloud machine the catalog has not seen yet
    /// (just created) gets one fleet re-read before the caller reports "no provider".
    nonisolated static func surfaceProvider(for machine: SurfaceMachineID, catalog: SurfaceCatalog) async throws -> (any SurfaceProvider)? {
        let query = await surfaceCatalogQuery(catalog: catalog)
        return await query.provider(for: machine)
    }

    @MainActor
    private static func surfaceCatalogQuery(catalog: SurfaceCatalog) -> SurfaceCatalogQueryService {
        SurfaceCatalogQueryService(catalog: catalog) { _ in }
    }

    /// `vm.workspace_open`'s workspace resolution — the sidebar row's own
    /// (`CloudTreeNodeBuilder.lookupRemoteWorkspace`), so `cmux vm workspace open`
    /// and a click on the row open the same set. A `ws_…` id or an unambiguous
    /// name; an existing workspace with nothing in it is an error that says so
    /// (the row opens nothing for it either, D9) and names the verb that starts
    /// a terminal there.

    /// Creates a terminal on `machine` through its provider and, when a destination is given,
    /// projects it there. Payload: `resource`, `terminal_id` (the provider key), `machine`,
    /// `remote_workspace_id`, and — when opened — `workspace_id` (local) + `surface_id`.
    nonisolated static func surfaceNewTerminal(
        machine: SurfaceMachineID,
        command: [String]?,
        cwd: String?,
        name: String?,
        remoteWorkspaceID: String?,
        destination: SurfaceDestination?,
        focus: Bool
    ) async throws -> [String: Any] {
        let catalog = await SurfaceCatalog.shared
        guard let provider = try await Self.surfaceProvider(for: machine, catalog: catalog) else {
            throw SurfaceCatalogError.noProvider(machine)
        }
        let resource = try await provider.createTerminal(command: command, cwd: cwd, name: name, remoteWorkspaceID: remoteWorkspaceID)
        var payload: [String: Any] = [
            "resource": resource.id.rawValue,
            "terminal_id": resource.id.key,
            "machine": machine.rawValue,
            "remote_workspace_id": resource.remoteWorkspace?.id ?? NSNull(),
        ]
        if let destination {
            let opened = try await catalog.project(
                resource.id,
                into: destination,
                focus: focus,
                reuseExisting: false,
                remoteView: resource.remoteViews?.count == 1 ? resource.remoteViews?.first : nil
            )
            payload["workspace_id"] = opened.projection.workspaceID.uuidString
            payload["surface_id"] = opened.projection.panelID.uuidString
        }
        return payload
    }

    /// The local workspace an open lands in: `workspace_id` (UUID or `workspace:N` ref), else
    /// the workspace of a given `pane_id`/`surface_id`, else the selected workspace. When
    /// `strictExplicit` is true, an explicit but stale/malformed pane or surface is rejected
    /// instead of silently falling through to the selected workspace (used by `vm.port_open`).
    nonisolated func surfaceTargetWorkspaceID(_ params: [String: Any], strictExplicit: Bool = false) -> UUID? {
        if strictExplicit {
            if v2HasNonNullParam(params, "workspace_id") {
                guard let explicit = v2UUID(params, "workspace_id") else { return nil }
                return explicit
            }
            if v2HasNonNullParam(params, "pane_id") {
                guard let paneID = v2UUID(params, "pane_id"),
                      let located = v2MainSync({ self.v2LocatePane(paneID) }) else {
                    return nil
                }
                return located.workspace.id
            }
            if v2HasNonNullParam(params, "surface_id") {
                guard let surfaceID = v2UUID(params, "surface_id") else { return nil }
                let owner = v2MainSync { () -> UUID? in
                    guard let tabManager = self.tabManager else { return nil }
                    return tabManager.tabs.first(where: { $0.panels[surfaceID] != nil })?.id
                }
                return owner
            }
        }
        if let explicit = v2UUID(params, "workspace_id") {
            return explicit
        }
        if let paneID = v2UUID(params, "pane_id"), let located = v2MainSync({ self.v2LocatePane(paneID) }) {
            return located.workspace.id
        }
        if let surfaceID = v2UUID(params, "surface_id") {
            let owner = v2MainSync { () -> UUID? in
                guard let tabManager = self.tabManager else { return nil }
                return tabManager.tabs.first(where: { $0.panels[surfaceID] != nil })?.id
            }
            if let owner { return owner }
        }
        return v2MainSync { self.tabManager?.selectedTabId }
    }

    /// `pane_id` / `surface_id` may be UUIDs or handle refs (`pane:3`, `surface:7`); the pure
    /// destination mapper needs pane UUIDs, so resolve refs here and turn a surface into the
    /// pane that holds it.
    nonisolated func surfaceResolvedParams(_ params: [String: Any]) -> [String: Any] {
        var resolved = params
        if let paneID = v2UUID(params, "pane_id") {
            resolved["pane_id"] = paneID.uuidString
        }
        if resolved["pane_id"] == nil, let surfaceID = v2UUID(params, "surface_id") {
            let paneID = v2MainSync { () -> String? in
                guard let tabManager = self.tabManager,
                      let workspace = tabManager.tabs.first(where: { $0.panels[surfaceID] != nil }) else { return nil }
                return SurfacePaneFactory.paneID(ofPanel: surfaceID, in: workspace.id)
            }
            if let paneID {
                resolved["pane_id"] = paneID
                resolved["surface_id"] = nil
            }
        }
        return resolved
    }

    /// Destination from the shared params: `pane_id` + `direction` → split that pane on that
    /// side; `pane_id` + `tab_index` (or `placement: tab`) → a tab in that pane; otherwise the
    /// workspace's focused pane (`placement`, default split). Pure.
    nonisolated static func surfaceDestination(_ params: [String: Any], workspaceID: UUID) -> SurfaceDestination {
        let paneID = surfaceString(params["pane_id"]) ?? surfaceString(params["surface_id"])
        let placement = surfaceString(params["placement"]).flatMap { SurfacePlacement(rawValue: $0.lowercased()) } ?? .split
        let direction = surfaceString(params["direction"]).flatMap { SurfaceSplitDirection(rawValue: $0.lowercased()) }
        let tabIndex = surfaceInt(params["tab_index"])
        if let paneID, let direction {
            return .split(workspaceID: workspaceID, paneID: paneID, direction: direction)
        }
        if let paneID, (tabIndex != nil || placement == .tab) {
            return .tab(workspaceID: workspaceID, paneID: paneID, index: tabIndex)
        }
        if let paneID {
            return .split(workspaceID: workspaceID, paneID: paneID, direction: .right)
        }
        return .workspace(id: workspaceID, placement: placement)
    }

    nonisolated static func surfaceMachineFilter(_ raw: Any?) -> SurfaceMachineID? {
        guard let value = surfaceString(raw), !value.isEmpty else { return nil }
        return SurfaceMachineID(rawValue: value)
    }

    // MARK: Wire payloads (snake_case; the same shape the CLI and the sidebar read)

    nonisolated static func surfaceCatalogPayload(_ export: SurfaceCatalogExport, machine: SurfaceMachineID?, cloudOnly: Bool = false) -> [String: Any] {
        let snapshot = export.catalog
        let machines = snapshot.machines.filter { info in
            if cloudOnly, info.id.isLocal { return false }
            if let machine { return info.id == machine }
            return true
        }
        let included = Set(machines.map { $0.id })
        let resources = snapshot.resources.filter { included.contains($0.machine) }
        let resourceIDs = Set(resources.map { $0.id })
        let projections = snapshot.projections.filter { resourceIDs.contains($0.resource) }
        let cloudStates = export.cloudStates.filter { state in
            included.contains(state.machine)
        }
        let cloudStateObservations = export.cloudStateObservations
        var openPanels: [SurfaceResourceID: [SurfaceProjection]] = [:]
        for projection in projections {
            openPanels[projection.resource, default: []].append(projection)
        }
        return [
            "machines": machines.map(surfaceMachinePayload),
            "resources": resources.map { surfaceResourcePayload($0, projections: openPanels[$0.id] ?? []) },
            "projections": projections.map(surfaceProjectionPayload),
            "cloud_states": cloudStates.map { state in
                surfaceCloudStatePayload(
                    state,
                    observation: cloudStateObservations[state.machine] ?? .current
                )
            },
        ]
    }

    nonisolated static func surfaceMachinePayload(_ info: SurfaceMachineInfo) -> [String: Any] {
        [
            "id": info.id.rawValue,
            "local": info.id.isLocal,
            "name": info.name,
            "status": info.status,
            "image": info.image ?? NSNull(),
            "has_desktop": info.hasDesktop,
            "memory_mb": info.memoryMb ?? NSNull(),
            "disk_mb": info.diskMb ?? NSNull(),
            "link_state": info.linkState.rawValue,
            "link_error": info.linkError ?? NSNull(),
            "cpu_percent": info.cpuPercent ?? NSNull(),
            "memory_used_mb": info.memoryUsedMb ?? NSNull(),
            "disk_used_mb": info.diskUsedMb ?? NSNull(),
            "remote_workspaces": info.remoteWorkspaces.map { $0.map(surfaceRemoteWorkspacePayload) } ?? NSNull(),
        ]
    }

    nonisolated static func surfaceResourcePayload(_ resource: SurfaceResource, projections: [SurfaceProjection]) -> [String: Any] {
        var payload: [String: Any] = [
            "id": resource.id.rawValue,
            "machine": resource.machine.rawValue,
            "kind": resource.kind.rawValue,
            "key": resource.id.key,
            "title": resource.title,
            "detail": resource.detail ?? NSNull(),
            "lifecycle": resource.lifecycle.rawValue,
            "port": resource.port ?? NSNull(),
            "url": resource.url ?? NSNull(),
            "open": !projections.isEmpty,
            "open_surface_ids": projections.map { $0.panelID.uuidString },
            "open_workspace_ids": projections.map { $0.workspaceID.uuidString },
        ]
        if let agent = resource.agent {
            payload["agent"] = ["state": agent.state, "source": agent.source ?? NSNull()] as [String: Any]
        } else {
            payload["agent"] = NSNull()
        }
        if let workspace = resource.remoteWorkspace {
            payload["remote_workspace"] = surfaceRemoteWorkspacePayload(workspace)
        } else {
            payload["remote_workspace"] = NSNull()
        }
        // All views of the resource (one per daemon tab). null = the provider does not
        // model views; [] = alive with zero views (the machine's pool).
        if let views = resource.remoteViews {
            payload["view_count"] = views.count
            payload["remote_views"] = views.map { view in
                [
                    "tab_id": view.tabID,
                    "workspace": surfaceRemoteWorkspacePayload(view.workspace),
                    "screen_id": view.screenID ?? NSNull(),
                    "pane_id": view.paneID ?? NSNull(),
                    "name": view.name ?? NSNull(),
                    "index": view.index ?? NSNull(),
                    "focused": view.focused ?? NSNull(),
                    "screen_index": view.screenIndex ?? NSNull(),
                    "pane_index": view.paneIndex ?? NSNull(),
                ] as [String: Any]
            }
        } else {
            payload["view_count"] = NSNull()
            payload["remote_views"] = NSNull()
        }
        return payload
    }

    nonisolated static func surfaceRemoteWorkspacePayload(_ workspace: SurfaceRemoteWorkspace) -> [String: Any] {
        [
            "id": workspace.id,
            "name": workspace.name,
            "index": workspace.index,
            "focused": workspace.focused,
        ]
    }

    nonisolated static func surfaceProjectionPayload(_ projection: SurfaceProjection) -> [String: Any] {
        [
            "resource": projection.resource.rawValue,
            "workspace_id": projection.workspaceID.uuidString,
            "panel_id": projection.panelID.uuidString,
            "surface_id": projection.panelID.uuidString,
            "remote_workspace_id": projection.remoteWorkspaceID ?? NSNull(),
            "remote_tab_id": projection.remoteTabID ?? NSNull(),
        ]
    }

    nonisolated static func surfaceProjectPayload(_ projection: SurfaceProjection, reused: Bool) -> [String: Any] {
        [
            "resource": projection.resource.rawValue,
            "workspace_id": projection.workspaceID.uuidString,
            "surface_id": projection.panelID.uuidString,
            "panel_id": projection.panelID.uuidString,
            "reused": reused,
            "remote_workspace_id": projection.remoteWorkspaceID ?? NSNull(),
            "remote_tab_id": projection.remoteTabID ?? NSNull(),
        ]
    }

    /// Agent-facing complete state. The typed graph makes common joins cheap;
    /// snapshot retains every daemon field, including fields this build does not
    /// know yet, after credential-like fields pass through the redaction boundary.
    /// Synchronization keeps the unredacted bytes internally.
    nonisolated static func surfaceCloudStatePayload(
        _ state: CloudVMState,
        observation: CloudVMStateObservation = .current
    ) -> [String: Any] {
        func optional(_ value: String?) -> Any { value ?? NSNull() }
        let snapshot: Any = state.agentSnapshotObject() ?? NSNull()
        let cursor: Any = state.cursor.map { [
            "generation": $0.generation,
            "revision": String($0.revision),
        ] as [String: Any] } ?? NSNull()
        let pendingWrites: [[String: Any]] = (observation.pendingWrites ?? []).map { pending in
            [
                "kind": pending.kind.rawValue,
                "resource": pending.resource?.rawValue ?? NSNull(),
                "remote_workspace_id": pending.remoteWorkspaceID ?? NSNull(),
                "remote_tab_id": pending.remoteTabID ?? NSNull(),
                "name": pending.name ?? NSNull(),
                "receipt": pending.receipt.map {
                    ["generation": $0.generation, "revision": String($0.revision)] as [String: Any]
                } ?? NSNull(),
            ]
        }
        return [
            "machine": state.machine.rawValue,
            "cursor": cursor,
            "sync_mode": state.syncMode.rawValue,
            "freshness": observation.freshness.rawValue,
            "stale_reason": observation.reason ?? NSNull(),
            "pending_writes": pendingWrites,
            "workspaces": state.workspaces.map { [
                "id": $0.id, "name": $0.name, "index": $0.index, "focused": $0.focused,
            ] as [String: Any] },
            "screens": state.screens.map { [
                "id": $0.id, "workspace_id": $0.workspaceID, "name": optional($0.name),
                "index": $0.index, "focused": $0.focused, "layout": $0.layout.flatMap { try? JSONSerialization.jsonObject(with: $0) } ?? NSNull(),
            ] as [String: Any] },
            "panes": state.panes.map { [
                "id": $0.id, "screen_id": $0.screenID, "name": optional($0.name),
                "focused": $0.focused, "zoomed": $0.zoomed, "tab_ids": $0.tabIDs,
            ] as [String: Any] },
            "tabs": state.tabs.map { [
                "id": $0.id, "pane_id": $0.paneID, "name": optional($0.name),
                "index": $0.index, "focused": $0.focused, "content_kind": $0.contentKind, "content_id": $0.contentID,
            ] as [String: Any] },
            "terminals": state.terminals.map { [
                "id": $0.id, "tab_ids": $0.tabIDs, "title": $0.title, "cwd": optional($0.cwd),
                "lifecycle": $0.lifecycle, "cols": $0.cols ?? NSNull(), "rows": $0.rows ?? NSNull(), "running": $0.running ?? NSNull(),
            ] as [String: Any] },
            "browsers": state.browsers.map { [
                "id": $0.id, "tab_id": $0.tabID, "url": $0.url, "title": $0.title, "status": $0.status,
            ] as [String: Any] },
            "agents": state.agents.map { [
                "id": optional($0.id), "terminal_id": $0.terminalID, "state": $0.state, "source": optional($0.source),
            ] as [String: Any] },
            "other_entities": state.otherEntities.map { entity in
                [
                    "kind": entity.kind,
                    "id": entity.id ?? NSNull(),
                    "value": state.agentEntityObject(entity),
                ] as [String: Any]
            },
            "snapshot_redacted": true,
            "snapshot": snapshot,
        ]
    }

    // MARK: Param helpers (nonisolated; the worker parses before hopping to the main actor)

    nonisolated static func surfaceString(_ raw: Any?) -> String? {
        guard let value = raw as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Reads a required string while preserving an explicit empty value. Most
    /// identifiers use ``surfaceString`` because empty means missing there.
    /// Rename commands are different: an empty string is the wire-level clear
    /// operation, while a missing or null value is a malformed request.
    nonisolated static func surfaceStringPreservingEmpty(_ raw: Any?) -> String? {
        guard let value = raw as? String else { return nil }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated static func surfaceBool(_ raw: Any?) -> Bool? {
        if let value = raw as? Bool { return value }
        if let number = raw as? NSNumber { return number.boolValue }
        if let text = raw as? String {
            switch text.lowercased() {
            case "true", "1", "yes": return true
            case "false", "0", "no": return false
            default: return nil
            }
        }
        return nil
    }

    nonisolated static func surfaceInt(_ raw: Any?) -> Int? {
        if let value = raw as? Int { return value }
        if let number = raw as? NSNumber { return number.intValue }
        if let text = raw as? String { return Int(text.trimmingCharacters(in: .whitespacesAndNewlines)) }
        return nil
    }

    nonisolated static func surfaceStringArray(_ raw: Any?) -> [String] {
        guard let array = raw as? [Any] else { return [] }
        return array.compactMap { surfaceString($0) }
    }
}

extension SurfaceResourceID {
    /// The key every provider uses for a machine's one VNC display (T10 makes this a list).
    static let desktopDisplayKey = "display:1"

    /// The key for the browser that shows a forwarded HTTP port.
    static func portKey(_ port: Int) -> String { "port:\(port)" }
}
