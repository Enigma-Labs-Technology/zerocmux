public import Foundation

public enum SocketPathMarkerFiles {
    public static let stableMarkerFileName = "last-socket-path"
    public static let stableTmpPath = "/tmp/zerocmux-last-socket-path"
    public static let nightlyBundleIdentifier = "com.kernelalex.zerocmux.nightly"
    public static let stagingBundleIdentifier = "com.kernelalex.zerocmux.staging"
    public static let defaultBaseDebugBundleIdentifier = "com.kernelalex.zerocmux.debug"
    public static let defaultDebugSocketPath = "/tmp/zerocmux-debug.sock"
    public static let defaultNightlySocketPath = "/tmp/zerocmux-nightly.sock"
    public static let defaultStagingSocketPath = "/tmp/zerocmux-staging.sock"

    public static func markerFileURL(
        fileName: String = stableMarkerFileName,
        directory: URL?
    ) -> URL? {
        directory?.appendingPathComponent(fileName, isDirectory: false)
    }

    public static func paths(
        bundleIdentifier: String?,
        environment: [String: String],
        directory: URL?,
        baseDebugBundleIdentifier: String = defaultBaseDebugBundleIdentifier
    ) -> [String] {
        let variant = variant(
            bundleIdentifier: bundleIdentifier,
            environment: environment,
            baseDebugBundleIdentifier: baseDebugBundleIdentifier
        )
        var candidates: [String] = []
        if let directoryPath = markerFileURL(
            fileName: variant.markerFileName,
            directory: directory
        )?.path {
            candidates.append(directoryPath)
        }
        candidates.append(variant.tmpPath)
        return dedupe(candidates)
    }

    public static func variant(
        bundleIdentifier: String?,
        environment: [String: String],
        baseDebugBundleIdentifier: String = defaultBaseDebugBundleIdentifier
    ) -> SocketPathVariant {
        let bundleId = bundleIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if bundleId == nightlyBundleIdentifier {
            return .nightly(slug: nil)
        }
        let nightlyPrefix = nightlyBundleIdentifier + "."
        if bundleId.hasPrefix(nightlyPrefix) {
            return .nightly(slug: bundleSuffixSlug(bundleId, prefix: nightlyPrefix))
        }
        if bundleId == stagingBundleIdentifier {
            return .staging(slug: nil)
        }
        let stagingPrefix = stagingBundleIdentifier + "."
        if bundleId.hasPrefix(stagingPrefix) {
            return .staging(slug: bundleSuffixSlug(bundleId, prefix: stagingPrefix))
        }
        if bundleId == baseDebugBundleIdentifier {
            if let tag = normalized(environment["CMUX_TAG"]),
               let slug = sanitizeSocketSlug(tag) {
                return .dev(slug: slug)
            }
            return .dev(slug: nil)
        }
        if bundleId.hasPrefix("\(baseDebugBundleIdentifier).") {
            return .dev(slug: bundleSuffixSlug(bundleId, prefix: "\(baseDebugBundleIdentifier)."))
        }
        return .stable
    }

    public static func defaultSocketPath(
        bundleIdentifier: String?,
        environment: [String: String],
        isDebugBuild: Bool,
        stableSocketPath: String,
        baseDebugBundleIdentifier: String = defaultBaseDebugBundleIdentifier,
        debugSocketPath: String = defaultDebugSocketPath,
        nightlySocketPath: String = defaultNightlySocketPath,
        stagingSocketPath: String = defaultStagingSocketPath
    ) -> String {
        switch variant(
            bundleIdentifier: bundleIdentifier,
            environment: environment,
            baseDebugBundleIdentifier: baseDebugBundleIdentifier
        ) {
        case .stable:
            return isDebugBuild ? debugSocketPath : stableSocketPath
        case .nightly(let slug):
            if let slug {
                return "/tmp/zerocmux-nightly-\(slug).sock"
            }
            return nightlySocketPath
        case .staging(let slug):
            if let slug {
                return "/tmp/zerocmux-staging-\(slug).sock"
            }
            return stagingSocketPath
        case .dev(let slug):
            if let slug {
                return "/tmp/zerocmux-debug-\(slug).sock"
            }
            return debugSocketPath
        }
    }

    public static func sanitizeSocketSlug(_ raw: String) -> String? {
        let slug = raw
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return slug.isEmpty ? nil : slug
    }

    private static func bundleSuffixSlug(_ bundleIdentifier: String, prefix: String) -> String? {
        let suffix = String(bundleIdentifier.dropFirst(prefix.count))
        return sanitizeSocketSlug(suffix)
    }

    private static func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func dedupe(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for value in values where seen.insert(value).inserted {
            ordered.append(value)
        }
        return ordered
    }
}
