import Foundation
import Testing
#if canImport(cmux_DEV)
@testable import cmux_DEV
#elseif canImport(cmux)
@testable import cmux
#endif

/// Exercise the public socket boundary retained for unavailable hosted commands.
@MainActor
@Suite(.serialized)
struct SurfaceSocketCommandTests {
    @Test(arguments: [
        "vm.tree", "vm.terminal_open", "vm.terminal_new", "vm.terminal_close",
        "vm.workspace_open", "vm.workspace_close", "vm.workspace_rename",
        "vm.workspace_delete", "vm.workspace_new"
    ])
    func hostedCommandsRemainUnavailable(method: String) async throws {
        let response = try await Self.call(method, ["id": "private-machine", "workspace_id": "private-workspace"])
        let error = try Self.error(response)
        #expect(error["code"] as? String == "unavailable")
        #expect(error["message"] as? String == VMClientUnavailable.message)
    }

    @Test func emptyWorkspaceHasARetryableSocketCode() async throws {
        let response = await Task.detached {
            TerminalController.shared.v2VmCall(id: "empty-workspace", timeoutSeconds: 5) {
                throw SurfaceCatalogError.nothingToOpen("workspace ws_pending")
            }
        }.value
        let object = try #require(JSONSerialization.jsonObject(with: Data(response.utf8)) as? [String: Any])
        #expect(try Self.error(object)["code"] as? String == "not_ready")
    }

    private nonisolated static func call(_ method: String, _ params: [String: Any]) async throws -> [String: Any] {
        let request: [String: Any] = ["jsonrpc": "2.0", "id": UUID().uuidString, "method": method, "params": params]
        let line = String(decoding: try JSONSerialization.data(withJSONObject: request), as: UTF8.self)
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let response = TerminalController.shared.handleSocketLine(line)
                do {
                    let object = try JSONSerialization.jsonObject(with: Data(response.utf8)) as? [String: Any]
                    continuation.resume(returning: object ?? [:])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func error(_ response: [String: Any]) throws -> [String: Any] {
        #expect(response["ok"] as? Bool == false, "expected an error, got \(response)")
        return try #require(response["error"] as? [String: Any])
    }
}
