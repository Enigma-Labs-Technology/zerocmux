# zerocmux CLI Contract

This document is the compatibility contract for migrating `CLI/cmux.swift` to
Swift ArgumentParser. The migration should preserve command names, aliases,
global flags, exit behavior, socket routing, and no-socket help behavior unless
a PR explicitly calls out an intentional contract change.

The current implementation is a hand-rolled parser. This spec is deliberately
written around user-visible behavior so the implementation can change behind it.

## Migration Rules

- Keep `zerocmux --help`, `zerocmux -h`, `zerocmux --version`, and `zerocmux -v` working without
  connecting to the zerocmux socket.
- Keep documented `zerocmux <command> --help` probes working without a socket where
  they already do.
- Keep `--socket`, `--password`, `--json`, `--id-format`, and `--window` as
  global options before the command.
- Keep UUIDs, refs such as `workspace:2`, and indexes accepted wherever the
  command accepts a window, workspace, pane, surface, or tab handle.
- Keep text output stable for scripting commands unless a command already
  documents JSON as the scripting interface.
- Keep hidden/internal commands available until their callers have migrated.

## Global Invocation

| Form | Contract |
| --- | --- |
| `zerocmux <path>` | Open a directory or file path in zerocmux. Relative paths resolve from the current working directory. |
| `zerocmux [global-options] <command> [options]` | Run a named command. |
| `zerocmux --help`, `zerocmux -h` | Print top-level usage without a socket. |
| `zerocmux help` | Print top-level usage without a socket. |
| `zerocmux --version`, `zerocmux -v`, `zerocmux version` | Print version summary without a socket. |

Global options:

| Option | Contract |
| --- | --- |
| `--socket <path>` | Override the socket path for this invocation. |
| `--password <value>` | Use an explicit socket password. Takes precedence over `CMUX_SOCKET_PASSWORD`. |
| `--json` | Prefer machine-readable JSON output for commands that support it. |
| `--id-format <refs\|uuids\|both>` | Select handle format in JSON and supported text output. |
| `--window <id\|ref\|index>` | Route the command through a specific window when supported. |

Environment:

| Variable | Contract |
| --- | --- |
| `CMUX_SOCKET_PATH` | Canonical socket path override. |
| `CMUX_SOCKET` | Deprecated compatibility alias for `CMUX_SOCKET_PATH`. New scripts should use `CMUX_SOCKET_PATH`; if both variables are set and differ, the CLI fails before socket commands. |
| `CMUX_SOCKET_PASSWORD` | Socket password fallback when `--password` is absent. |
| `CMUX_WORKSPACE_ID` | Default workspace context inside zerocmux terminals. |
| `CMUX_SURFACE_ID` | Default surface context inside zerocmux terminals. |
| `CMUX_TAB_ID` | Default tab context for tab commands. |

## Top-Level Commands

