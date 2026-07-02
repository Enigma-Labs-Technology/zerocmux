/// A single command captured from a `Button`'s action closure.
///
/// The interpreter records the call shape; a host runtime executes it. The
/// `zerocmux` case maps onto zerocmux's socket command dispatcher (`method` + string
/// arguments), giving interpreted buttons the breadth of the zerocmux CLI.
public enum ActionCommand: Codable, Sendable, Equatable {
    /// A zerocmux command: a dispatcher method plus named string params, e.g.
    /// `zerocmux("workspace.select", workspace_id: w.id)` →
    /// `.cmux("workspace.select", ["workspace_id": "<uuid>"])`. Maps directly
    /// onto the socket command protocol (`{"method","params"}`).
    case zerocmux(method: String, params: [String: String])
    case log(String)
    /// Opens a URL (host runs it, e.g. via the workspace opener).
    case openURL(String)
}
