<h1 align="center">zerocmux</h1>
<p align="center">A fast, zero-telemetry terminal workspace for local development and AI agent workflows.</p>

<p align="center">
  A privacy-focused fork of <a href="https://github.com/manaflow-ai/cmux">cmux</a>, built on Ghostty and native macOS technologies.
</p>

<p align="center">
  <img src="./docs/assets/main-first-image.png" alt="zerocmux screenshot" width="900" />
</p>

<p align="center">
  <a href="https://www.youtube.com/watch?v=i-WxO5YUTOs">Upstream demo video</a> · <a href="https://github.com/manaflow-ai/cmux">Upstream project</a>
</p>

## Features

<table>
<tr>
<td width="40%" valign="middle">
<h3>Notification rings</h3>
Panes get a blue ring and tabs light up when coding agents need your attention
</td>
<td width="60%">
<img src="./docs/assets/notification-rings.png" alt="Notification rings" width="100%" />
</td>
</tr>
<tr>
<td width="40%" valign="middle">
<h3>Notification panel</h3>
See all pending notifications in one place, jump to the most recent unread
</td>
<td width="60%">
<img src="./docs/assets/sidebar-notification-badge.png" alt="Sidebar notification badge" width="100%" />
</td>
</tr>
<tr>
<td width="40%" valign="middle">
<h3>In-app browser</h3>
Split a browser alongside your terminal with a scriptable API ported from <a href="https://github.com/vercel-labs/agent-browser">agent-browser</a>
</td>
<td width="60%">
<img src="./docs/assets/built-in-browser.png" alt="Built-in browser" width="100%" />
</td>
</tr>
<tr>
<td width="40%" valign="middle">
<h3>Vertical + horizontal tabs</h3>
Sidebar shows git branch, linked PR status/number, working directory, listening ports, and latest notification text. Split horizontally and vertically.
</td>
<td width="60%">
<img src="./docs/assets/vertical-horizontal-tabs-and-splits.png" alt="Vertical tabs and split panes" width="100%" />
</td>
</tr>
<tr>
<td width="40%" valign="middle">
<h3>SSH</h3>
<code>zerocmux ssh user@remote</code> creates a workspace for a remote machine. Browser panes route through the remote network so localhost just works. Drag an image into a remote session to upload via scp.
</td>
<td width="60%">
<img src="./docs/assets/ssh.png" alt="zerocmux SSH" width="100%" />
</td>
</tr>
<tr>
<td width="40%" valign="middle">
<h3>Claude Code Teams</h3>
<code>zerocmux claude-teams</code> runs Claude Code's teammate mode with one command. Teammates spawn as native splits with sidebar metadata and notifications. No tmux required.
</td>
<td width="60%">
<img src="./docs/assets/claude-code-teams.png" alt="Claude Code Teams" width="100%" />
</td>
</tr>
</table>

- **Browser import** — Import cookies, history, and sessions from Chrome, Firefox, Arc, and 20+ browsers so browser panes start authenticated
- **Custom commands** — Define project-specific actions in `cmux.json` that launch from the command palette
- **Scriptable** — CLI and socket API to create workspaces, split panes, send keystrokes, and automate the browser
- **Native macOS app** — Built with Swift and AppKit, not Electron. Fast startup, low memory.
- **Ghostty compatible** — Reads your existing `~/.config/ghostty/config` for themes, fonts, and colors
- **GPU-accelerated** — Powered by libghostty for smooth rendering

## Telemetry and network access

zerocmux does not collect analytics, usage events, crash reports, session data,
terminal contents, command history, or workspace metadata.

Some inherited source code, agent hooks, and feed UI use the word "telemetry"
for local status events. In zerocmux, those events are local app/socket/feed
events, not external analytics.

Network access is limited to features that require it, such as:

- update checks, if enabled
- configured agent providers
- package or framework downloads during development builds
- browser panes and user-requested web navigation
- browser imports requested by the user
- SSH/remote sessions and remote file transfer

Release builds should use a zerocmux-owned update feed or ship with automatic
update checks disabled. They should not use the upstream cmux appcast URL.

## Install

Prebuilt zerocmux releases are not published from this fork yet. Build from source with:

```bash
./scripts/setup.sh
./scripts/reload.sh --tag zerocmux
```

The built app is written to Xcode DerivedData under a tag-specific directory.

## Why zerocmux?

zerocmux is a fork of cmux with a strict zero-telemetry stance. It keeps the
core idea: a native macOS terminal workspace for running local development and
AI agent sessions side by side, with Ghostty terminal rendering, browser panes,
workspace tabs, notifications, and scriptable automation.

## Upstream background

cmux was created for developers running many Claude Code and Codex sessions in
parallel. Plain terminal splits and native macOS notifications do not provide
much context when an agent needs attention, and large tab sets become difficult
to scan.

The upstream project is a native macOS app built with Swift/AppKit and
libghostty, rather than Electron or Tauri. It reads existing Ghostty config for
themes, fonts, and colors.

The main additions are the sidebar and notification system. The sidebar has
vertical tabs that show git branch, linked PR status/number, working directory,
listening ports, and the latest notification text for each workspace. The
notification system picks up terminal sequences (OSC 9/99/777) and has a CLI
(`zerocmux notify`) you can wire into agent hooks for Claude Code, OpenCode, etc.
When an agent is waiting, its pane gets a blue ring and the tab lights up in
the sidebar. Cmd+Shift+U jumps to the most recent unread.

