import Foundation

extension TerminalController {
    nonisolated func socketWorkerCloudVMResponse(
        method: String,
        id: Any?,
        params: [String: Any]
    ) -> String {
        _ = method
        _ = params
        return v2Error(
            id: id,
            code: "unavailable",
            message: VMClientUnavailable.message
        )
    }
}