| Command | Contract |
| --- | --- |
| `welcome` | Print the welcome screen. |
| `docs` | Print canonical docs URLs, raw GitHub resources, and useful commands for a topic. |
| `settings` | Open Settings, print cmux.json paths, or print settings docs. |
| `config` | Validate cmux.json syntax, print config references, or reload config. |
| `shortcuts` | Open Settings to Keyboard Shortcuts. |
| `disable-browser` | Disable zerocmux browser creation and link interception until re-enabled. |
| `enable-browser` | Re-enable zerocmux browser creation and link interception. |
| `browser-status` | Print whether zerocmux browser creation and link interception are enabled. |
| `restore-session` | Restore the previously saved zerocmux session. |
| `feed` | Open the keyboard-first Feed TUI or manage persisted Feed workstream history. |
| `themes` | List, set, clear, or interactively pick Ghostty themes. |
| `claude-teams` | Launch Claude Code with cmux/tmux-style agent team integration. |
| `omo` | Launch OpenCode with oh-my-openagent integration. |
| `omx` | Launch Oh My Codex with zerocmux pane integration. |
| `omc` | Launch Oh My Claude Code with zerocmux pane integration. |
| `hooks` | Install, uninstall, and run agent hook integrations under one namespace. |
| `codex` | Compatibility alias for installing or uninstalling Codex hooks. |
| `ping` | Check socket connectivity. |
| `capabilities` | Print server capabilities as JSON. |
| `events` | Stream reconnectable zerocmux events as newline-delimited JSON. |
| `auth` | Manage auth status, login, and logout through the app. |
| `vm`, `cloud` | Manage cloud VMs. `cloud` is an alias for `vm`. |
| `rpc` | Call a raw v2 socket method with optional JSON params. |
| `identify` | Print server identity and caller context. |
| `list-windows` | List windows. |
| `current-window` | Print the selected window ID. |
| `new-window` | Create a new window. |
| `focus-window` | Focus a window by handle. |
| `close-window` | Close a window by handle. |
| `move-workspace-to-window` | Move a workspace into a target window. |
| `reorder-workspace` | Reorder a workspace inside a window. |
| `workspace-action` | Run workspace context-menu actions from the CLI. |
| `list-workspaces` | List workspaces. |
| `new-workspace` | Create a workspace, optionally with cwd, command, description, and layout. |
| `ssh` | Open an SSH-backed workspace. |
| `remote-daemon-status` | Print bundled remote daemon version, asset, checksum, and cache status. |
| `new-split` | Split from a surface in a direction. |
| `list-panes` | List panes in a workspace. |
| `list-pane-surfaces` | List surfaces in a pane. |
| `tree` | Print a window, workspace, pane, and surface tree. |
| `focus-pane` | Focus a pane. |
| `new-pane` | Create a pane with terminal or browser content. |
| `new-surface` | Create a surface inside a pane. |
| `close-surface` | Close a surface. |
| `move-surface` | Move a surface to another pane, workspace, window, or index. |
| `split-off` | Move a surface into a new split without changing focus by default. |
| `reorder-surface` | Reorder a surface within its pane. |
| `tab-action` | Run horizontal tab context-menu actions. |
| `rename-tab` | Rename a tab. Compatibility wrapper for `tab-action rename`. |
| `drag-surface-to-split` | Move a surface into a split direction. |
| `refresh-surfaces` | Ask the app to refresh terminal surfaces. |
| `reload-config` | Ask zerocmux to reload configuration. |
| `surface-health` | Print terminal surface health information. |
| `debug-terminals` | Print debug terminal state. |
| `trigger-flash` | Trigger a visual flash on a workspace or surface. |
| `list-panels` | List panels. Compatibility alias over pane/surface data. |
| `focus-panel` | Focus a panel. Compatibility alias over surface focus. |
| `close-workspace` | Close a workspace. |
| `select-workspace` | Select a workspace. |
| `rename-workspace`, `rename-window` | Rename a workspace. `rename-window` is a compatibility alias. |
| `current-workspace` | Print current workspace information. |
| `read-screen` | Read terminal text from a surface. |
| `send` | Send text to a terminal surface. |
| `send-key` | Send one key to a terminal surface. |
| `send-panel` | Send text to a panel/surface. |
| `send-key-panel` | Send one key to a panel/surface. |
| `notify` | Send a notification to a workspace/surface. |
| `list-notifications` | List queued notifications. |
| `clear-notifications` | Clear queued notifications. |
| `set-status` | Set a sidebar status pill. |
| `clear-status` | Remove a sidebar status pill. |
| `list-status` | List sidebar status pills. |
| `set-progress` | Set sidebar progress. |
| `clear-progress` | Clear sidebar progress. |
| `log` | Append a sidebar log entry. |
| `clear-log` | Clear sidebar log entries. |
| `list-log` | List sidebar log entries. |
| `sidebar-state` | Dump sidebar metadata state. |
| `claude-hook` | Compatibility alias for Claude Code hook events from stdin JSON. |
| `set-app-focus` | Override app focus state for tests. |
| `simulate-app-active` | Trigger app-active handling for tests. |
| `browser` | Run browser automation commands. |
| `open-browser` | Legacy alias for `browser open`. |
| `navigate` | Legacy alias for `browser navigate`. |
| `browser-back` | Legacy alias for `browser back`. |
| `browser-forward` | Legacy alias for `browser forward`. |
| `browser-reload` | Legacy alias for `browser reload`. |
| `get-url` | Legacy alias for `browser get-url`. |
| `focus-webview` | Legacy alias for `browser focus-webview`. |
| `is-webview-focused` | Legacy alias for `browser is-webview-focused`. |
| `markdown` | Open a markdown file in a formatted viewer panel with live reload. |
| `vm-pty-attach` | Hosted Cloud VM helper retained as an unavailable compatibility tombstone. |
| `vm-ssh-attach` | Hosted Cloud VM helper retained as an unavailable compatibility tombstone. |
| `vm-pty-connect` | Hosted Cloud VM helper retained as an unavailable compatibility tombstone. |
| `ssh-session-end` | Internal helper that clears remote SSH session state. |
| `__tmux-compat` | Internal tmux compatibility dispatcher. |