The in-app browser has a scriptable API ported from [agent-browser](https://github.com/vercel-labs/agent-browser). Agents can snapshot the accessibility tree, get element refs, click, fill forms, and evaluate JS. You can split a browser pane next to your terminal and have Claude Code interact with your dev server directly.

Everything is scriptable through the CLI and socket API — create workspaces/tabs, split panes, send keystrokes, open URLs in the browser.

## Upstream philosophy

zerocmux keeps the same non-prescriptive model: it is a terminal and browser
with a CLI, and the rest is up to you.

zerocmux is a primitive, not a solution. It gives you a terminal, a browser,
notifications, workspaces, splits, tabs, and a CLI to control all of it. It does
not force you into an opinionated way to use coding agents. What you build with
the primitives is yours.

The best developers have always built their own tools. Nobody has figured out the best way to work with agents yet, and the teams building closed products definitely haven't either. The developers closest to their own codebases will figure it out first.

Give a million developers composable primitives and they'll collectively find the most efficient workflows faster than any product team could design top-down.

## Documentation

Most upstream cmux concepts still apply while zerocmux preserves the old `cmux`
config paths, socket environment variables, and CLI alias as compatibility
shims. New docs and examples should use the `zerocmux` app and CLI names. Local
reference material lives in [`docs/`](docs/) and machine-readable settings
schemas live in [`docs/data/`](docs/data/).

## Keyboard Shortcuts

### Workspaces

| Shortcut | Action |
|----------|--------|
| ⌘ N | New workspace |
| ⌘ 1–8 | Jump to workspace 1–8 |
| ⌘ 9 | Jump to last workspace |
| ⌃ ⌘ ] | Next workspace |
| ⌃ ⌘ [ | Previous workspace |
| ⌘ ⇧ W | Close workspace |
| ⌘ ⇧ R | Rename workspace |
| ⌥ ⌘ E | Edit workspace description |
| ⌘ B | Toggle sidebar |
| ⌘ ⇧ E | Focus right sidebar |
| ⌃ 1 / ⌃ 2 / ⌃ 3 | Switch Files / Sessions / Feed when the right sidebar is focused |

### Surfaces

| Shortcut | Action |
|----------|--------|
| ⌘ T | New surface |
| ⌘ ⇧ ] | Next surface |
| ⌘ ⇧ [ | Previous surface |
| ⌃ Tab | Next surface |
| ⌃ ⇧ Tab | Previous surface |
| ⌃ 1–8 | Jump to surface 1–8 |
| ⌃ 9 | Jump to last surface |
| ⌘ W | Close surface |

### Split Panes

| Shortcut | Action |
|----------|--------|
| ⌘ D | Split right |
| ⌘ ⇧ D | Split down |
| ⌥ ⌘ ← → ↑ ↓ | Focus pane directionally |
| ⌘ ⇧ H | Flash focused panel |

### Browser

Browser developer-tool shortcuts follow Safari defaults and are customizable in `Settings → Keyboard Shortcuts`.
Command palette navigation shortcuts, including ⌃ P, are also customizable and can be cleared so the keypress reaches the active terminal.

| Shortcut | Action |
|----------|--------|
| ⌘ ⇧ L | Open browser in split |
| ⌘ L | Focus address bar |
| ⌘ [ | Back |
| ⌘ ] | Forward |
| ⌘ R | Reload page |
| ⌥ ⌘ I | Toggle Developer Tools (Safari default) |
| ⌥ ⌘ C | Show JavaScript Console (Safari default) |

### Notifications

| Shortcut | Action |
|----------|--------|
| ⌘ I | Show notifications panel |
| ⌘ ⇧ U | Jump to latest unread |

### Find

| Shortcut | Action |
|----------|--------|
| ⌘ F | Find |
| ⌘ G / ⌘ ⇧ G | Find next / previous |
| ⌘ ⇧ F | Hide find bar |
| ⌘ E | Use selection for find |

### Terminal

| Shortcut | Action |
|----------|--------|
| ⌘ K | Clear scrollback |
| ⌘ C | Copy (with selection) |
| ⌘ V | Paste |
| ⌘ + / ⌘ - | Increase / decrease font size |
| ⌘ 0 | Reset font size |

### Window

| Shortcut | Action |
|----------|--------|
| ⌘ ⇧ N | New window |
| ⌘ ⇧ O | Reopen previous session |
| ⌘ , | Settings |
| ⌘ ⇧ , | Reload configuration |
| ⌘ Q | Quit |

## Nightly Builds

Nightly builds are not published from this fork yet.

## Session restore

Quitting zerocmux saves the current session. On relaunch, zerocmux restores:
- Window/workspace/pane layout
- Working directories
- Terminal scrollback (best effort)
- Browser URL and navigation history
- Saved Claude Code and Codex sessions, when zerocmux has a resume token for the panel

If you need to reapply the last saved snapshot manually, use:
- `File > Reopen Previous Session`
- `⌘ ⇧ O`
- `zerocmux restore-session`

zerocmux does **not** restore arbitrary live terminal process state. tmux, vim, shells, and other tools without a zerocmux resume flow still reopen as normal terminals rather than resuming in-process state.

## Contributing

Open issues and pull requests in this fork. Keep changes scoped and preserve the
zero-telemetry guarantee.

## Community

zerocmux is independent from the upstream cmux community channels. Upstream cmux
links are left in this README only where they document inherited behavior.

## License

zerocmux is open source under [GPL-3.0-or-later](LICENSE).
