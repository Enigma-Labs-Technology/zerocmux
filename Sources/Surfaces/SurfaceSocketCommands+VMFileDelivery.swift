import Foundation

extension TerminalController {
    /// `vm.file_put {id, path, mode?, data_base64}` → one file lands on the machine at
    /// `path` (mode `mode`, default 600) over its link, through the in-VM
    /// `cmux file receive` (see `CloudFileDelivery`): never through `vm.exec`, a command
    /// line, or a terminal's visible screen. Backs `cmux vm push --secret`.
    /// Result: `{machine, path, mode, bytes, transport: "link"}`.
    nonisolated func socketWorkerVMFilePutResponse(id: Any?, params: [String: Any]) -> String {
        hostedSurfaceUnavailable(id: id)
    }
}