## Command Families

Auth subcommands:

| Command | Contract |
| --- | --- |
| `auth` | Hosted auth is unavailable in zerocmux because the web backend has been removed. Supports `--json` for an unavailable status payload. |

VM subcommands:

| Command | Contract |
| --- | --- |
| `vm`, `cloud` | Hosted Cloud VM commands are unavailable in zerocmux because the web backend has been removed. Use `zerocmux ssh` for remote workspaces. Supports `--json` for an unavailable status payload. |

Theme subcommands:

| Command | Contract |
| --- | --- |
| `themes` | In a TTY, open the interactive picker. Outside a TTY, list themes. |
| `themes list` | List available themes and current light/dark defaults. |
| `themes set <theme>` | Set the same theme for light and dark appearance. |
| `themes set --light <theme>` | Set the light appearance theme. |
| `themes set --dark <theme>` | Set the dark appearance theme. |
| `themes clear` | Remove the zerocmux theme override. |

Workspace and tab action names:

| Command | Actions |
| --- | --- |
| `workspace-action` | `pin`, `unpin`, `rename`, `clear-name`, `set-description`, `clear-description`, `move-up`, `move-down`, `move-top`, `close-others`, `close-above`, `close-below`, `mark-read`, `mark-unread`, `set-color`, `clear-color` |
| `tab-action` | `rename`, `clear-name`, `close-left`, `close-right`, `close-others`, `new-terminal-right`, `new-browser-right`, `reload`, `duplicate`, `pin`, `unpin`, `mark-unread` |

tmux compatibility commands:

| Command | Contract |
| --- | --- |
| `capture-pane` | Read pane text. |
| `resize-pane` | Resize a pane with direction flags. |
| `pipe-pane` | Pipe pane text to a shell command. |
| `wait-for` | Signal or wait on a named synchronization point. |
| `swap-pane` | Swap two panes. |
| `break-pane` | Move a pane into a new workspace. |
| `join-pane` | Join a pane into another pane. |
| `next-window`, `previous-window`, `last-window` | Move workspace selection. |
| `last-pane` | Focus the last pane. |
| `find-window` | Find a workspace by title or content. |
| `clear-history` | Clear terminal scrollback. |
| `set-hook` | Manage tmux-compat hook definitions. |
| `popup` | Placeholder, currently unsupported. |
| `bind-key`, `unbind-key`, `copy-mode` | Placeholders, currently unsupported. |
| `set-buffer` | Set a tmux-compat buffer. |
| `paste-buffer` | Paste a tmux-compat buffer. |
| `list-buffers` | List tmux-compat buffers. |
| `respawn-pane` | Send a restart command to a surface. |
| `display-message` | Print or display a message. |

