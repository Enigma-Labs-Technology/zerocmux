# Command Reference (zerocmux Browser)

This maps common `agent-browser` usage to `zerocmux browser` usage.

## Direct Equivalents

- `agent-browser open <url>` -> `zerocmux browser open <url>`
- `agent-browser goto|navigate <url>` -> `zerocmux browser <surface> goto|navigate <url>`
- `agent-browser snapshot -i` -> `zerocmux browser <surface> snapshot --interactive`
- `agent-browser click <ref>` -> `zerocmux browser <surface> click <ref>`
- `agent-browser fill <ref> <text>` -> `zerocmux browser <surface> fill <ref> <text>`
- `agent-browser type <ref> <text>` -> `zerocmux browser <surface> type <ref> <text>`
- `agent-browser select <ref> <value>` -> `zerocmux browser <surface> select <ref> <value>`
- `agent-browser get text <ref>` -> `zerocmux browser <surface> get text <ref-or-selector>`
- `agent-browser get url` -> `zerocmux browser <surface> get url`
- `agent-browser get title` -> `zerocmux browser <surface> get title`

## Core Command Groups

### Navigation

```bash
zerocmux browser open <url>                        # opens in caller's workspace (uses CMUX_WORKSPACE_ID)
zerocmux browser open <url> --workspace <id|ref>   # opens in a specific workspace
zerocmux browser <surface> goto <url>
zerocmux browser <surface> back|forward|reload
zerocmux browser <surface> get url|title
```

> **Workspace context:** `browser open` targets the workspace of the terminal where the command is run (via `CMUX_WORKSPACE_ID`), even if a different workspace is currently focused. Use `--workspace` to override.

### Snapshot and Inspection

```bash
zerocmux browser <surface> snapshot --interactive
zerocmux browser <surface> snapshot --interactive --compact --max-depth 3
zerocmux browser <surface> get text body
zerocmux browser <surface> get html body
zerocmux browser <surface> get value "#email"
zerocmux browser <surface> get attr "#email" --attr placeholder
zerocmux browser <surface> get count ".row"
zerocmux browser <surface> get box "#submit"
zerocmux browser <surface> get styles "#submit" --property color
zerocmux browser <surface> eval '<js>'
```

### Interaction

```bash
zerocmux browser <surface> click|dblclick|hover|focus <selector-or-ref>
zerocmux browser <surface> fill <selector-or-ref> [text]   # empty text clears
zerocmux browser <surface> type <selector-or-ref> <text>
zerocmux browser <surface> press|keydown|keyup <key>
zerocmux browser <surface> select <selector-or-ref> <value>
zerocmux browser <surface> check|uncheck <selector-or-ref>
zerocmux browser <surface> scroll [--selector <css>] [--dx <n>] [--dy <n>]
```

### Wait

```bash
zerocmux browser <surface> wait --selector "#ready" --timeout-ms 10000
zerocmux browser <surface> wait --text "Done" --timeout-ms 10000
zerocmux browser <surface> wait --url-contains "/dashboard" --timeout-ms 10000
zerocmux browser <surface> wait --load-state complete --timeout-ms 15000
zerocmux browser <surface> wait --function "document.readyState === 'complete'" --timeout-ms 10000
```

### Session/State

```bash
zerocmux browser <surface> cookies get|set|clear ...
zerocmux browser <surface> storage local|session get|set|clear ...
zerocmux browser <surface> tab list|new|switch|close ...
zerocmux browser <surface> state save|load <path>
```

### Diagnostics

```bash
zerocmux browser <surface> console list|clear
zerocmux browser <surface> errors list|clear
zerocmux browser <surface> highlight <selector>
zerocmux browser <surface> screenshot
zerocmux browser <surface> download wait --timeout-ms 10000
```

## Agent Reliability Tips

- Use `--snapshot-after` on mutating actions to return a fresh post-action snapshot.
- Re-snapshot after navigation, modal open/close, or major DOM changes.
- Prefer short handles in outputs by default (`surface:N`, `pane:N`, `workspace:N`, `window:N`).
- Use `--id-format both` only when a UUID must be logged/exported.

## Known WKWebView Gaps (`not_supported`)

- `browser.viewport.set`
- `browser.geolocation.set`
- `browser.offline.set`
- `browser.trace.start|stop`
- `browser.network.route|unroute|requests`
- `browser.screencast.start|stop`
- `browser.input_mouse|input_keyboard|input_touch`

See also:
- [snapshot-refs.md](snapshot-refs.md)
- [authentication.md](authentication.md)
- [session-management.md](session-management.md)
