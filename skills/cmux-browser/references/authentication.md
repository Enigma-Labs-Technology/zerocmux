# Authentication Patterns

Login flows, session persistence, OAuth, and 2FA patterns for zerocmux browser surfaces.

Set `SURFACE` from [surface discovery](surface-discovery.md) or from the JSON
returned by `browser open`. Never guess a default surface or log credentials.

Saved browser state contains cookies and storage. Use a private directory with
restrictive permissions before saving it:

```bash
STATE_DIR="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/cmux-browser-state"
umask 077
mkdir -p "$STATE_DIR"
chmod 700 "$STATE_DIR"
STATE_FILE="$STATE_DIR/auth-state.json"
```

## Basic login

```bash
OPEN_JSON="$(zerocmux --json browser open https://app.example.com/login --focus false)"
SURFACE="$(printf '%s' "$OPEN_JSON" | jq -r '.surface_ref // .surface_id // empty')"
[ -n "$SURFACE" ] || { printf '%s\n' 'browser open did not return a surface ref' >&2; exit 1; }
zerocmux browser --surface "$SURFACE" wait --load-state complete --timeout-ms 15000
zerocmux browser --surface "$SURFACE" snapshot --interactive
zerocmux browser --surface "$SURFACE" fill e1 "$APP_USERNAME"
zerocmux browser --surface "$SURFACE" fill e2 "$APP_PASSWORD"
zerocmux browser --surface "$SURFACE" click e3 --snapshot-after --json
zerocmux browser --surface "$SURFACE" wait --url-contains "/dashboard" --timeout-ms 20000
```

## Saving authentication state

```bash
zerocmux browser --surface "$SURFACE" state save "$STATE_FILE"
chmod 600 "$STATE_FILE"
```

State includes cookies, localStorage, sessionStorage, and open tab metadata for that surface.

## Restoring authentication

```bash
STATE_DIR="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/cmux-browser-state"
umask 077
mkdir -p "$STATE_DIR"
chmod 700 "$STATE_DIR"
STATE_FILE="$STATE_DIR/auth-state.json"
OPEN_JSON="$(zerocmux --json browser open https://app.example.com --focus false)"
SURFACE="$(printf '%s' "$OPEN_JSON" | jq -r '.surface_ref // .surface_id // empty')"
[ -n "$SURFACE" ] || { printf '%s\n' 'browser open did not return a surface ref' >&2; exit 1; }
zerocmux browser --surface "$SURFACE" state load "$STATE_FILE"
zerocmux browser --surface "$SURFACE" goto https://app.example.com/dashboard
zerocmux browser --surface "$SURFACE" snapshot --interactive
```

## OAuth / SSO

Same shape as basic login, waiting on the provider host and then the return host, with generous timeouts:

```bash
OAUTH_STATE_DIR="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/cmux-browser-state"
umask 077
mkdir -p "$OAUTH_STATE_DIR"
chmod 700 "$OAUTH_STATE_DIR"
OAUTH_STATE_FILE="$OAUTH_STATE_DIR/oauth-state.json"
OPEN_JSON="$(zerocmux --json browser open https://app.example.com/auth/provider --focus false)"
SURFACE="$(printf '%s' "$OPEN_JSON" | jq -r '.surface_ref // .surface_id // empty')"
[ -n "$SURFACE" ] || { printf '%s\n' 'browser open did not return a surface ref' >&2; exit 1; }
zerocmux browser --surface "$SURFACE" wait --url-contains "login.example.com" --timeout-ms 30000
zerocmux browser --surface "$SURFACE" snapshot --interactive
# fill and click the provider's fields
zerocmux browser --surface "$SURFACE" wait --url-contains "app.example.com" --timeout-ms 45000
zerocmux browser --surface "$SURFACE" state save "$OAUTH_STATE_FILE"
chmod 600 "$OAUTH_STATE_FILE"
```

## Two-factor

```bash
zerocmux browser open https://app.example.com/login --json
zerocmux browser surface:7 snapshot --interactive
zerocmux browser surface:7 fill e1 "user@example.com"
zerocmux browser surface:7 fill e2 "$APP_PASSWORD"
zerocmux browser surface:7 click e3

# complete 2FA manually in the webview, then:
zerocmux browser surface:7 wait --url-contains "/dashboard" --timeout-ms 120000
zerocmux browser surface:7 state save ./2fa-state.json
```

## Cookie-Based Auth

```bash
zerocmux browser --surface "$SURFACE" cookies set session_cookie "$SESSION_COOKIE"
zerocmux browser --surface "$SURFACE" goto https://app.example.com/dashboard
```

## Token refresh

Load saved state, navigate, and re-login only when the URL bounced to `/login`:

```bash
#!/usr/bin/env bash
set -euo pipefail
STATE_DIR="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/cmux-browser-state"
umask 077
mkdir -p "$STATE_DIR"
chmod 700 "$STATE_DIR"
STATE_FILE="${STATE_FILE:-$STATE_DIR/auth-state.json}"
: "${SURFACE:?set SURFACE from browser open or surface discovery}"

[ -f "$STATE_FILE" ] && zerocmux browser --surface "$SURFACE" state load "$STATE_FILE"
zerocmux browser --surface "$SURFACE" goto https://app.example.com/dashboard

if zerocmux browser --surface "$SURFACE" get url | grep -q '/login'; then
  zerocmux browser --surface "$SURFACE" snapshot --interactive
  zerocmux browser --surface "$SURFACE" fill e1 "$APP_USERNAME"
  zerocmux browser --surface "$SURFACE" fill e2 "$APP_PASSWORD"
  zerocmux browser --surface "$SURFACE" click e3
  zerocmux browser --surface "$SURFACE" wait --url-contains "/dashboard" --timeout-ms 20000
  zerocmux browser --surface "$SURFACE" state save "$STATE_FILE"
  chmod 600 "$STATE_FILE"
fi
```

## Security

Never commit state files; they contain auth tokens. Take credentials from environment variables. Clear state after sensitive tasks:

```bash
zerocmux browser --surface "$SURFACE" cookies clear --all
STATE_DIR="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/cmux-browser-state"
STATE_FILE="${STATE_FILE:-$STATE_DIR/auth-state.json}"
OAUTH_STATE_FILE="${OAUTH_STATE_FILE:-$STATE_DIR/oauth-state.json}"
rm -f "$STATE_FILE"
rm -f "$OAUTH_STATE_FILE"
```
