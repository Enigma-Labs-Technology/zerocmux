import Foundation

/// What a cloud machine is for, independent of which image id the control
/// plane happens to deploy for it today.
///
/// Clients request machines by kind and let the backend map the kind to the
/// image its environment supports (the provider's `_DESKTOP_IMAGE` selector,
/// its base image selector, or the deployed manifest default). Pinning an
/// image id on the client broke every build whose id drifted from the web
/// deploy's manifest (`vm_image_config_error`), so the id is never sent unless
/// a person passes `--image` explicitly.
public enum VMMachineKind: String, CaseIterable, Sendable, Equatable {
    /// Devtools, coding agents, and a desktop with a noVNC screen.
    case desktop
    /// Shell-only machine: same devtools, no screen.
    case base

    /// The kind an image id implies when the backend did not say. Older
    /// control planes omit `kind`; a desktop image carries a recognizable
    /// name, everything else is a shell box.
    ///
    /// Only VNC markers count. `devbox` used to imply a desktop because one
    /// provider's devbox image bundled xfce + noVNC; historical devbox images
    /// could also be shell-only, so matching it here published a Desktop
    /// surface for machines with no screen. Current images report their kind.
    /// - Parameter image: Legacy image identifier to classify.
    /// - Returns: The inferred machine kind.
    public static func inferred(fromImage image: String) -> VMMachineKind {
        let lowered = image.lowercased()
        return lowered.contains("xfce") || lowered.contains("vnc") ? .desktop : .base
    }

    /// The kind a backend payload describes: its explicit `kind` field when
    /// present and valid, otherwise inferred from the image id.
    /// - Parameters:
    ///   - rawKind: Optional kind received in a legacy payload.
    ///   - image: Optional image identifier used as a fallback.
    /// - Returns: The resolved legacy machine kind.
    public static func resolved(kind rawKind: Any?, image: Any?) -> VMMachineKind {
        if let raw = rawKind as? String, let kind = VMMachineKind(rawValue: raw.lowercased()) {
            return kind
        }
        return inferred(fromImage: (image as? String) ?? "")
    }

    /// The product default: every create path that does not ask for a kind
    /// (the New Machine sheet, bare `cmux vm new`, `vm base open` / `vm base
    /// reset`) gets the devbox with a screen. Base remains for historical machines.
    public static let defaultKind: VMMachineKind = .desktop

    /// The `cmux vm new` / `vm base open` / `vm base reset` flag that requests
    /// this kind. Always sent, so the create never depends on a server default.
    public var cliFlag: String {
        switch self {
        case .desktop: return "--desktop"
        case .base: return "--base"
        }
    }

    /// Whether this legacy machine kind includes a desktop.
    public var hasDesktop: Bool { self == .desktop }

    /// The localized name of this legacy machine kind.
    public var displayName: String {
        switch self {
        case .desktop:
            return String(localized: "machines.kind.desktop", defaultValue: "Desktop")
        case .base:
            return String(localized: "machines.kind.base", defaultValue: "Base")
        }
    }


}
