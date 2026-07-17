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

    /// zerocmux: the `remotes.*` phone-pairing registry was removed with the
    /// hosted backend; every method answers with the same unavailable error.
    nonisolated func socketWorkerRemotesResponse(
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

    /// zerocmux: the `aiAccounts.*` hosted AI-account registry was removed
    /// with the hosted backend; every method answers with the same
    /// unavailable error.
    nonisolated func socketWorkerAIAccountsResponse(
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