Browser subcommands:

| Command | Contract |
| --- | --- |
| `browser open`, `browser open-split`, `browser new` | Create or open a browser surface. |
| `browser goto`, `browser navigate` | Navigate to a URL. |
| `browser back`, `browser forward`, `browser reload` | Navigate browser history or reload. |
| `browser url`, `browser get-url` | Print current URL. |
| `browser focus-webview`, `browser is-webview-focused` | Focus or query webview focus. |
| `browser snapshot` | Print a DOM snapshot. |
| `browser eval` | Evaluate JavaScript. |
| `browser wait` | Wait for selector, text, URL, load state, or JS predicate. |
| `browser click`, `browser dblclick`, `browser hover`, `browser focus`, `browser check`, `browser uncheck`, `browser scroll-into-view` | Run element interaction. |
| `browser type`, `browser fill` | Type into or set an input. |
| `browser press`, `browser key`, `browser keydown`, `browser keyup` | Send keyboard input. |
| `browser select` | Select an option. |
| `browser scroll` | Scroll page or element. |
| `browser screenshot` | Save a screenshot. |
| `browser get` | Read URL, title, text, HTML, value, attr, count, box, or styles. |
| `browser is` | Check visible, enabled, or checked state. |
| `browser find` | Find by role, text, label, placeholder, alt, title, testid, first, last, or nth. |
| `browser frame` | Select frame context. |
| `browser dialog` | Accept or dismiss dialogs. |
| `browser download` | Wait for or save downloads. |
| `browser cookies` | Get, set, or clear cookies. |
| `browser storage` | Get, set, or clear local/session storage. |
| `browser tab` | Create, list, switch, or close browser tabs. |
| `browser console`, `browser errors` | List or clear console messages and errors. |
| `browser highlight` | Highlight an element. |
| `browser state` | Save or load browser state. |
| `browser addinitscript`, `browser addscript`, `browser addstyle` | Inject scripts or CSS. |
| `browser viewport` | Set viewport size. |
| `browser geolocation`, `browser geo` | Set geolocation. |
| `browser offline` | Toggle offline state. |
| `browser trace` | Start or stop trace capture. |
| `browser network` | Route, unroute, or list requests. |
| `browser screencast` | Start or stop screencast. |
| `browser input`, `browser input_mouse`, `browser input_keyboard`, `browser input_touch` | Send low-level input. |
| `browser identify` | Identify browser surface context. |

Hook subcommands:

| Command | Contract |
| --- | --- |
| `hooks setup` | Install hooks for all supported agents whose binaries are on `PATH`. Supports `--agent <name>`, positional agent filters such as `zerocmux hooks setup rovo`, and `--yes`. |
| `hooks uninstall` | Remove hooks for all supported agents. Supports `--agent <name>`, positional agent filters such as `zerocmux hooks uninstall rovo`, and `--yes`. |
| `hooks <agent> install` | Install hooks for one supported agent. `opencode` also supports `--project` for the project-local Feed plugin. |
| `hooks <agent> uninstall` | Remove hooks for one supported agent. |
| `hooks claude <event>` | Handle Claude Code hook events. `claude-hook <event>` remains as the main-compatibility alias. |
| `hooks codex <event>` | Handle Codex hook events. `codex install-hooks` remains as the main-compatibility installer alias. |
| `hooks feed --source <agent>` | Convert agent hook events into Feed context. |
| `hooks <agent> <event>` | Generic hook surface for `opencode`, `pi`, `cursor`, `gemini`, `rovodev`, `copilot`, `codebuddy`, `factory`, and `qoder`. |

Docs topics:

