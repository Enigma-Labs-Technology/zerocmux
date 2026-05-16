# Windows and Workspaces

Window/workspace lifecycle and ordering operations.

## Inspect

```bash
zerocmux list-windows
zerocmux current-window
zerocmux list-workspaces
zerocmux current-workspace
```

## Create/Focus/Close

```bash
zerocmux new-window
zerocmux focus-window --window window:2
zerocmux close-window --window window:2

zerocmux new-workspace
zerocmux select-workspace --workspace workspace:4
zerocmux close-workspace --workspace workspace:4
```

## Reorder and Move

```bash
zerocmux reorder-workspace --workspace workspace:4 --before workspace:2
zerocmux move-workspace-to-window --workspace workspace:4 --window window:1
```
