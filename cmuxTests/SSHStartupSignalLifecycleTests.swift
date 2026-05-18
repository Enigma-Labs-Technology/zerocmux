import XCTest
import Darwin

extension CLINotifyProcessIntegrationRegressionTests {
    func testSSHStartupRetriesTransientSSHExitBeforeReportingSessionEnd() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("cmux-ssh-reconnect-\(UUID().uuidString)", isDirectory: true)
        let fakeCLI = root.appendingPathComponent("cmux")
        let fakeSSH = root.appendingPathComponent("ssh")
        let logFile = root.appendingPathComponent("ssh-session-end.log")
        let attemptFile = root.appendingPathComponent("ssh-attempts.txt")

        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: root) }

        try writeShellFile(at: fakeCLI, lines: [
            "#!/bin/sh",
            "printf '%s\\n' \"$*\" >> \"${CMUX_TEST_SESSION_END_LOG}\"",
        ])
        try writeShellFile(at: fakeSSH, lines: [
            "#!/bin/sh",
            "count=0",
            "if [ -r \"${CMUX_TEST_ATTEMPT_FILE}\" ]; then count=$(cat \"${CMUX_TEST_ATTEMPT_FILE}\"); fi",
            "count=$((count + 1))",
            "printf '%s\\n' \"$count\" > \"${CMUX_TEST_ATTEMPT_FILE}\"",
            "if [ \"$count\" -eq 1 ]; then exit 255; fi",
            "exit 0",
        ])
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: fakeCLI.path)
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: fakeSSH.path)

        let startupCommand = try generatedSSHStartupCommand()
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = "\(root.path):\(environment["PATH"] ?? "/usr/bin:/bin")"
        environment["CMUX_BUNDLED_CLI_PATH"] = fakeCLI.path
        environment["CMUX_SOCKET_PATH"] = "/tmp/cmux-debug-test.sock"
        environment["CMUX_WORKSPACE_ID"] = "11111111-1111-1111-1111-111111111111"
        environment["CMUX_SURFACE_ID"] = "22222222-2222-2222-2222-222222222222"
        environment["CMUX_TEST_SESSION_END_LOG"] = logFile.path
        environment["CMUX_TEST_ATTEMPT_FILE"] = attemptFile.path
        environment["CMUX_SSH_RECONNECT_DELAY_SECONDS"] = "0"

        let result = runProcess(
            executablePath: "/bin/sh",
            arguments: ["-c", startupCommand],
            environment: environment,
            timeout: 5
        )

        XCTAssertFalse(result.timedOut, result.stderr)
        XCTAssertEqual(result.status, 0, result.stderr)
        // The regular `cmux ssh` bootstrap path runs one SSH command to install
        // the remote bootstrap and another to open the session. A transient
        // install-channel failure therefore yields three raw SSH invocations:
        // failed install, retried install, successful session.
        XCTAssertEqual((try? String(contentsOf: attemptFile, encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines), "3")
        let recordedCalls = (try? String(contentsOf: logFile, encoding: .utf8)) ?? ""
        let sessionEndCalls = recordedCalls
            .split(separator: "\n")
            .filter { $0.contains("ssh-session-end") }
        XCTAssertEqual(sessionEndCalls.count, 1, recordedCalls)
    }

    func testSSHStartupRemovesStaleCmuxControlSocketBeforeLaunchingPaneSSH() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("cmux-ssh-stale-control-\(UUID().uuidString)", isDirectory: true)
        let fakeCLI = root.appendingPathComponent("cmux")
        let fakeSSH = root.appendingPathComponent("ssh")
        let logFile = root.appendingPathComponent("ssh.log")
        let staleControlPath = URL(fileURLWithPath: "/tmp", isDirectory: true)
            .appendingPathComponent("cmux-ssh-\(getuid())-\(UUID().uuidString.prefix(8)).sock")

        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        defer {
            try? fileManager.removeItem(at: root)
            unlink(staleControlPath.path)
        }

        let staleSocketFD = try bindUnixSocket(at: staleControlPath.path)
        Darwin.close(staleSocketFD)
        XCTAssertTrue(fileManager.fileExists(atPath: staleControlPath.path))

        try writeShellFile(at: fakeCLI, lines: [
            "#!/bin/sh",
            "printf '%s\\n' \"$*\" >> \"${CMUX_TEST_SESSION_END_LOG}\"",
        ])
        try writeShellFile(at: fakeSSH, lines: [
            "#!/bin/sh",
            "printf '%s\\n' \"$*\" >> \"${CMUX_TEST_SSH_LOG}\"",
            "for arg in \"$@\"; do",
            "  if [ \"$arg\" = '-G' ]; then",
            "    printf 'controlpath %s\\n' \"${CMUX_TEST_CONTROL_PATH}\"",
            "    exit 0",
            "  fi",
            "done",
            "previous_arg=",
            "for arg in \"$@\"; do",
            "  if [ \"$previous_arg\" = '-O' ] && [ \"$arg\" = 'check' ]; then",
            "    exit 255",
            "  fi",
            "  previous_arg=\"$arg\"",
            "done",
            "if [ -e \"${CMUX_TEST_CONTROL_PATH}\" ]; then",
            "  printf 'ControlSocket %s already exists, disabling multiplexing\\n' \"${CMUX_TEST_CONTROL_PATH}\" >&2",
            "  exit 99",
            "fi",
            "exit 0",
        ])
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: fakeCLI.path)
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: fakeSSH.path)

        let startupCommand = try generatedSSHStartupCommand(sshOptions: [
            "ControlMaster auto",
            "ControlPersist 600",
            "ControlPath \(staleControlPath.path)",
        ])
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = "\(root.path):\(environment["PATH"] ?? "/usr/bin:/bin")"
        environment["CMUX_BUNDLED_CLI_PATH"] = fakeCLI.path
        environment["CMUX_SOCKET_PATH"] = "/tmp/cmux-debug-test.sock"
        environment["CMUX_WORKSPACE_ID"] = "11111111-1111-1111-1111-111111111111"
        environment["CMUX_SURFACE_ID"] = "22222222-2222-2222-2222-222222222222"
        environment["CMUX_TEST_CONTROL_PATH"] = staleControlPath.path
        environment["CMUX_TEST_SESSION_END_LOG"] = root.appendingPathComponent("ssh-session-end.log").path
        environment["CMUX_TEST_SSH_LOG"] = logFile.path
        environment["CMUX_SSH_RECONNECT_DELAY_SECONDS"] = "0"

        let result = runProcess(
            executablePath: "/bin/sh",
            arguments: ["-c", startupCommand],
            environment: environment,
            timeout: 5
        )

        XCTAssertFalse(result.timedOut, result.stderr)
        XCTAssertEqual(result.status, 0, result.stderr)
        XCTAssertFalse(fileManager.fileExists(atPath: staleControlPath.path))

        let sshLog = (try? String(contentsOf: logFile, encoding: .utf8)) ?? ""
        XCTAssertTrue(sshLog.contains("-G"), sshLog)
        XCTAssertTrue(sshLog.contains("-O check"), sshLog)
    }

    func testSSHStartupForwardsStdinToBackgroundedSSH() throws {
        // Regression test for cmux ssh sessions where output flowed back from
        // the remote (prompt rendered) but typed keystrokes never reached the
        // remote shell after PR #3786 backgrounded `ssh` inside the startup
        // wrapper. POSIX sh redirects stdin of an async command to /dev/null
        // when job control is off, so without an explicit `<&0` on the `&`'d
        // ssh invocation, the local PTY stdin is dropped and the user types
        // into a dead pipe.
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("cmux-ssh-stdin-forward-\(UUID().uuidString)", isDirectory: true)
        let fakeCLI = root.appendingPathComponent("cmux")
        let fakeSSH = root.appendingPathComponent("ssh")
        let sessionEndLog = root.appendingPathComponent("ssh-session-end.log")
        let stdinCapture = root.appendingPathComponent("ssh-stdin.txt")

        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: root) }

        try writeShellFile(at: fakeCLI, lines: [
            "#!/bin/sh",
            "printf '%s\\n' \"$*\" >> \"${CMUX_TEST_SESSION_END_LOG}\"",
        ])
        // Fake ssh reads one line from stdin and records it so the test can
        // verify the wrapper's stdin reached the backgrounded ssh process.
        try writeShellFile(at: fakeSSH, lines: [
            "#!/bin/sh",
            "IFS= read -r line || line='<EOF>'",
            "printf '%s\\n' \"$line\" > \"${CMUX_TEST_STDIN_LOG}\"",
            "exit 0",
        ])
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: fakeCLI.path)
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: fakeSSH.path)

        let startupCommand = try generatedSSHStartupCommand()
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = "\(root.path):\(environment["PATH"] ?? "/usr/bin:/bin")"
        environment["CMUX_BUNDLED_CLI_PATH"] = fakeCLI.path
        environment["CMUX_SOCKET_PATH"] = "/tmp/cmux-debug-test.sock"
        environment["CMUX_WORKSPACE_ID"] = "11111111-1111-1111-1111-111111111111"
        environment["CMUX_SURFACE_ID"] = "22222222-2222-2222-2222-222222222222"
        environment["CMUX_TEST_SESSION_END_LOG"] = sessionEndLog.path
        environment["CMUX_TEST_STDIN_LOG"] = stdinCapture.path
        environment["CMUX_SSH_RECONNECT_DELAY_SECONDS"] = "0"

        let result = runProcess(
            executablePath: "/bin/sh",
            arguments: ["-c", startupCommand],
            environment: environment,
            standardInput: "FORWARDED_KEYSTROKE\n",
            timeout: 5
        )

        XCTAssertFalse(result.timedOut, result.stderr)
        XCTAssertEqual(result.status, 0, result.stderr)
        let recorded = (try? String(contentsOf: stdinCapture, encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        XCTAssertEqual(
            recorded,
            "FORWARDED_KEYSTROKE",
            "Backgrounded ssh in the startup wrapper must inherit the wrapper's stdin so that keystrokes from the surface PTY reach the remote shell. Got: \(recorded.isEmpty ? "<empty>" : recorded)"
        )
    }

    private func generatedSSHStartupCommand(
        sshOptions: [String] = [
            "ControlMaster no",
            "ControlPath /tmp/cmux-ssh-%C",
        ]
    ) throws -> String {
        let cliPath = try bundledCLIPath()
        let socketPath = makeSocketPath("ssh-pane-close")
        let listenerFD = try bindUnixSocket(at: socketPath)
        let state = MockSocketServerState()
        let workspaceID = "11111111-1111-1111-1111-111111111111"
        let workspaceRef = "workspace:9"

        defer {
            Darwin.close(listenerFD)
            unlink(socketPath)
        }

        let serverHandled = startMockServer(listenerFD: listenerFD, state: state) { line in
            guard let data = line.data(using: .utf8),
                  let payload = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                  let id = payload["id"] as? String,
                  let method = payload["method"] as? String else {
                return self.v2Response(
                    id: "unknown",
                    ok: false,
                    error: ["code": "unexpected", "message": "Unexpected payload"]
                )
            }

            switch method {
            case "workspace.create":
                return self.v2Response(
                    id: id,
                    ok: true,
                    result: [
                        "workspace_id": workspaceID,
                    ]
                )
            case "workspace.remote.configure":
                return self.v2Response(
                    id: id,
                    ok: true,
                    result: [
                        "workspace_id": workspaceID,
                        "workspace_ref": workspaceRef,
                        "remote": [
                            "enabled": true,
                            "state": "connecting",
                        ],
                    ]
                )
            default:
                return self.v2Response(
                    id: id,
                    ok: false,
                    error: ["code": "unexpected", "message": "Unexpected method \(method)"]
                )
            }
        }

        var environment = ProcessInfo.processInfo.environment
        environment["CMUX_SOCKET_PATH"] = socketPath

        var arguments = [
            "ssh",
            "--no-focus",
            "--port", "2222",
        ]
        for option in sshOptions {
            arguments += ["--ssh-option", option]
        }
        arguments.append("cmux-macmini")

        let result = runProcess(
            executablePath: cliPath,
            arguments: arguments,
            environment: environment,
            timeout: 5
        )

        wait(for: [serverHandled], timeout: 5)
        XCTAssertFalse(result.timedOut, result.stderr)
        XCTAssertEqual(result.status, 0, result.stderr)
        XCTAssertTrue(result.stderr.isEmpty, result.stderr)

        let requests = try state.commands.map { line -> [String: Any] in
            let data = try XCTUnwrap(line.data(using: .utf8))
            return try XCTUnwrap(JSONSerialization.jsonObject(with: data, options: []) as? [String: Any])
        }
        let configureRequest = try XCTUnwrap(
            requests.first { ($0["method"] as? String) == "workspace.remote.configure" }
        )
        let configureParams = try XCTUnwrap(configureRequest["params"] as? [String: Any])
        return try XCTUnwrap(configureParams["terminal_startup_command"] as? String)
    }

    private func writeShellFile(at url: URL, lines: [String]) throws {
        try lines.joined(separator: "\n")
            .appending("\n")
            .write(to: url, atomically: true, encoding: .utf8)
    }
}
