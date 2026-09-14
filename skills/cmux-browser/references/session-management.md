# Session Management

zerocmux uses isolated browser contexts per surface. Treat each browser surface as its own session.

Keep the handle returned by creation or
[surface discovery](surface-discovery.md); never use a guessed default.

## Parallel sessions

Each `cmux browser open` returns a new surface ref; drive them independently.

```bash
FIRST_JSON="$(zerocmux --json browser open https://site-a.example --focus false)"
FIRST_SURFACE="$(printf '%s' "$FIRST_JSON" | jq -r '.surface_ref // .surface_id // empty')"
SECOND_JSON="$(zerocmux --json browser open https://site-b.example --focus false)"
SECOND_SURFACE="$(printf '%s' "$SECOND_JSON" | jq -r '.surface_ref // .surface_id // empty')"
[ -n "$FIRST_SURFACE" ] && [ -n "$SECOND_SURFACE" ] || exit 1

ARTIFACT_DIR="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/cmux-browser-output"
umask 077
mkdir -p "$ARTIFACT_DIR"
chmod 700 "$ARTIFACT_DIR"
zerocmux browser --surface "$FIRST_SURFACE" get text body > "$ARTIFACT_DIR/a.txt"
zerocmux browser --surface "$SECOND_SURFACE" get text body > "$ARTIFACT_DIR/b.txt"
chmod 600 "$ARTIFACT_DIR/a.txt" "$ARTIFACT_DIR/b.txt"
```

## Isolation Properties

Each surface has independent:
- cookies
- localStorage/sessionStorage
- tab list and active tab
- navigation history

## State Persistence

### Save State

```bash
STATE_DIR="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/cmux-browser-state"
umask 077
mkdir -p "$STATE_DIR"
chmod 700 "$STATE_DIR"
STATE_FILE="$STATE_DIR/auth.json"
SOURCE_SURFACE="surface:7"       # from discovery
DESTINATION_JSON="$(zerocmux --json browser open https://app.example.com --focus false)"
DESTINATION_SURFACE="$(printf '%s' "$DESTINATION_JSON" | jq -r '.surface_ref // .surface_id // empty')"
[ -n "$DESTINATION_SURFACE" ] || exit 1
zerocmux browser --surface "$SOURCE_SURFACE" state save "$STATE_FILE"
chmod 600 "$STATE_FILE"
zerocmux browser --surface "$DESTINATION_SURFACE" state load "$STATE_FILE"
zerocmux browser --surface "$DESTINATION_SURFACE" goto https://app.example.com/dashboard
```

## Cleanup

```bash
STATE_DIR="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/cmux-browser-state"
STATE_FILE="${STATE_FILE:-$STATE_DIR/auth.json}"
zerocmux close-surface --surface surface:7
rm -f "$STATE_FILE"
```

## Best practices

Log only the surface refs needed to keep actions attributable (not raw URLs or
auth payloads), keep one task per surface to avoid ref churn, save state after
successful auth milestones, and re-snapshot after switching tabs or pages
inside a surface.
