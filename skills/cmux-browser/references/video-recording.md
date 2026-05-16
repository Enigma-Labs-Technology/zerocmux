# Video Recording

Status and alternatives for capturing browser automation evidence in zerocmux.

**Related**: [commands.md](commands.md), [SKILL.md](../SKILL.md)

## Contents

- [Current Status](#current-status)
- [Recommended Alternatives](#recommended-alternatives)
- [Use Cases](#use-cases)
- [Best Practices](#best-practices)

## Current Status

`zerocmux browser` currently does not expose a built-in video recording command.

Why: zerocmux browser automation runs on WKWebView, and the agent-browser style recording pipeline is Chrome/CDP-specific.

## Recommended Alternatives

### 1. Step Screenshots

```bash
zerocmux browser surface:7 screenshot > /tmp/step1.b64
zerocmux browser surface:7 click e3 --snapshot-after --json
zerocmux browser surface:7 screenshot > /tmp/step2.b64
```

### 2. Snapshot Timeline

```bash
zerocmux browser surface:7 snapshot --interactive > /tmp/snap-1.txt
zerocmux browser surface:7 click e3 --snapshot-after --json > /tmp/action-1.json
zerocmux browser surface:7 snapshot --interactive > /tmp/snap-2.txt
```

### 3. macOS Window Capture (external)

Use an external screen recorder if full-motion capture is required.

## Use Cases

- Debug flaky browser automation.
- Produce artifacts for CI logs.
- Document flow changes between releases.

## Best Practices

1. Capture snapshot before and after each mutating action.
2. Add `--snapshot-after` on clicks/fills/types that change state.
3. Keep artifacts grouped by timestamp/run id.