| Command | Contract |
| --- | --- |
| `docs` | List docs topics without a socket. |
| `docs settings` | Print the configuration docs URL, raw schema URL, cmux.json paths, backup reminder, and reload command. |
| `docs shortcuts` | Print shortcut docs and raw shortcut data resources. |
| `docs api` | Print API docs and raw CLI contract resources. |
| `docs browser` | Print browser automation docs and raw browser skill resources. |
| `docs agents` | Print agent integration docs and raw integration resources. |

Settings subcommands:

| Command | Contract |
| --- | --- |
| `settings` | Open the Settings window, launching zerocmux if needed. |
| `settings open [target]` | Open Settings to an optional target section. |
| `settings path` | Print cmux.json paths, docs URL, schema URL, backup reminder, and reload command without a socket. |
| `settings docs` | Print the same output as `docs settings` without a socket. |
| `settings <target>` | Open Settings to a target section. Supported aliases include `shortcuts`, `json`, `cmux-json`, `browser`, and `automation`. |

Config subcommands:

| Command | Contract |
| --- | --- |
| `config doctor [--path <file>]`, `config check`, `config validate` | Validate JSONC syntax for config files. When `--path` is absent, default discovery checks the primary config, project-level `.cmux/cmux.json` or `cmux.json`, and legacy config files. `--path <file>` may be repeated to validate multiple explicit files. Exits 0 on success and 1 on any error. Supports `--json`. Works without a socket. |
| `config path`, `config paths` | Print cmux.json paths, docs URL, schema URL, backup reminder, and reload command without a socket. |
| `config docs`, `config documentation` | Print the same output as `docs settings` without a socket. |
| `config reload` | Ask the running zerocmux app to reload configuration. Requires a socket. |

`config doctor --json` outputs an object with `ok`, `error_count`,
`findings`, `reload_command`, `docs_url`, and `schema_url`. Each finding includes
`label`, `display_path`, `path`, `status`, `ok`, `keys`, and, when available,
`message` and `bytes`.

Events command:

| Option | Contract |
| --- | --- |
| `--after <seq>`, `--after-seq <seq>` | Subscribe to retained events after a sequence number. |
| `--cursor-file <path>` | Read the starting sequence from a file and update it after every event. |
| `--name <event>` | Filter by event name. Repeatable. |
| `--category <name>` | Filter by category. Repeatable. |
| `--reconnect` | Reconnect and resume from the last received sequence until interrupted. |
| `--limit <n>` | Exit after printing `n` event frames. |
| `--no-ack` | Suppress the initial ack frame in stdout. |
| `--no-heartbeat`, `--no-heartbeats` | Suppress heartbeat frames in stdout. |

`events.stream` is a v2 socket method advertised by `capabilities`. The first
response frame is an `ack`; sequence resume metadata lives under `ack.resume` as
`after_seq`, `oldest_seq`, `latest_seq`, `next_seq`, and `gap`. Event frames
carry a process-local monotonic `seq` and a stable `id` for dedupe. Clients
should persist `seq` after processing each event and reconnect with that value.
See [events.md](events.md) for the full protocol and event catalog. Every emitted event is also appended to
`~/.cmuxterm/events.jsonl`, including model lifecycle events for window
creation, close, focus, key-window state, workspace selection, pane focus, and
surface selection, focus, creation, or closure. The stream is bounded: zerocmux keeps
4,096 replay events in memory, caps each encoded event frame at 16 KiB, closes
slow subscribers after 1,024 pending events, and rotates `events.jsonl` with one
16 MiB archive at `events.jsonl.1`.

## No-Socket Help Probes

The following probes are executable contract checks. They must exit 0 and print
the expected text without connecting to a zerocmux socket.

