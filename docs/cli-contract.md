# zerocmux CLI Contract

This document is the compatibility contract for migrating `CLI/cmux.swift` to
Swift ArgumentParser. The migration should preserve command names, aliases,
global flags, exit behavior, socket routing, and no-socket help behavior unless
a PR explicitly calls out an intentional contract change.

The current implementation is a hand-rolled parser. This spec is deliberately
written around user-visible behavior so the implementation can change behind it.
The migration contract is intentionally English-only; runtime UI strings remain
localized.

## Migration Rules

- Keep `zerocmux --help`, `zerocmux -h`, `zerocmux --version`, and `zerocmux -v` working without
  connecting to the zerocmux socket.
- Keep documented `zerocmux <command> --help` probes working without a socket where
  they already do.
- Keep `--socket`, `--password`, and `--window` as global options before the
  command. Keep presentation options `--json` and `--id-format` accepted either
  before or after the command.
- Keep UUIDs, refs such as `workspace:2`, and indexes accepted wherever the
  command accepts a window, workspace, pane, surface, or tab handle.
- Keep text output stable for scripting commands unless a command already
  documents JSON as the scripting interface.
- Keep hidden/internal commands available until their callers have migrated.

## Global Invocation

| Form | Contract |
| --- | --- |
| `zerocmux <path>` | Open a directory or file parent in zerocmux through the app's file-open path, without requiring control-socket access. Relative paths resolve from the current working directory. |
| `zerocmux [global-options] <command> [options]` | Run a named command. Presentation options may appear before or after the command. |
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
| `agent-hibernation` | Enable or disable routine Agent Hibernation. |
| `restore` | Replace the CLI with a process restored from structured surface state. |
| `fork` | Replace the CLI with a provider fork process restored from structured surface state. |
| `restore-session` | Restore the previously saved zerocmux session. |
| `open` | Open files, directories, or URLs in cmux. |
| `feedback` | Open feedback UI or submit feedback with `--email`, `--body`, and repeated `--image`. |
| `feed` | Open the keyboard-first Feed TUI or manage persisted Feed workstream history. |
| `themes` | List, set, clear, or interactively pick Ghostty themes. |
| `claude-teams` | Launch Claude Code with zerocmux/tmux-style agent team integration. |
| `codex-teams` | Launch Codex with zerocmux-managed subagent panes. |
| `omo` | Launch OpenCode with oh-my-openagent integration. |
| `omx` | Launch Oh My Codex with zerocmux pane integration. |
| `omc` | Launch Oh My Claude Code with zerocmux pane integration. |
| `hooks` | Install, uninstall, and run agent hook integrations under one namespace. |
| `codex` | Compatibility alias for installing or uninstalling Codex hooks. |
| `ping` | Check socket connectivity. |
| `capabilities` | Print server capabilities as JSON. |
| `events` | Stream reconnectable zerocmux events as newline-delimited JSON. |
| `automation` | Manage config-backed event rules: `list`, `show <id>`, dry-run `test <id> --event <json>`, `enable`, `disable`, `logs`, and `reload`. Rules live in `~/.cmuxterm/automations.json`; actions are dispatched by the running app. |
| `sessions [list]` | List saved agent session records without requiring a running zerocmux socket. Filters: `--agent <name>`, `--session <id>`, `--workspace <id>`, `--surface <id>`, `--cwd <text>`. Overrides: `--state-dir <path>`, `--codex-home <path>`. Text output defaults to 100 results; `--limit <n>` takes a positive integer and `--all` removes the limit. Supports `--json`. |
| `auth` | Manage auth status, login, and logout through the app. |
| `coderouter`, `cr` | `zerocmux coderouter <status|machines|claude>` manages the team's coderouter model plane through the app (sign-in state, per-machine usage, the team's Claude upstream accounts). Every other `zerocmux coderouter ...` verb and all of `zerocmux cr ...` exec the CodeRouter CLI unchanged with the `CMUX_*`/`CMUXD_*` environment stripped: `coderouter` or `cr` on PATH first, then the official installer's `~/.coderouter/bin/coderouter` (`$CODEROUTER_INSTALL/bin` when set), never with a network call. When neither exists and stdin and stderr are terminals, zerocmux shows the documented installer `curl -fsSL https://cmux.com/coderouter/install.sh | sh`, says what it does (checksum-verified binary into `~/.coderouter/bin`, PATH line in the shell profile), asks once (`Install CodeRouter now? [y/N]`), and after `y` fetches the script, runs it with `sh`, and execs the new install with the original arguments. Any other outcome (non-interactive, declined, download or installer failure) prints that install command on stderr and exits 127. |
| `vm`, `cloud` | Manage cloud VMs and their HTTPS publications. `cloud` is an alias for `vm`. |
| `remotes`, `remote` | Manage remote Macs in the team device registry so they appear in the iOS app's device list. `remote` is an alias for `remotes`. |
| `rpc` | Call a raw v2 socket method with optional JSON params. |
| `identify` | Print server identity and caller context. |
| `list-windows` | List windows. |
| `current-window` | Print the selected window ID. |
| `new-window` | Create a new window. |
| `focus-window` | Focus a window by handle. |
| `close-window` | Close a window by handle. |
| `window displays` | List connected displays (name, index, main flag). |
| `window display <name\|index>` | Move the instance's window(s) onto a display by name (exact, substring) or index, preserving size. Does not steal focus. With `--window`, targets that window; otherwise moves all main windows. `--list` aliases `window displays`. |
| `window default-display [<name>\|--clear]` | Set, show (no arg), or clear (`--clear`) the shared, cross-tag default display that DEBUG dev builds open new windows on, stored in `~/.config/cmux/cmux.json` under `app.devWindowDisplay`. No running app required; applied at window creation. Also settable in Debug > Debug Windows > Dev Window Display. |
| `move-workspace-to-window` | Move a workspace into a target window. |
| `reorder-workspace` | Reorder a workspace inside a window. |
| `reorder-workspaces` | Atomically reorder workspaces inside pinned and unpinned groups. |
| `workspace-action` | Run workspace context-menu actions from the CLI. |
| `workspace` | Namespace for workspace verbs: `list`, `create`, `env`, `close`, `rename`, `select`, `status`, `reconnect`, `disconnect`, `group`. `workspace status` prints the workspace's todo lifecycle status (effective, inferred, override); `workspace status set <todo\|working\|needs-attention\|review\|done\|auto>` pins a manual lane (`auto` clears it; a pinned lane auto-clears once the inferred lane changes). `workspace env` prints a workspace's configured environment variables (see [Workspace environment variables](#workspace-environment-variables)); pass `--mask` to redact the values. `workspace reconnect` manually reconnects a remote (SSH) workspace — including one whose automatic reconnect suspended because the host was unreachable — and `workspace disconnect` stops its remote connection. `env`, `reconnect`, and `disconnect` accept a positional workspace handle or `--workspace <id\|ref\|index>`, defaulting to the caller's workspace, then the selected one. |
| `todo` | Per-workspace checklist namespace: `add "text" [--state <pending\|in-progress\|completed>] [--origin <user\|agent>]`, `list`, `check <index\|id>`, `uncheck <index\|id>`, `start <index\|id>` (in-progress), `edit <index\|id> "text"`, `rm <index\|id>`, `clear`, `set ['<json>']` (atomic replace from a JSON item array, inline or piped on stdin), `open` (open or focus the workspace's todo pane). Targets the caller's workspace by default with `--workspace <id\|ref\|index>` override; `<index>` is the 1-based number printed by `todo list`. Items cap at 50 per workspace. See [Workspace todos](#workspace-todos). |
| `comments` | Diff review comments namespace: `list` (alias `ls`) `[--repo <path>] [--all] [--json]` — read-only listing of review comments saved from the diff viewer for one git repository (default: the repository containing the current directory). Pending comments only by default; `--all` includes comments already delivered to an agent through a TextBox submission. Backed by the socket v2 method `comments.list`. |
| `vault` | Vault session-index namespace: `sessions [--agent <id>] [--folder <path>] [--limit <n>]` lists indexed agent sessions newest first; `search <query>` searches them with `agent:`/`repo:`/`ws:`/`before:`/`after:` operators; `checkpoints --agent <id> --session <id>` lists a session's checkpoint timeline (derived turn checkpoints + manual ones); `checkpoint … [--name <text>]` creates a manual checkpoint (capturing the workspace git HEAD when available); `fork … (--checkpoint <id> \| --turn <n>) [--open]` forks a new session from a checkpoint and prints the new session id (plus its resume command when one is available) (`--open` also opens it in a new workspace). Backed by the socket v2 methods `vault.sessions`, `vault.search`, `vault.checkpoints`, `vault.checkpoint`, and `vault.fork`; all support `--json`. |
| `move-tab-to-new-workspace` | Move a tab or surface into a newly created workspace. |
| `list-workspaces` | List workspaces. |
| `new-workspace` | Create a workspace, optionally with cwd, command, description, layout, and per-workspace environment variables (`--env KEY=VALUE` repeatable, `--env-file <path>`). See [Workspace environment variables](#workspace-environment-variables). `--command <text>` runs in the initial interactive shell; see [Initial terminal command](#initial-terminal-command). |
| `ssh` | Open an SSH-backed workspace. Preserves the caller's live `SSH_AUTH_SOCK` for app-launched OpenSSH processes so `ForwardAgent yes` from ssh_config works normally. Supports `-A` / `--forward-agent` to request forwarding and `-a` / `--no-forward-agent` to disable forwarding for a workspace. Agent forwarding remains opt-in because forwarded agents can be used by processes on the remote host while the SSH session is active. |
| `local-tmux` | Opt in to a user-owned local tmux server. `start`, `attach`, `list`, `status`, `detach`, `close`, and `cleanup` preserve and manage named sessions independently of the cmux GUI; `cleanup` previews stale records unless `--prune` is supplied. `list`, `status`, `detach`, `close`, `cleanup`, and `attach --headless` work without a running cmux control socket. This preserves live processes across cmux lifecycle events, not a machine shutdown or reboot; use a remote tmux owner for continuity while the Mac is offline. See [`docs/local-tmux.md`](local-tmux.md). |
| `tmux attach` | Compatibility alias for `local-tmux attach`. |
| `remote-daemon-status` | Print bundled remote daemon version, asset, checksum, and cache status. |
| `ssh-session-list` | List persisted SSH PTY sessions for one remote workspace or all remote workspaces. Supports `--json`. |
| `ssh-session-attach` | Create a local terminal surface that reattaches to an existing persisted SSH PTY session. |
| `ssh-session-cleanup` | Close one or all persisted SSH PTY sessions. Supports `--json`. |
| `new-split` | Split from a surface in a direction. `--command <text>` starts a command in the new terminal; see [Initial terminal command](#initial-terminal-command). |
| `list-panes` | List panes in a workspace. |
| `list-pane-surfaces` | List surfaces in a pane. |
| `tree` | Print a window, workspace, pane, and surface tree. |
| `top` | Print process/resource usage for zerocmux windows, workspaces, panes, and surfaces. |
| `focus-pane` | Focus a pane. |
| `new-pane` | Create a pane with terminal or browser content. `--command <text>` is accepted for terminal panes only; see [Initial terminal command](#initial-terminal-command). |
| `new-surface` | Create a surface inside a pane. `--command <text>` is accepted for terminal surfaces only; see [Initial terminal command](#initial-terminal-command). |
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
| `read-selection` | Read the active selection from a terminal, file preview, Markdown, or browser surface. Plain output includes available source context; `--json` returns the complete socket response. |
| `read-screen` | Read terminal text from a surface. `--selection` is a text-only compatibility alias for `read-selection`. |
| `send` | Send text to a terminal surface. |
| `send-key` | Send one key to a terminal surface. |
| `send-panel` | Send text to a panel/surface. |
| `send-key-panel` | Send one key to a panel/surface. |
| `notify` | Send a notification to a workspace/surface and return its notification id; `--clear` clears the resolved caller/target scope. Supports `--id-format refs\|uuids\|both` for human-readable handles. |
| `list-notifications` | List queued notifications, including `created_at` and `tab_title`. |
| `dismiss-notification` | Remove one notification, or remove already-read notifications with `--all-read`. |
| `mark-notification-read` | Mark one notification, a workspace/surface scope, or all notifications read. |
| `open-notification` | Focus the notification's workspace/surface and mark it read. |
| `jump-to-unread` | Focus the latest unread notification. |
| `clear-notifications` | Clear queued notifications, optionally scoped to a workspace, surface, and `--window` context. |
| `right-sidebar` | Control right sidebar visibility, mode, focus, and state reads. |
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
| `ssh-pty-attach` | Internal helper used by SSH terminal startup scripts to bridge a local terminal surface to a remote PTY session. |
| `ssh-session-end` | Internal helper that clears remote SSH session state. |
| `__tmux-compat` | Internal tmux compatibility dispatcher. |

## Surface Selection Contract

`surface.read_selection` is a v2 worker-lane socket method advertised by
`system.capabilities` and printed by `cmux capabilities`. It accepts the usual
surface routing selectors (`window_id`, `workspace_id`, `surface_id`,
`terminal_id`, `tab_id`, and `pane_id`) without focusing a window, workspace,
pane, or surface.

Successful responses use one shape across surface kinds:

```json
{
  "has_selection": true,
  "kind": "filepreview",
  "text": "let answer = 42",
  "base64": "bGV0IGFuc3dlciA9IDQy",
  "file_path": "/Users/me/project/Answer.swift",
  "line_range": { "start": 7, "end": 7 },
  "workspace_id": "...",
  "workspace_ref": "workspace:1",
  "surface_id": "...",
  "surface_ref": "surface:2",
  "window_id": "...",
  "window_ref": "window:1"
}
```

- `has_selection`, `kind`, `text`, and `base64` are always present.
- Selection text is capped at 1 MiB before it crosses the socket boundary;
  browser and native text selections are shortened with a visible ellipsis,
  while a terminal selection that exceeds Ghostty's bounded work budget is
  reported as temporarily unavailable.
- `file_path` is present for native file/Markdown selections and Markdown
  preview selections.
- `line_range` is present when a native text view can map the selection back to
  source lines. `start` and `end` are one-based and inclusive. Selecting a line
  terminator keeps that terminator on its source line.
- `url` is present for browser selections.
- The normal workspace, surface, and window identity fields are always emitted;
  absent window identity values are JSON `null`.
- A supported surface with no active selection succeeds with
  `has_selection: false`, empty `text`, and empty `base64`. Unsupported surface
  kinds return `not_supported`; a selectable surface whose live view is no
  longer available returns `unavailable`.

Terminal selections come from Ghostty's live selection API. Text file previews
and Markdown text mode read their native text view. Markdown preview and browser
surfaces read the page selection, including editable text controls; password
input selections are never exposed. Non-text file preview modes do not claim
selection support.

`cmux read-selection` prints available kind, file, line, or URL context followed
by the selected text. A supported surface with no selection still exits zero and
prints the explicit `Has selection: false` marker. `cmux read-selection --json`
preserves the complete response for scripts. `cmux read-screen --selection`
uses the same socket path but omits source metadata, and cannot be combined with
`--scrollback` or `--lines`.

Examples:

```bash
cmux read-selection --surface surface:2
cmux read-selection --surface surface:2 --json
cmux read-screen --surface surface:2 --selection
cmux rpc surface.read_selection '{"surface_id":"83F4E6A4-5246-4DB8-A412-9CE7B059FA6C"}'
```

## Command Families

Sessions output:

`cmux sessions [list]` reads saved hook state from disk and never connects to a
cmux socket. By default the listing includes records that are active for a
workspace or surface, restorable, launch-backed, or transcript-backed. Passing
`--all`, or any record filter (`--session`, `--workspace`, `--surface`,
`--cwd`), includes every record that matches the filters. `--json` prints one
object with:

| Field | Contract |
| --- | --- |
| `state_dir` | Hook state directory the session stores were read from. |
| `default_codex_home` | Codex home used for transcript checks. |
| `total_matches` | Number of matching records, counted before `--limit` is applied. |
| `limit` | Applied result limit, or `null` when `--all` removes it. |
| `stores` | Per-agent hook store files that were read: `agent`, `path`, `exists`, `session_count`. |
| `sessions` | The limited result set of session records. |

Auth subcommands:

| Command | Contract |
| --- | --- |
| `auth` | Hosted auth is unavailable in zerocmux because the web backend has been removed. Supports `--json` for an unavailable status payload. |

VM subcommands:

| Command | Contract |
| --- | --- |
| `vm ls`, `vm list` | List VMs. |
| `cloud domains [list]`, `vm domains [list]` | List the account's VM-port publications (`vm.publication_list`). `--json` returns `{publications: [...]}`. |
| `cloud domains zones`, `vm domains zones` | List custom domains owned by the account (`vm.domain_list`); `--json` returns `{domains: [...]}`. |
| `cloud domains verify <domain>`, `vm domains verify <domain>` | Start or complete ownership/certificate verification for a custom zone (`vm.domain_verify`). The first call prints the DNS checklist; add the records and rerun it. A publication hostname resolves to its zone; generated zerocmux names need no verification. |
| `cloud domains publish <vm> <port> [--domain <hostname>] [--access personal\|team\|public] [--team <id>]`, `vm domains publish …` | Create one HTTPS publication (`vm.publication_create`). Generated names need no DNS setup. `personal` is owner-only (default), `team` requires the selected team id, and `public` allows anyone with the URL. |
| `cloud domains access <hostname> <personal\|team\|public> [--team <id>]`, `vm domains access …` | Change an existing publication's viewer policy (`vm.publication_update`); the first argument is a publication hostname or id, not a VM id. |
| `cloud domains rm <hostname>`, `vm domains rm …` | Remove a publication (`vm.publication_delete`). |
| `vm tree [<machine>\|local] [--refresh] [--json]` | The surface catalog (`surface.catalog`), rendered Finder-style: **This Mac** first (its terminals grouped by the local workspace showing them, then its browsers), then every cloud machine — Workspaces, Ports, VNC Displays (one row per screen), and a final Terminals section containing every machine-owned terminal. Workspace folders include their terminal, browser, and display layout; a canonical `browser/port:<n>` resource is also listed in the machine's Ports folder. Every line carries an address `vm open` or `surface open` accepts. `--refresh` re-syncs every provider first. `--json` prints the catalog payload with `cloud_states` (`sync_mode`: `journaled` or `snapshot_only`, cursor `(generation, revision)`, freshness, and pending writes) and resources with exact `remote_views: [{tab_id, workspace: {id, name, index, focused}, screen_id?, pane_id?, name?, index?, focused?, screen_index?, pane_index?}]`. A snapshot-only VM remains readable but rejects revision-fenced rename writes until its daemon is upgraded. Same as `surface ls`. |
| `vm workspace new <machine> [--name <name>] [--json]` | `vm.workspace_new`: creates a cmux-tui workspace on the machine (its ⌘N, with a first terminal) and opens it as a new local workspace. Prints `OK workspace=<local id> remote_workspace=<ws id> machine=<id>`. |
| `vm workspace open <machine> <workspace> [--here] [--tabs] [--workspace <local>] [--pane <id\|ref> [--left\|--right\|--up\|--down]] [--json]` | `vm.workspace_open`: the machine workspace's terminals, browsers and pinned displays as a new local workspace, one pane each (what clicking the sidebar row does). `<workspace>` is the `ws_…` id or an unambiguous workspace name, resolved exactly like the sidebar row (every view of every terminal counts); the payload's `remote_workspace_id` is the resolved id. An existing workspace with nothing in it opens nothing and answers `Nothing to open: … zerocmux vm open <machine>/<ws> starts a terminal there`. `--here`/`--tabs`/`--pane`+side instead project the group into an existing local workspace (`here: true` + the `surface open` destination params; one pane at the destination, the rest as tabs) — the sidebar's "Open All Here" / "Open All in New Tabs" / drop on a pane edge. |
| `vm prompt [--json]` / `vm prompt --open <agent>` (alias `skill`) | `vm.cloud_prompt` / `vm.cloud_agent_open`: installs the bundled cmux-cloud skill file at `~/.config/cmux/skills/cmux-cloud.md` and prints the kickoff prompt for any agent (the Machines panel's "Copy Cloud Prompt"), or opens a local terminal running claude\|codex\|opencode with it ("Open Cloud Agent"). |
| `vm workspace rename <machine> <workspace-id> <name> [--json]` | `vm.workspace_rename`: renames the cmux-tui workspace (the sidebar row's "Rename…") through the catalog's machine-scoped rename lane. |
| `vm tab rename <machine> <tab-id> <name> [--json]` | `vm.tab_rename`: renames one exact cmux-tui tab placement through the catalog's machine-scoped rename lane. Pass `""` as `<name>` to clear that tab's custom label and restore its generated title. Use the tab id from `vm tree --json`; the daemon revision fence prevents overwriting a concurrent rename. |
| `vm workspace close <machine> <workspace-id> [--json]` | `vm.workspace_close`: closes the cmux-tui workspace; its terminals keep running in the Terminals pool (CLI-only; the sidebar's "Close Workspace…" is `vm workspace rm`). |
| `vm workspace rm <machine> <workspace-id> [--json]` (alias `delete`) | `vm.workspace_delete`: kills every terminal viewed in the workspace, then closes it (the sidebar row's "Close Workspace…" and its hover ×). Prints how many terminals were closed. |
| `vm terminal close <machine> <terminal-id> [--json]` | `vm.terminal_close`: ends a terminal on the machine; an exited terminal is removed through its tab. |
| `vm terminal send <machine> <terminal-id> [text] [--keys <k1,k2,…>] [--json]` (alias `write`) | `vm.terminal_write {id, terminal_id, text?, keys?}`: types `text` into the machine terminal exactly as given (no newline), then presses the named keys (`enter`, `tab`, `escape`, `up`, …; chords join with `+`: `ctrl+c`) — cmux-tui `terminal <id> write --text` / `keys`. Headless: no pane is attached or focused. |
| `vm terminal read <machine> <terminal-id> [--json]` (alias `screen`) | `vm.terminal_read {id, terminal_id}`: the terminal's visible screen (`text`; `--json` adds `rows`, `cols`, `cursor_row`, `cursor_col`, `cursor_visible`) — cmux-tui `terminal <id> screen read`. |
| `vm terminal wait <machine> <terminal-id> --pattern <regex> [--timeout <seconds>] [--json]` | `vm.terminal_wait {id, terminal_id, pattern, timeout_ms?}`: blocks until the screen text matches (default 30 s) — cmux-tui `terminal <id> screen wait`. Prints `OK matched …`; exits 1 with a bounded timeout diagnostic that does not include terminal text. |
| `vm terminal rename <machine> <terminal-id> <name> [--json]` | `vm.terminal_rename`: names the terminal's daemon tab view(s) (the sidebar's Rename…) through the same machine-scoped rename lane; every client shows the name in place of the PTY title, and the daemon persists it. Pass `""` to clear the custom label on every placement. A zero-view pool terminal has no tab to name. |
| `vm new`, `vm create` | Create a VM: the devbox with devtools, the coding agents and a screen (TigerVNC + openbox + noVNC on 6901). The CLI always sends the machine **kind** `desktop` and the backend maps kind and size to the image its deployment supports (one snapshot ladder serves both kinds, so a request that names `base` gets the same machine); `--desktop` / `--base` / `--no-desktop` are accepted for older scripts and change nothing. `--image <id>` is the explicit override and is the only way an image id leaves the client. Supports `--size <4g\|8g\|16g\|24g\|32g\|64g>`, `--name <label>` (display label, applied via `vm.rename` after create), `--provider`, `--workspace`, `--detach`, and `-d`. Without `--detach`, opens a plain terminal on the machine through the shared open path (see `vm shell`). The Machines panel's ＋ opens the New Machine sheet (size, plan meter) whose Create runs this same command. |
| `vm base open`, `vm base reset` | Open (creating on first use) or reset the persistent Base machine, the same devbox with a screen; `--base` / `--desktop` are accepted for older scripts and change nothing, and an existing Base keeps its image. The app's Cloud VM button shows the Set Up Base sheet only when no Base exists yet. |
| `vm shell`, `vm attach` | Open an interactive shell for an existing VM. Every cloud open (`vm shell` / `vm new` / `vm fork` / `vm restore` / `vm base open` / `vm base reset`, the Machines panel, the sidebar cloud button) uses the machine's private cmux-tui route through the app's user-space WireGuard hub. The first open gets one enrollment invitation from `vm.cmux_remote_info`; a known device reconnects with its pinned daemon fingerprint and cached private route, without a connection-time control-plane request. The app then uses `workspace.create` or `workspace.cloud_vm_terminal_ready`, `workspace.cloud_vm_bind`, and `surface.new_terminal {machine, open: true, workspace_id, focus: true, name: "shell"}`. There is no public WebSocket or automatic SSH fallback. `zerocmux vm ssh` remains an explicit diagnostic command. |
| `vm stats <id>`, `vm top <id>` | Print CPU, memory, and disk for the machine right now; a sleeping machine reports `asleep` and is not woken. |
| `vm resize <id> --disk <GiB>` | Increase a machine's disk in 4 GiB steps, from 4 GiB through the Freestyle 256 GiB limit. The operation is grow-only and returns the provider-confirmed size. |
| `vm desktop <id>`, `vm vnc <id>` | Open the VM desktop in a browser pane using its private address on port 6901. The browser shows VPN setup and connection state until access is ready. Forward Port is an explicit action in the Ports table; no local forward starts automatically. |
| `vm rename <id> <label>`, `vm rename <id> --clear` | Set or clear a display label; the machine id stays its address. |
| `vm rm`, `vm destroy`, `vm delete` | Destroy a VM. |
| `vm ssh` | Open a cmux-managed SSH workspace for an existing VM. |
| `vm ssh-info` | Print SSH connection info. |
| `vm ssh-attach` | Internal attach helper. |
| `vm exec` | Run a shell command inside a VM. |
| `vm tui <id>` | Open the FULL cmux-tui client (its own workspaces/panes/tabs) in a pane — every other open gives a plain terminal instead; dials the machine's trusted-carrier listener over the private network, so no device enrollment or approval happens (hidden helper, used only by this command: `vm-tui-connect --config <file>` execs the local cmux-tui client in the pane). |
| `vm run -- <command...>` | Run a command without naming a machine: reuses an idle machine the router provisioned earlier (persisted in `~/.cmuxterm/vm-run-pool.json`, labeled `agent-pool`), wakes a sleeper, or provisions a fresh one; `--sync` pushes the cwd first, `--pull <remote>` fetches results, and the remote exit code passes through. |
| `vm push <id> <local> [remote]`, `vm upload` | Copy a local file or directory onto a VM over the exec channel (base64-chunked, SHA-256 verified; directories travel as tarballs). |
| `vm pull <id> <remote> [local]`, `vm download` | Copy a file or directory from a VM to local disk over the exec channel. |
| `vm wait <id>` | Block until the VM reports a ready status; `--wake` also runs a trivial exec so a sleeping machine is awake, `--timeout <seconds>` bounds the wait. |
| `vm open <id> <port> [--print]` | Open the canonical machine-port browser resource. The pane uses the VM private address and shows VPN setup, connection state, and an explicit Ports table. Opening or copying does not create a forward. `url` and `private_url` identify the private URL. `--print` remains the explicit control-plane URL request. |
| `vm open <target> [--workspace <id\|ref\|index>] [--focus <true\|false>]` | Open a tree address. `<machine>` is the machine's shell (exactly `vm shell <machine>`). `<machine>/<ws>` (a `ws_…` id or workspace name) opens that cmux-tui workspace's focused/first live terminal, or starts one there when it is empty (`surface.new_terminal {machine, remote_workspace_id, open: true}`). `<machine>/<ws>/<term_…>` opens one terminal (`surface.project {resource: "<machine>/terminal/<term_…>", workspace_id?, focus?}`), reusing the pane that already shows it (`reused: true`). `<machine>/<ws>/<term_…>/<tab_…>` opens that terminal's exact tab placement (`surface.project {…, remote_tab_id}`); it is the address `vm tree` prints for each tab when one terminal occupies several tabs of a pane, and the tab must belong to that workspace. `<machine>:desktop` is `vm desktop`. `<machine>:port/<n>` is the port form. Prints `OK surface=… workspace=… terminal=…`; `--json` prints the socket payload. Anything else is a usage error. |
| `vm route [--cwd <dir>] [--new] [--provision] [--size <s>] [--json]` | Print the machine `vm run` / `vm agent` would use for a directory and why (the router's own policy: the machine bound to the directory, then an awake idle pool machine, then a sleeper), without running anything. When routing would provision a fresh machine it prints that and stops unless `--provision` is passed. |
| `vm agent --agent <claude\|codex\|opencode\|pi> [--machine <id>] [--sync] [--cwd <dir>] [--name <name>] [--no-open] [--new] [--size <s>] [--json] -- <prompt or args...>` | Start a coding agent on a cloud machine chosen like `vm run` (or pinned with `--machine`), as a detached terminal in the machine's cmux-tui session (`surface.new_terminal {machine, command, cwd, name, open}`; the command is a login shell that puts `/root/.npm-global/bin` first). A bare prompt uses the agent's one-shot form (`claude -p`, `codex exec`, `opencode run`, `pi -p`); flag- or subcommand-led args pass through. `--sync` pushes the directory to `work/<basename>` first and starts the agent there. Prints the terminal, the workspace, and the `vm open <machine>/<ws>/<term>` reattach address; exits as soon as the terminal starts. |
| `surface ls [<machine>\|local] [--refresh] [--json]` | The surface catalog, exactly `vm tree` (This Mac and every cloud machine). |
| `surface open <resource> [--workspace <id\|ref\|index>] [--pane <id\|ref>] [--left\|--right\|--up\|--down\|--tab] [--new] [--focus <true\|false>] [--json]` | Put one surface in a pane through the single open path (`surface.project {resource, workspace_id?, pane_id?, direction?, placement?, reuse?, focus?}` → `{surface_id, workspace_id, reused, resource}`). `<resource>` is `<machine>/<kind>/<key>` from `surface ls --json` (`local/terminal/<uuid>`, `<m>/terminal/<term_…>`, `<m>/display/display:1`, `<m>/browser/port:<n>`). Reuses the pane already showing the resource unless `--new`; `--pane` + a side splits that pane on that side, `--tab` adds a tab to it, otherwise the workspace's focused pane; a local terminal moves to the destination (it is shown once). Prints `OK surface=… workspace=… resource=… [reused=true]`. |
| `surface new-terminal --machine <id\|local> [--cwd <dir>] [--name <name>] [--remote-workspace <ws_…>] [--workspace <id\|ref\|index>] [--no-open] [--json] [-- <command...>]` | Create a terminal on a machine through its provider (`surface.new_terminal {machine, command?, cwd?, name?, remote_workspace_id?, open?, workspace_id?, …}` → `{resource, terminal_id, machine, remote_workspace_id, workspace_id?, surface_id?}`) and open it as a pane unless `--no-open`. Cloud terminals land in the machine's cmux-tui session (`--remote-workspace` picks the workspace); local ones are a new shell on This Mac. |
| `vm tools <id>`, `vm tool-inspector <id>` | Inspect installed tools inside the VM. |
| `vm ports <id>` | Show listening TCP ports inside the VM. |
| `vm handoff <id>` | Print a short attach handoff block. |
| `vm promote-template <id>` | Promote the VM into a reusable template. |

Remotes subcommands:

| Command | Contract |
| --- | --- |
| `remotes list`, `remotes ls` | List the team's registered remotes (name, deviceId, routes, tag, last seen). Supports `--json`. |
| `remotes add <name>` | Register or update a remote with one or more `--route <host:port>`. Supports `--tag` and `--json`. Idempotent on `<name>` (re-adding updates routes). The host must be a Tailscale address the phone can authenticate to (CGNAT `100.64.x.x`-`100.127.x.x` or `*.ts.net`); loopback, plain LAN IPs, and bare hostnames are rejected. |
| `remotes remove <name-or-deviceId>` | Remove a remote you registered. Aliases `rm`, `delete`. Supports `--json`. |

CodeRouter subcommands (cmux-owned; anything else passes through to the CodeRouter CLI, which `cmux cr` offers to install when the machine has none):

| Command | Contract |
| --- | --- |
| `coderouter status` | Sign-in state (`auth.status`), selected team, and the team's Claude upstream accounts. Supports `--team <id>` and `--json`. |
| `coderouter machines` | 30-day coderouter usage per Cloud machine from `GET /api/coderouter/vm-usage/team`: vmId, display name, total tokens, API-equivalent USD, plus a total line. Alias `machine`. Supports `--team <id>` and `--json` (raw team-usage payload). |
| `coderouter claude list` | Every Claude upstream account of the team: id, kind, masked identifier, label, health (`active`, `disabled`, `cooling down Ns <failure code>`), last use. Aliases `ls`, `show`, `get`, `status`. Supports `--team <id>` and `--json`. |
| `coderouter claude add oauth-token` | Add a Claude Code OAuth token (`sk-ant-oat01-...`, from `claude setup-token`) as one more account. In a terminal, cmux runs `claude setup-token` and parses its output automatically. It also reads `CLAUDE_CODE_OAUTH_TOKEN`, stdin with `--stdin` or a non-TTY stdin, or a hidden terminal prompt; never from argv. `--label <s>` names it. A non-`sk-ant-oat01-` value is rejected before the socket is used. Prints the masked identifier and account id only. `set` is an alias of `add`. Supports `--team <id>` and `--json`. |
| `coderouter claude add api-key` | Same intake (`ANTHROPIC_API_KEY`, `--stdin`, hidden prompt) for an Anthropic API key (`sk-ant-...`, not `sk-ant-oat`). |
| `coderouter claude add bedrock` | Amazon Bedrock credentials from `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, optional `AWS_SESSION_TOKEN`; `--region <r>` (default `AWS_REGION` / `AWS_DEFAULT_REGION`); repeatable `--model <claude-id>=<bedrock-id>`. |
| `coderouter claude remove <account>` | Remove one account. `<account>` is the id, or a label or masked identifier that matches exactly one account (ambiguity is an error naming the count). Idempotent. Aliases `rm`, `delete`. |
| `coderouter claude disable <account>`, `coderouter claude enable <account>` | Take an account out of routing, or put it back, via `coderouter.claude_upstream.update`. Same selector rules as `remove`. |
| `coderouter claude clear` | Remove every Claude upstream account of the team (`No Claude upstream accounts were set.` when none). Aliases `remove-all`, `unset`. Supports `--team <id>` and `--json`. |

Socket methods: `coderouter.claude_upstream.get|add|update|remove|clear` (`set` is an alias of `add`), `coderouter.machines`. Sign-in failures surface as the `auth_required` code, like `vm`.

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

### Workspace environment variables

A workspace can carry a set of user-defined environment variables that every
shell spawned in it inherits.

Setting them:

- CLI: `zerocmux new-workspace --env KEY=VALUE [--env ...] [--env-file <path>]`
  (and the same flags on `zerocmux workspace create`). `--env` is repeatable;
  `--env-file` reads `KEY=VALUE` lines (blank lines and `#` comments ignored, an
  optional leading `export ` stripped). When both are given, `--env` overrides a
  value from a file.
- Project config (`cmux.json`): an `env` object on a workspace definition, e.g.
  `{ "name": "Build", "cwd": ".", "env": { "AWS_PROFILE": "prod" } }`.
- Socket: the `workspace_env` param on `workspace.create`.

Inspecting them: `zerocmux workspace env [<handle>] [--mask] [--json]` prints the
configured set. `--mask` redacts the values so secrets are not echoed in full.
The env set is intentionally omitted from `workspace list` output so a plain
listing never leaks secrets.

Semantics:

- **Inheritance.** The variables apply to the workspace's initial shell and to
  every pane, surface, and split created later in that workspace — no per-pane
  re-export. They are also re-applied to every shell recreated on session
  restore.
- **Persistence.** They are stored on the workspace in the session manifest, so
  they survive app restart, daemon restart, and session restore.
- **Precedence.** Workspace env overlays the inherited process environment. It is
  applied as the shell's startup environment, so it is visible to login-shell
  init files (`~/.zprofile`, `~/.zshrc`) as they run, but any `export` those
  files perform for the same key wins for the interactive session (they run after
  the variable is seeded). An explicit per-surface environment (a layout
  `surfaces[].env`, SSH startup env) overrides the workspace value for that
  surface.
- **Protected `CMUX_*` variables.** Workspace env can never override the managed
  variables zerocmux injects (e.g. `CMUX_WORKSPACE_ID`, `CMUX_SURFACE_ID`,
  `CMUX_SOCKET_PATH`, `CMUX_SOCKET_PASSWORD`) or the terminal identity variables
  (`TERM`, `COLORTERM`, `TERM_PROGRAM`); those keys are protected at spawn time
  and silently win.
- **Secrets.** Values may be secrets. They are never logged, are masked by
  `--mask`, and are kept out of `workspace list`. Prefer `--env-file` so secrets
  do not land in shell history. Note that values stored in the session manifest
  live on disk in plaintext.

### Initial terminal command

`new-workspace`, `new-split`, `new-pane`, and `new-surface` accept
`--command <text>` (also `--command=<text>`; a value is required).

- CLI: the text is sent to the v2 socket as `initial_input` with one trailing
  Enter (`\r`) appended. Command text is preserved literally, including quotes,
  `&&`, pipes, and `$VARS`, which the new shell interprets.
- Socket: `initial_input` on `workspace.create`, `surface.split`, `pane.create`,
  and `surface.create` (including Dock placement). The value is delivered raw at
  spawn time as the terminal's initial input, so socket clients append their own
  Enter keystroke.

Semantics:

- **Interactive shell stays alive.** The terminal spawns its normal interactive
  shell and the text is typed into it, so the shell remains after the command
  exits. This differs from the pre-existing `initial_command` socket param,
  which replaces the shell with a one-shot process; `initial_command` is
  unchanged.
- **Terminal-only.** The CLI rejects `--command` when `--type` is explicitly
  non-terminal (`browser`, `simulator`, `agent-session`), and the socket
  rejects `initial_input` with `invalid_params` when `type` is present and not
  `terminal`. A null `type` is treated as omitted (terminal).
- **Blank input is ignored.** Empty or whitespace-only text is dropped and no
  `initial_input` is sent.
- **Layouts win.** `new-workspace --layout` ignores `--command`; layout surfaces
  define their own commands. Without `--layout`, the command is injected at
  spawn and no follow-up `surface.send_text` is issued.
- **Remote tmux mirrors fail closed.** A mirrored remote-tmux workspace rejects
  creation requests carrying `initial_input` instead of dropping the command.
  A split next to a cloud-projected pane with explicit `initial_input` stays
  local.

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
| `browser press`, `browser key`, `browser keydown`, `browser keyup` | Send keyboard input as `--key <key>` or positional `<key>` using Playwright/W3C names such as `Enter`, `Tab`, `Escape`, `ArrowLeft`, and `Space`. Supported keys are replayed through native WebKit input so browser default behavior (including contenteditable caret movement and scrolling) runs; opaque key tokens retain a page-event compatibility fallback. `Space`, `Spacebar`, and `space` emit DOM key `" "` with code `"Space"`; raw `--key ' '` is also accepted. Use `keydown`/`keyup` around a supported modifier to hold it across a subsequent key action. |
| `browser select` | Select an option. |
| `browser scroll` | Scroll page or element. |
| `browser screenshot` | Save a screenshot. |
| `browser get` | Read URL, title, text, HTML, value, attr, count, box, or styles. |
| `browser is` | Check visible, enabled, or checked state. |
| `browser find` | Find by role, text, label, placeholder, alt, title, testid, first, last, or nth. |
| `browser frame` | Select frame context. |
| `browser dialog` | Accept or dismiss dialogs. |
| `browser download` | Wait for or save downloads. |
| `browser profiles` | List, add, rename, clear, or delete zerocmux browser profiles. `clear` refuses to wipe active profiles unless `--force` is passed. |
| `browser import` | Open the browser import wizard. In detected coding-agent environments, defaults to non-interactive cookie import; pass `--interactive` to force the wizard. Non-interactive import supports `--from`, `--profile`, `--all-profiles`, `--to-profile`, `--create-profile`, and `--domain`. |
| `browser cookies` | Get, set, or clear cookies; `set` accepts `--http-only` to keep the cookie hidden from page JavaScript. `clear` requires an explicit scope such as `--url`, `--domain`, `--name`, or `--all`, and returns the removed count as `cleared` in JSON output. |
| `browser storage` | Get, set, or clear local/session storage. |
| `browser tab` | Create, list, switch, or close browser tabs. |
| `browser console`, `browser errors` | List or clear console messages and errors. |
| `browser highlight` | Highlight an element. |
| `browser state` | Save or load browser state. |
| `browser addinitscript`, `browser addscript`, `browser addstyle` | Inject scripts or CSS. |
| `browser viewport <width> <height>` | Emulate an exact logical viewport from 1×1 through 4096×4096 CSS pixels. WKWebView aspect-fits the page inside its current pane without resizing the pane or changing focus; screenshots use the emulated dimensions. |
| `browser viewport reset` | Restore native viewport sizing so the page follows its pane dimensions. |
| `browser geolocation`, `browser geo` | Set geolocation. |
| `browser offline` | Toggle offline state. |
| `browser trace` | Start or stop trace capture. |
| `browser network` | Route, unroute, or list requests. |
| `browser screencast` | Start or stop screencast. |
| `browser input`, `browser input_mouse`, `browser input_keyboard`, `browser input_touch` | Send low-level input. |
| `browser identify` | Identify browser surface context. |

`browser screenshot` reports `screenshot_mismatch` when conservative DOM/pixel
attestation still disagrees after its retry, `timeout` when capture cannot
complete within its bounded budget or another capture is already in progress,
and `internal_error` for other failures. Clients may retry `timeout` and
`screenshot_mismatch`; cmux does not return the suspect image.

`browser viewport` changes the selected browser surface only. On WKWebView, the
requested logical size becomes `window.innerWidth`/`window.innerHeight` and the
page is uniformly scaled to fit inside the existing pane. The pane layout and
other surfaces do not move. Visible screenshots are normalized to exactly those
CSS-pixel dimensions, independent of the display backing scale. JSON results
report `mode`, effective `width` and `height`, displayed size, `scale`,
`presentation`, and `pane_resized`. `reset` reports the actual native CSS
viewport, including the current page zoom.

zerocmux bounds the combined viewport and page-zoom render geometry to 8192 points
per dimension and 33,554,432 points of area. If the current zoom would exceed
that bound, `browser.viewport.set` leaves the current viewport unchanged and
returns `invalid_params` with
`reason: viewport_zoom_render_geometry_too_large`, `requested_page_zoom`, and
`maximum_page_zoom`. While emulation is active, browser zoom commands also stop
at that maximum. A visible attached browser inspector owns the same layout;
close or detach it before changing the viewport. In that state the v2 method
returns `invalid_state` with `reason: attached_browser_inspector`. Opening or
redocking an attached inspector while emulation is active resets the viewport to
native sizing before WebKit takes ownership of the split geometry.

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
| `hooks <agent> <event>` | Generic hook surface for `grok`, `opencode`, `pi`, `amp`, `cursor`, `gemini`, `kimi`, `rovodev`, `copilot`, `codebuddy`, `factory`, and `qoder`. |

Kimi hook setup targets the config file `kimi doctor` reports. Without a reported path, it takes the first of `${KIMI_CODE_HOME:-~/.kimi-code}/config.toml` (Kimi Code CLI) and `${KIMI_SHARE_DIR:-~/.kimi}/config.toml` (Kimi CLI 1.49 and earlier) that already exists as a file, then the first whose directory exists, and the Kimi Code CLI path when neither directory exists. Setup refreshes, but never removes, a cmux marker block already present in the other location; `hooks kimi uninstall` removes the block from both.

Right sidebar commands:

| Command | Contract |
| --- | --- |
| `right-sidebar toggle`, `right-sidebar show`, `right-sidebar hide` | Change right-sidebar visibility without printing on success. |
| `right-sidebar focus` | Focus the current right-sidebar mode. |
| `right-sidebar set <files\|find\|vault\|sessions\|feed\|dock\|cloud>` | Show the right sidebar, switch mode, and focus it unless `--no-focus` is passed. |
| `right-sidebar files`, `right-sidebar find`, `right-sidebar vault`, `right-sidebar sessions`, `right-sidebar feed`, `right-sidebar dock`, `right-sidebar cloud` | Short aliases for `right-sidebar set <mode>` with focus. `cloud` (aliases `machines`, `vms`) is the Cloud machines panel; `mode` reports it as `machines`. |
| `right-sidebar mode` | Print JSON with `visible` and `mode`. |
| `--workspace <id\|ref\|index>` | Target the window containing a workspace. Refs and indexes resolve before the V1 socket command is sent. |
| `--window <id\|ref\|index>` | Target a window. Refs and indexes resolve before the V1 socket command is sent. |
| `--no-focus` | Only valid with `set`; switches mode without moving focus. |

Custom sidebar commands:

| Command | Contract |
| --- | --- |
| `sidebar validate [name]` | Validate all custom sidebars, or one named sidebar, under `~/.config/cmux/sidebars`. |
| `sidebar reload [name]` | Validate all custom sidebars, then request a reload for every valid one. |
| `sidebar select <name>` | Validate and activate one custom sidebar in the sidebar picker. |
| `sidebar open <name>` | Validate and open one custom sidebar as a normal Bonsplit pane tab, preferring the right-side split from the focused surface. |

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
| `config get sidebar-font-size` | Print the effective sidebar text size. |
| `config set sidebar-font-size <points>` | Write the sidebar text size to zerocmux's editable Ghostty config and reload the running app when available. |
| `config sidebar-font-size [points]` | Get the sidebar text size, or set it when a point size is provided. |
| `config get surface-tab-bar-font-size` | Print the effective workspace tab bar text size. |
| `config set surface-tab-bar-font-size <points>` | Write the workspace tab bar text size to zerocmux's editable Ghostty config and reload the running app when available. |
| `config surface-tab-bar-font-size [points]` | Get the workspace tab bar text size, or set it when a point size is provided. |
| `config get <key>`, `config set <key> <points>` | Generic get/set for `sidebar-font-size` and `surface-tab-bar-font-size`. |

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

## Workspace todos

Each workspace carries a persisted checklist plus a todo lifecycle status,
shared by the sidebar row, the checklist popover, the todo pane, `zerocmux todo`
/ `zerocmux workspace status`, and the `workspace.todo.*` / `workspace.status.*`
socket verbs (all funnel through the same mutation entry points).

Agent policy: the checklist and manual status pins belong to the user.
Coding agents must not create, edit, complete, remove, or replace checklist
items, and must not `set`/`cycle` the status, unless the user explicitly
asks them to manage that surface — a request to manage checklist items or
a request to manage manual status pins. The status lane already tracks
agent activity automatically through inference; agents should keep their
own plans in their internal task tracking.

Item schema (wire and `todo list --json` shape):

| Field | Contract |
| --- | --- |
| `id` | Stable item UUID, assigned at creation and preserved across edits. |
| `text` | Trimmed, non-empty, capped at 500 characters. |
| `state` | `pending`, `in-progress`, or `completed`. |
| `origin` | `user` or `agent`; who created the item. |

Caps and ordering: at most 50 items per workspace. Storage order is the
creation/`set` order and is what `todo list` prints and the wire returns;
the sidebar/popover/pane rendering that floats unchecked items above
completed ones is display-only and never reorders storage.

`zerocmux todo set` atomically replaces the whole checklist from a JSON array of
`{text, state?, id?, origin?}` objects (inline argument, or piped on stdin;
also accepts `{"items": [...]}`). Items whose `id` matches an existing item
keep that identity and its origin (state updates when given, else stays);
other items are created (`origin` defaults to `user`, `state` to `pending`);
existing items not named are removed. The whole replace is rejected — nothing
mutated — if any text is empty after trimming or the array exceeds 50 items.
The reply is the full resulting list payload. `zerocmux todo open` (socket:
`workspace.todo.open`) opens or focuses the workspace's todo pane, so a
script can drive the pane as a generic list surface:

```bash
# Mirror a build script's step list into the workspace todo pane.
./plan-steps.sh --json |            # emits [{"text":"lint","state":"completed"}, ...]
  zerocmux todo set
zerocmux todo open
```

Re-running `zerocmux todo set` with the same `id`s updates text/state in place
(checkbox identity is stable), so a watcher loop can re-emit the full list on
every tick without churning item identities.

## No-Socket Help Probes

The following probes are executable contract checks. They must exit 0 and print
the expected text without connecting to a zerocmux socket.

<!-- cli-contract-help-probes:start -->
- `zerocmux --help` -> `zerocmux - control zerocmux via Unix socket`
- `zerocmux --help` -> `open <path-or-url>...`
- `zerocmux --help` -> `sessions [list] [options]`
- `zerocmux help` -> `zerocmux - control zerocmux via Unix socket`
- `zerocmux sessions --help` -> `Usage: zerocmux sessions list [options]`
- `zerocmux ping --help` -> `Usage: zerocmux ping`
- `zerocmux capabilities --help` -> `Usage: zerocmux capabilities`
- `zerocmux events --help` -> `Usage: zerocmux events [options]`
- `zerocmux auth --help` -> `Usage: zerocmux auth <status|login|logout>`
- `zerocmux vm --help` -> `Usage: zerocmux vm <base|new|ls|domains|tree|self|status|stats|rename|pause|resume|snapshot|fork|restore|rm|run|route|agent|dev|prompt|exec|push|pull|wait|shell|tui|desktop|open|workspace|terminal|tab|layout|env|ports|tools|handoff|promote-template|attach|ssh|ssh-info> [args...]`
- `zerocmux cloud --help` -> `Usage: zerocmux cloud <base|new|ls|domains|tree|self|status|stats|rename|pause|resume|snapshot|fork|restore|rm|run|route|agent|dev|prompt|exec|push|pull|wait|shell|tui|desktop|open|workspace|terminal|tab|layout|env|ports|tools|handoff|promote-template|attach|ssh|ssh-info> [args...]`
- `zerocmux vm ls --help` -> `Usage: zerocmux vm <base|new|ls|domains|tree|self|status|stats|rename|pause|resume|snapshot|fork|restore|rm|run|route|agent|dev|prompt|exec|push|pull|wait|shell|tui|desktop|open|workspace|terminal|tab|layout|env|ports|tools|handoff|promote-template|attach|ssh|ssh-info> [args...]`
- `zerocmux vm domains --help` -> `zerocmux cloud domains [list]`
- `zerocmux vm run --help` -> `Usage: zerocmux vm run [--sync] [--pull <remote-path>] [--machine <id>] [--new] [--size <20g>] [--timeout <seconds>] -- <command...>`
- `zerocmux vm run -h` -> `Usage: zerocmux vm run [--sync] [--pull <remote-path>] [--machine <id>] [--new] [--size <20g>] [--timeout <seconds>] -- <command...>`
- `zerocmux cloud run --help` -> `Usage: zerocmux vm run [--sync] [--pull <remote-path>] [--machine <id>] [--new] [--size <20g>] [--timeout <seconds>] -- <command...>`
- `zerocmux vm route --help` -> `Usage: zerocmux vm route [--cwd <dir>] [--new] [--provision] [--size <20g>] [--json]`
- `zerocmux vm agent --help` -> `Usage: zerocmux vm agent --agent <claude|codex|opencode|pi> [--machine <id>] [--sync] [--cwd <dir>] [--name <name>] [--no-open] [--remote-workspace <ws>] [--wait [--output] [--timeout <seconds>]] [--new] [--size <s>] [--json] -- <prompt or args...>`
- `zerocmux vm push --help` -> `Usage: zerocmux vm push <id> <local-path> [remote-path] [--exclude <pattern>]... [--no-default-excludes]`
- `zerocmux vm upload --help` -> `Usage: zerocmux vm push <id> <local-path> [remote-path] [--exclude <pattern>]... [--no-default-excludes]`
- `zerocmux vm pull --help` -> `Usage: zerocmux vm pull <id> <remote-path> [local-path]`
- `zerocmux vm download --help` -> `Usage: zerocmux vm pull <id> <remote-path> [local-path]`
- `zerocmux vm wait --help` -> `Usage: zerocmux vm wait <id> [--timeout <seconds>] [--wake]`
- `zerocmux vm open --help` -> `Usage: zerocmux vm open <target> [--workspace <id|ref|index>] [--focus <true|false>] [--print]`
- `zerocmux vm tree --help` -> `Usage: zerocmux vm tree [<machine>|local] [--refresh] [--json]`
- `zerocmux vm workspace --help` -> `zerocmux vm workspace open <machine> <workspace-id>`
- `zerocmux vm terminal --help` -> `zerocmux vm terminal close <machine> <terminal-id>`
- `zerocmux vm prompt --help` -> `zerocmux vm prompt --open <agent>`
- `zerocmux vm base --help` -> `zerocmux vm base reset [--desktop|--base] [--reason <text>]`
- `zerocmux surface --help` -> `Usage: zerocmux surface ls [<machine>|local] [--refresh] [--json]`
- `zerocmux remotes --help` -> `Usage: zerocmux remotes <list|add|remove> [options]`
- `zerocmux remote --help` -> `Usage: zerocmux remotes <list|add|remove> [options]`
- `zerocmux coderouter --help` -> `Usage: zerocmux coderouter <status|machines|claude|agent> [options]`
- `zerocmux rpc --help` -> `Usage: zerocmux rpc <method> [json-params]`
- `zerocmux comments --help` -> `Usage: zerocmux comments <subcommand> [options]`
- `zerocmux vault --help` -> `Usage: zerocmux vault <subcommand> [options]`
- `zerocmux help --help` -> `Usage: zerocmux help`
- `zerocmux docs --help` -> `Usage: zerocmux docs [settings|shortcuts|api|browser|agents|dock|managed-policies]`
- `zerocmux docs` -> `Topics:`
- `zerocmux docs settings` -> `Config files:`
- `zerocmux docs dock` -> `dock: Custom right-sidebar terminal controls`
- `zerocmux settings --help` -> `Usage: zerocmux settings [open [target]|path|docs|<target>]`
- `zerocmux settings path` -> `Config files:`
- `zerocmux settings docs` -> `Config files:`
- `zerocmux config --help` -> `Usage: zerocmux config <doctor|check|validate|path|paths|docs|documentation|reload|get|set|sidebar-font-size|surface-tab-bar-font-size>`
- `zerocmux config path` -> `Config files:`
- `zerocmux config docs` -> `Config files:`
- `zerocmux welcome --help` -> `Usage: zerocmux welcome`
- `zerocmux welcome` -> `Toggle Left Sidebar`
- `zerocmux welcome` -> `Toggle Right Sidebar`
- `zerocmux shortcuts --help` -> `Usage: zerocmux shortcuts`
- `zerocmux disable-browser --help` -> `Usage: zerocmux disable-browser [--json]`
- `zerocmux enable-browser --help` -> `Usage: zerocmux enable-browser [--json]`
- `zerocmux browser-status --help` -> `Usage: zerocmux browser-status [--json]`
- `zerocmux agent-hibernation --help` -> `Usage: zerocmux agent-hibernation <on|off> [--json]`
- `zerocmux restore --help` -> `Usage: zerocmux restore [--surface <id|ref>] <kind> <checkpoint-id>`
- `zerocmux fork --help` -> `Usage: zerocmux fork [--surface <id|ref>] <kind> <checkpoint-id>`
- `zerocmux restore-session --help` -> `Usage: zerocmux restore-session`
- `zerocmux open --help` -> `Usage: zerocmux open <path-or-url>...`
- `zerocmux feedback --help` -> `Usage: zerocmux feedback`
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
- `zerocmux reorder-workspaces --help` -> `Usage: zerocmux reorder-workspaces`
- `zerocmux workspace-action --help` -> `Usage: zerocmux workspace-action --action <name>`
- `zerocmux move-tab-to-new-workspace --help` -> `Usage: zerocmux move-tab-to-new-workspace`
- `zerocmux tab-action --help` -> `Usage: zerocmux tab-action --action <name>`
- `zerocmux rename-tab --help` -> `Usage: zerocmux rename-tab`
- `zerocmux new-workspace --help` -> `Usage: zerocmux new-workspace`
- `zerocmux new-workspace --help` -> `--command <text>`
- `zerocmux list-workspaces --help` -> `Usage: zerocmux list-workspaces`
- `zerocmux ssh --help` -> `Usage: zerocmux ssh <destination>`
- `zerocmux ssh --help` -> `--forward-agent`
- `zerocmux ssh --help` -> `--transport <ssh|mosh>`
- `zerocmux mosh --help` -> `Usage: zerocmux mosh <destination>`
- `zerocmux mosh-tmux --help` -> `Usage: zerocmux mosh-tmux <destination>`
- `zerocmux mosh-tmux --help` -> `--session <name>`
- `zerocmux ssh --help` -> `--command <text>`
- `zerocmux ssh-session-list --help` -> `Usage: zerocmux ssh-session-list`
- `zerocmux ssh-session-attach --help` -> `Usage: zerocmux ssh-session-attach --session-id <id>`
- `zerocmux ssh-session-cleanup --help` -> `Usage: zerocmux ssh-session-cleanup`
- `zerocmux new-split --help` -> `Usage: zerocmux new-split`
- `zerocmux new-split --help` -> `--command <text>`
- `zerocmux list-panes --help` -> `Usage: zerocmux list-panes`
- `zerocmux list-pane-surfaces --help` -> `Usage: zerocmux list-pane-surfaces`
- `zerocmux tree --help` -> `Usage: zerocmux tree`
- `zerocmux top --help` -> `Usage: zerocmux top`
- `zerocmux focus-pane --help` -> `Usage: zerocmux focus-pane`
- `zerocmux new-pane --help` -> `Usage: zerocmux new-pane`
- `zerocmux new-pane --help` -> `--command <text>`
- `zerocmux new-surface --help` -> `Usage: zerocmux new-surface`
- `zerocmux new-surface --help` -> `--command <text>`
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
- `zerocmux dismiss-notification --help` -> `Usage: zerocmux dismiss-notification`
- `zerocmux mark-notification-read --help` -> `Usage: zerocmux mark-notification-read`
- `zerocmux open-notification --help` -> `Usage: zerocmux open-notification`
- `zerocmux jump-to-unread --help` -> `Usage: zerocmux jump-to-unread`
- `zerocmux clear-notifications --help` -> `Usage: zerocmux clear-notifications`
- `zerocmux right-sidebar --help` -> `Usage: zerocmux right-sidebar <command> [flags]`
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

For `cmux restore`, `--surface [id|ref]` uses the caller when omitted.

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
- `zerocmux codex-teams --help` is handled by the command launcher, not by the
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
