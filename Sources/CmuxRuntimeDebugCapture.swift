#if DEBUG
import Foundation

/// Writes explicitly enabled terminal probes to the local tagged debug log.
struct CmuxRuntimeDebugCapture {
    // The former URL/token/session environment configuration is deliberately ignored.
    // Debug builds follow the same zero-telemetry policy as release builds.
    private static let isEnabled = ProcessInfo.processInfo.environment["CMUX_RUNTIME_DEBUG_LOG"] == "1"

    static func logIfConfigured(
        hypothesisID: String,
        source: String,
        name: String,
        expected: String? = nil,
        actual: String? = nil,
        data: [String: Any] = [:]
    ) {
        guard isEnabled else { return }

        var payload: [String: Any] = [
            "hypothesis_id": hypothesisID,
            "source": source,
            "name": name,
            "data": data,
        ]
        if let expected {
            payload["expected"] = expected
        }
        if let actual {
            payload["actual"] = actual
        }
        guard JSONSerialization.isValidJSONObject(payload),
              let encoded = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
              let message = String(data: encoded, encoding: .utf8) else { return }
        cmuxDebugLog("runtime.probe \(message)")
    }
}
#endif