<!-- cli-contract-help-probes:start -->
- `zerocmux --help` -> `zerocmux - control zerocmux via Unix socket`
- `zerocmux help` -> `zerocmux - control zerocmux via Unix socket`
- `zerocmux ping --help` -> `Usage: zerocmux ping`
- `zerocmux capabilities --help` -> `Usage: zerocmux capabilities`
- `zerocmux events --help` -> `Usage: zerocmux events [options]`
- `zerocmux auth --help` -> `Usage: zerocmux auth <status|login|logout>`
- `zerocmux vm --help` -> `Usage: zerocmux vm <new|ls|rm|exec|shell|attach|ssh> [args...]`
- `zerocmux cloud --help` -> `Usage: zerocmux cloud <new|ls|rm|exec|shell|attach|ssh> [args...]`
- `zerocmux rpc --help` -> `Usage: zerocmux rpc <method> [json-params]`
- `zerocmux help --help` -> `Usage: zerocmux help`
- `zerocmux docs --help` -> `Usage: zerocmux docs [settings|shortcuts|api|browser|agents|dock]`
- `zerocmux docs` -> `Topics:`
- `zerocmux docs settings` -> `Config files:`
- `zerocmux docs dock` -> `dock: Custom right-sidebar terminal controls`
- `zerocmux settings --help` -> `Usage: zerocmux settings [open [target]|path|docs|<target>]`
- `zerocmux settings path` -> `Config files:`
- `zerocmux settings docs` -> `Config files:`
- `zerocmux config --help` -> `Usage: zerocmux config <doctor|check|validate|path|paths|docs|documentation|reload>`
- `zerocmux config path` -> `Config files:`
- `zerocmux config docs` -> `Config files:`
- `zerocmux welcome --help` -> `Usage: zerocmux welcome`
- `zerocmux shortcuts --help` -> `Usage: zerocmux shortcuts`
- `zerocmux disable-browser --help` -> `Usage: zerocmux disable-browser [--json]`
- `zerocmux enable-browser --help` -> `Usage: zerocmux enable-browser [--json]`
- `zerocmux browser-status --help` -> `Usage: zerocmux browser-status [--json]`
- `zerocmux restore-session --help` -> `Usage: zerocmux restore-session`
- `zerocmux feed --help` -> `Usage: zerocmux feed tui [--opentui|--legacy]`
- `zerocmux hooks --help` -> `Usage: zerocmux hooks setup [agent] [--agent <name>] [--yes|-y]`
- `zerocmux codex --help` -> `Usage: zerocmux codex <install-hooks|uninstall-hooks>`
- `zerocmux themes --help` -> `Usage: zerocmux themes`
- `zerocmux omo --help` -> `Usage: zerocmux omo [opencode-args...]`
- `zerocmux omx --help` -> `Usage: zerocmux omx [omx-args...]`
- `zerocmux omc --help` -> `Usage: zerocmux omc [omc-args...]`
- `zerocmux identify --help` -> `Usage: zerocmux identify`
- `zerocmux list-windows --help` -> `Usage: zerocmux list-windows`
- `zerocmux current-window --help` -> `Usage: zerocmux current-window`
- `zerocmux new-window --help` -> `Usage: zerocmux new-window`
- `zerocmux focus-window --help` -> `Usage: zerocmux focus-window --window <id|ref|index>`
- `zerocmux close-window --help` -> `Usage: zerocmux close-window --window <id|ref|index>`
- `zerocmux move-workspace-to-window --help` -> `Usage: zerocmux move-workspace-to-window`
- `zerocmux move-surface --help` -> `Usage: zerocmux move-surface`
- `zerocmux split-off --help` -> `Usage: zerocmux split-off`
- `zerocmux reorder-surface --help` -> `Usage: zerocmux reorder-surface`
- `zerocmux reorder-workspace --help` -> `Usage: zerocmux reorder-workspace`
- `zerocmux workspace-action --help` -> `Usage: zerocmux workspace-action --action <name>`
- `zerocmux tab-action --help` -> `Usage: zerocmux tab-action --action <name>`
- `zerocmux rename-tab --help` -> `Usage: zerocmux rename-tab`
- `zerocmux new-workspace --help` -> `Usage: zerocmux new-workspace`
- `zerocmux list-workspaces --help` -> `Usage: zerocmux list-workspaces`
- `zerocmux ssh --help` -> `Usage: zerocmux ssh <destination>`
- `zerocmux new-split --help` -> `Usage: zerocmux new-split`
- `zerocmux list-panes --help` -> `Usage: zerocmux list-panes`
- `zerocmux list-pane-surfaces --help` -> `Usage: zerocmux list-pane-surfaces`
- `zerocmux tree --help` -> `Usage: zerocmux tree`
- `zerocmux focus-pane --help` -> `Usage: zerocmux focus-pane`
- `zerocmux new-pane --help` -> `Usage: zerocmux new-pane`
- `zerocmux new-surface --help` -> `Usage: zerocmux new-surface`
- `zerocmux close-surface --help` -> `Usage: zerocmux close-surface`
- `zerocmux drag-surface-to-split --help` -> `Usage: zerocmux drag-surface-to-split`
- `zerocmux refresh-surfaces --help` -> `Usage: zerocmux refresh-surfaces`
- `zerocmux reload-config --help` -> `Usage: zerocmux reload-config`
- `zerocmux surface-health --help` -> `Usage: zerocmux surface-health`
- `zerocmux debug-terminals --help` -> `Usage: zerocmux debug-terminals`
- `zerocmux trigger-flash --help` -> `Usage: zerocmux trigger-flash`
- `zerocmux list-panels --help` -> `Usage: zerocmux list-panels`
- `zerocmux focus-panel --help` -> `Usage: zerocmux focus-panel`
- `zerocmux close-workspace --help` -> `Usage: zerocmux close-workspace`
- `zerocmux select-workspace --help` -> `Usage: zerocmux select-workspace`
- `zerocmux rename-workspace --help` -> `Usage: zerocmux rename-workspace`
- `zerocmux rename-window --help` -> `Usage: zerocmux rename-workspace`
- `zerocmux current-workspace --help` -> `Usage: zerocmux current-workspace`
- `zerocmux capture-pane --help` -> `Usage: zerocmux capture-pane`
- `zerocmux resize-pane --help` -> `Usage: zerocmux resize-pane`
- `zerocmux pipe-pane --help` -> `Usage: zerocmux pipe-pane`
- `zerocmux wait-for --help` -> `Usage: zerocmux wait-for`
- `zerocmux swap-pane --help` -> `Usage: zerocmux swap-pane`
- `zerocmux break-pane --help` -> `Usage: zerocmux break-pane`
- `zerocmux join-pane --help` -> `Usage: zerocmux join-pane`
- `zerocmux next-window --help` -> `Usage: zerocmux next-window`
- `zerocmux previous-window --help` -> `Usage: zerocmux previous-window`
- `zerocmux last-window --help` -> `Usage: zerocmux last-window`
- `zerocmux last-pane --help` -> `Usage: zerocmux last-pane`
- `zerocmux find-window --help` -> `Usage: zerocmux find-window`
- `zerocmux clear-history --help` -> `Usage: zerocmux clear-history`
- `zerocmux set-hook --help` -> `Usage: zerocmux set-hook`
- `zerocmux popup --help` -> `Usage: zerocmux popup`
- `zerocmux bind-key --help` -> `Usage: zerocmux bind-key`
- `zerocmux unbind-key --help` -> `Usage: zerocmux unbind-key`
- `zerocmux copy-mode --help` -> `Usage: zerocmux copy-mode`
- `zerocmux set-buffer --help` -> `Usage: zerocmux set-buffer`
- `zerocmux paste-buffer --help` -> `Usage: zerocmux paste-buffer`
- `zerocmux list-buffers --help` -> `Usage: zerocmux list-buffers`
- `zerocmux respawn-pane --help` -> `Usage: zerocmux respawn-pane`
- `zerocmux display-message --help` -> `Usage: zerocmux display-message`
- `zerocmux read-screen --help` -> `Usage: zerocmux read-screen`
- `zerocmux send --help` -> `Usage: zerocmux send`
- `zerocmux send-key --help` -> `Usage: zerocmux send-key`
- `zerocmux send-panel --help` -> `Usage: zerocmux send-panel`
- `zerocmux send-key-panel --help` -> `Usage: zerocmux send-key-panel`
- `zerocmux notify --help` -> `Usage: zerocmux notify`
- `zerocmux list-notifications --help` -> `Usage: zerocmux list-notifications`
- `zerocmux clear-notifications --help` -> `Usage: zerocmux clear-notifications`
- `zerocmux set-status --help` -> `Usage: zerocmux set-status`
- `zerocmux clear-status --help` -> `Usage: zerocmux clear-status`
- `zerocmux list-status --help` -> `Usage: zerocmux list-status`
- `zerocmux set-progress --help` -> `Usage: zerocmux set-progress`
- `zerocmux clear-progress --help` -> `Usage: zerocmux clear-progress`
- `zerocmux log --help` -> `Usage: zerocmux log`
- `zerocmux clear-log --help` -> `Usage: zerocmux clear-log`
- `zerocmux list-log --help` -> `Usage: zerocmux list-log`
- `zerocmux sidebar-state --help` -> `Usage: zerocmux sidebar-state`
- `zerocmux set-app-focus --help` -> `Usage: zerocmux set-app-focus`
- `zerocmux simulate-app-active --help` -> `Usage: zerocmux simulate-app-active`
- `zerocmux claude-hook --help` -> `Usage: zerocmux claude-hook`
- `zerocmux browser --help` -> `Usage: zerocmux browser`
- `zerocmux open-browser --help` -> `Legacy alias for 'zerocmux browser open'`
- `zerocmux navigate --help` -> `Legacy alias for 'zerocmux browser navigate'`
- `zerocmux browser-back --help` -> `Legacy alias for 'zerocmux browser back'`
- `zerocmux browser-forward --help` -> `Legacy alias for 'zerocmux browser forward'`
- `zerocmux browser-reload --help` -> `Legacy alias for 'zerocmux browser reload'`
- `zerocmux get-url --help` -> `Legacy alias for 'zerocmux browser get-url'`
- `zerocmux focus-webview --help` -> `Legacy alias for 'zerocmux browser focus-webview'`
- `zerocmux is-webview-focused --help` -> `Legacy alias for 'zerocmux browser is-webview-focused'`
- `zerocmux markdown --help` -> `Usage: zerocmux markdown open <path>`
<!-- cli-contract-help-probes:end -->

