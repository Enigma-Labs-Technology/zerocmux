# Panes and Surfaces

Split layout, surface creation, focus, move, and reorder.

## Inspect

```bash
zerocmux list-panes
zerocmux list-pane-surfaces --pane pane:1
```

## Create Splits/Surfaces

```bash
zerocmux new-split right --panel pane:1
zerocmux new-surface --type terminal --pane pane:1
zerocmux new-surface --type browser --pane pane:1 --url https://example.com
```

## Focus and Close

```bash
zerocmux focus-pane --pane pane:2
zerocmux focus-panel --panel surface:7
zerocmux close-surface --surface surface:7
```

## Move/Reorder Surfaces

```bash
zerocmux move-surface --surface surface:7 --pane pane:2 --focus true
zerocmux move-surface --surface surface:7 --workspace workspace:2 --window window:1 --after surface:4
zerocmux split-off --surface surface:7 right
zerocmux reorder-surface --surface surface:7 --before surface:3
```

Surface identity is stable across move/reorder/split-off operations. Layout commands are focus-neutral by default; pass `--focus true` only when you want the moved or created surface selected.
