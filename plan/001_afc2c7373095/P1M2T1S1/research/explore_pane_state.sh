#!/bin/sh
# Deeper probe: WHY does #{pane_current_path} show server cwd instead of -c dir?
# Hypothesis: in this headless sandbox the pane's default-shell doesn't start a live
# process, so pane_current_path falls back to the tmux SERVER's cwd. If a real shell
# runs, /proc/<pid>/cwd should reflect the -c dir.
set -u
REAL_TMUX=/usr/bin/tmux
SOCK=zxstest_probe2
"$REAL_TMUX" -L "$SOCK" kill-server 2>/dev/null || true
sleep 0.3

WORKDIR=$(mktemp -d)
echo "WORKDIR=$WORKDIR"

"$REAL_TMUX" -L "$SOCK" new-session -d -s zs -c "$WORKDIR"
echo "new-session exit=$?"

echo ""
echo "=== pane state ==="
"$REAL_TMUX" -L "$SOCK" list-panes -t zs: -F 'pid=#{pane_pid} dead=#{pane_dead} dead_status=#{pane_dead_status} cmd=#{pane_current_command} cwd=#{pane_current_path} start=#{pane_start_path}'

echo ""
echo "=== /proc/<pid>/cwd of the pane process ==="
PID=$("$REAL_TMUX" -L "$SOCK" list-panes -t zs: -F '#{pane_pid}' | head -1)
echo "pane_pid=$PID"
if [ -n "$PID" ] && [ -e "/proc/$PID/cwd" ]; then
    echo "/proc/$PID/cwd -> $(readlink "/proc/$PID/cwd" 2>&1)"
else
    echo "no /proc/$PID/cwd (pid empty or gone)"
fi

echo ""
echo "=== is the shell alive? send-keys pwd, capture pane text ==="
"$REAL_TMUX" -L "$SOCK" send-keys -t zs: 'pwd' Enter
sleep 0.5
"$REAL_TMUX" -L "$SOCK" capture-pane -t zs: -p | tail -5

echo ""
echo "=== now new-window -c to a SECOND dir, with -P to capture window id ==="
RESOLVEDDIR=$(mktemp -d)
echo "RESOLVEDDIR=$RESOLVEDDIR"
"$REAL_TMUX" -L "$SOCK" new-window -t zs: -d -c "$RESOLVEDDIR" -n "$(basename "$RESOLVEDDIR")"
# find the window by name
WIN=$("$REAL_TMUX" -L "$SOCK" list-windows -t zs: -F '#{window_index}:#{window_name}' | grep ":$(basename "$RESOLVEDDIR")$" | cut -d: -f1)
echo "new win index=$WIN"
sleep 0.3
echo "new-window pane cwd: [$("$REAL_TMUX" -L "$SOCK" display-message -t "zs:$WIN" -p '#{pane_current_path}')]"
NPID=$("$REAL_TMUX" -L "$SOCK" list-panes -t "zs:$WIN" -F '#{pane_pid}' | head -1)
echo "new pane pid=$NPID  /proc/cwd -> $(readlink "/proc/$NPID/cwd" 2>&1)"

echo ""
echo "=== KEY TEST: does new-window -c reflect in pane_start_path? ==="
"$REAL_TMUX" -L "$SOCK" list-windows -t zs: -F 'idx=#{window_index} name=#{window_name} start=#{pane_start_path} cwd=#{pane_current_path}'

"$REAL_TMUX" -L "$SOCK" kill-server 2>/dev/null || true
rm -rf "$WORKDIR" "$RESOLVEDDIR"
echo "[done]"