## No-Socket Negative Help Probes

The following probes must not print help. They protect argument forwarding after
`--`, where a forwarded `--help` token belongs to the command payload.

<!-- cli-contract-negative-help-probes:start -->
- `zerocmux vm exec demo -- --help` !> `Usage: zerocmux vm`
<!-- cli-contract-negative-help-probes:end -->

## Current Help Caveats

These are current contracts to preserve until a follow-up PR intentionally
changes them:

- `zerocmux version --help` currently prints the version summary because `version`
  is handled before subcommand help dispatch.
- `zerocmux claude-teams --help` is handled by the command launcher, not by the
  pre-socket help dispatcher.
- `zerocmux remote-daemon-status --help` currently prints status because the command
  runs before subcommand help dispatch.

## ArgumentParser Migration Sequence

1. Keep this contract file and `tests/test_cli_contract_help.py` green.
2. Add Swift ArgumentParser as a dependency without changing behavior.
3. Introduce a parse-only facade that maps ArgumentParser command structs onto
   existing `CMUXCLI` runner methods.
4. Move one command family at a time into small files, starting with no-socket
   commands (`version`, `themes`, hook installers), then socket commands, then
   browser and tmux compatibility.
5. After each family moves, run the contract probes plus targeted socket tests in
   GitHub Actions.
6. When all command families are migrated, remove the manual global parser and
   legacy helper code that no longer owns behavior.
