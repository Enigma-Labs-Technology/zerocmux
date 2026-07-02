# zerocmux Workspace Command Reference

Use these commands from a zerocmux terminal. Most commands infer the caller workspace from `CMUX_WORKSPACE_ID`, but explicit flags are safer for automation.

## Context

```bash
zerocmux identify --json
zerocmux current-workspace --json
zerocmux capabilities --json
zerocmux ping
```

## Windows and Workspaces

```bash
zerocmux list-windows
zerocmux current-window
zerocmux new-window
zerocmux focus-window --window window:2
zerocmux close-window --window window:2

zerocmux list-workspaces
zerocmux list-workspaces --json
zerocmux new-workspace --name "task" --cwd "$PWD"
zerocmux new-workspace --command "npm run dev"
zerocmux new-workspace --layout '{"root":{"type":"terminal"}}'
zerocmux current-workspace
zerocmux select-workspace --workspace workspace:2
zerocmux rename-workspace --workspace workspace:2 -- "new name"
zerocmux close-workspace --workspace workspace:2
zerocmux reorder-workspace --workspace workspace:4 --before workspace:2
zerocmux move-workspace-to-window --workspace workspace:4 --window window:1
```

## Panes and Surfaces

```bash
zerocmux list-panes --workspace "$CMUX_WORKSPACE_ID"
zerocmux list-pane-surfaces --workspace "$CMUX_WORKSPACE_ID" --pane pane:1
zerocmux list-panels --workspace "$CMUX_WORKSPACE_ID"
zerocmux tree --workspace "$CMUX_WORKSPACE_ID"

zerocmux new-split right --workspace "$CMUX_WORKSPACE_ID"
zerocmux new-split down --workspace "$CMUX_WORKSPACE_ID" --surface "$CMUX_SURFACE_ID"
zerocmux new-pane --workspace "$CMUX_WORKSPACE_ID" --type terminal --direction right
zerocmux new-pane --workspace "$CMUX_WORKSPACE_ID" --type browser --url http://localhost:3000
zerocmux new-surface --workspace "$CMUX_WORKSPACE_ID" --type terminal --pane pane:1
zerocmux new-surface --workspace "$CMUX_WORKSPACE_ID" --type browser --pane pane:1 --url http://localhost:3000

zerocmux focus-pane --workspace "$CMUX_WORKSPACE_ID" --pane pane:2
zerocmux focus-panel --workspace "$CMUX_WORKSPACE_ID" --panel surface:3
zerocmux close-surface --workspace "$CMUX_WORKSPACE_ID" --surface surface:3
zerocmux move-surface --surface surface:7 --pane pane:2 --focus true
zerocmux reorder-surface --surface surface:7 --before surface:3
zerocmux move-tab-to-new-workspace --surface surface:7 --title "browser"
```

## Input

```bash
zerocmux send "echo hello\n"
zerocmux send-key enter
zerocmux send --surface "$CMUX_SURFACE_ID" "git status\n"
zerocmux send-key --surface "$CMUX_SURFACE_ID" enter
zerocmux read-screen --surface "$CMUX_SURFACE_ID"
```

## Sidebar Metadata

```bash
zerocmux set-status build "running" --workspace "$CMUX_WORKSPACE_ID" --icon hammer --color "#ff9500"
zerocmux clear-status build --workspace "$CMUX_WORKSPACE_ID"
zerocmux list-status --workspace "$CMUX_WORKSPACE_ID"
zerocmux set-progress 0.5 --workspace "$CMUX_WORKSPACE_ID" --label "Building"
zerocmux clear-progress --workspace "$CMUX_WORKSPACE_ID"
zerocmux log --workspace "$CMUX_WORKSPACE_ID" --level info -- "Build started"
zerocmux list-log --workspace "$CMUX_WORKSPACE_ID" --limit 20
zerocmux clear-log --workspace "$CMUX_WORKSPACE_ID"
zerocmux sidebar-state --workspace "$CMUX_WORKSPACE_ID" --json
```

## Notifications and Attention

```bash
zerocmux notify --title "Done" --body "Task complete"
zerocmux list-notifications --json
zerocmux clear-notifications
zerocmux trigger-flash --workspace "$CMUX_WORKSPACE_ID" --surface "$CMUX_SURFACE_ID"
zerocmux surface-health --workspace "$CMUX_WORKSPACE_ID" --json
```

## Config and Docs

```bash
zerocmux docs api
zerocmux docs browser
zerocmux docs settings
zerocmux settings path
zerocmux settings zerocmux-json
zerocmux settings shortcuts
zerocmux reload-config
```

## Tagged Reloads

```bash
./scripts/reload.sh --tag <short-tag>
CMUX_SOCKET_PATH=/tmp/zerocmux-debug-<short-tag>.sock zerocmux identify --json
```
