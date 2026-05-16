import XCTest

final class BundledCLILinkageTests: XCTestCase {
    deinit {}

    func testBundledCLIDoesNotDependOnPrivateRPathFrameworks() throws {
        let cliURL = try bundledCLIURL()
        let linkedLibraries = try linkedLibraries(for: cliURL)
        let rpathFrameworks = linkedLibraries.filter {
            $0.hasPrefix("@rpath/") && $0.contains(".framework/")
        }
        let rpaths = try loadCommandRPaths(for: cliURL)
        let unresolvedFrameworks = rpathFrameworks.filter {
            resolvedRPathLibraryURL($0, cliURL: cliURL, rpaths: rpaths) == nil
        }

        XCTAssertEqual(
            unresolvedFrameworks,
            [],
            "The bundled zerocmux CLI must only depend on @rpath frameworks resolvable from Contents/Resources/bin."
        )
    }

    private func bundledCLIURL() throws -> URL {
        let fileManager = FileManager.default
        let appBundleURL = Bundle(for: Self.self)
            .bundleURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let enumerator = fileManager.enumerator(at: appBundleURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])

        while let item = enumerator?.nextObject() as? URL {
            guard item.lastPathComponent == "zerocmux",
                  item.path.contains(".app/Contents/Resources/bin/zerocmux") else {
                continue
            }
            return item
        }

        throw XCTSkip("Bundled zerocmux CLI not found in \(appBundleURL.path)")
    }

    private func linkedLibraries(for executableURL: URL) throws -> [String] {
        try otool(arguments: ["-L", executableURL.path])
            .split(separator: "\n")
            .dropFirst()
            .compactMap { line -> String? in
                line.trimmingCharacters(in: .whitespacesAndNewlines)
                    .split(separator: " ")
                    .first
                    .map(String.init)
            }
    }

    private func loadCommandRPaths(for executableURL: URL) throws -> [String] {
        let output = try otool(arguments: ["-l", executableURL.path])
        let lines = output.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var rpaths: [String] = []
        var inRPathCommand = false
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "cmd LC_RPATH" {
                inRPathCommand = true
                continue
            }
            guard inRPathCommand else { continue }
            if trimmed.hasPrefix("cmd ") {
                inRPathCommand = false
                continue
            }
            guard trimmed.hasPrefix("path ") else { continue }
            let suffix = trimmed.dropFirst("path ".count)
            let path = suffix.split(separator: " ").first.map(String.init) ?? ""
            if !path.isEmpty {
                rpaths.append(path)
            }
        }
        return rpaths
    }

    private func resolvedRPathLibraryURL(_ library: String, cliURL: URL, rpaths: [String]) -> URL? {
        let suffix = String(library.dropFirst("@rpath/".count))
        let executableDirectory = cliURL.deletingLastPathComponent()
        for rpath in rpaths {
            let expanded = rpath.replacingOccurrences(of: "@executable_path", with: executableDirectory.path)
            let candidate = URL(fileURLWithPath: expanded, isDirectory: true)
                .appendingPathComponent(suffix, isDirectory: false)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        return nil
    }

    private func otool(arguments: [String]) throws -> String {
        let process = Process()
        let outputPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/otool")
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        try process.run()
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        let output = String(data: outputData, encoding: .utf8) ?? ""
        XCTAssertEqual(process.terminationStatus, 0, "otool failed: \(output)")
        return output
    }
}
