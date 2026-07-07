#!/bin/sh
# Empirical probe: tmux no-client behavior for z-window.sh test design.
# Q1: From OUTSIDE tmux (no attached client), does `display-message -p '#{pane_current_path}'`
#     (NO -t target) resolve a current pane, or return empty?
# Q2: Does `new-window -t session: -c dir -n name` work without a client?
# Q3: Can we assert the new window's cwd/name via `display-message -t <win> -p ...`?

set -u
REAL_TMUX=/usr/bin/tmux
SOCK=zxstest_probe

"$REAL_TMUX" -L "$SOCK" kill-server 2>/dev/null || true
sleep 0.3

WORKDIR=$(mktemp -d)
RESOLVEDDIR=$(mktemp -d)

# Detached session: NO attached client (mirrors how the test invokes z-window.sh).
"$REAL_TMUX" -L "$SOCK" new-session -d -s zs -c "$WORKDIR"
echo "[setup] new-session exit=$? WORKDIR=$WORKDIR RESOLVEDDIR=$RESOLVEDDIR"

echo ""
echo "=== Q1a: pane_current_path (NO -t, no client) ==="
out=$("$REAL_TMUX" -L "$SOCK" display-message -p '#{pane_current_path}' 2>&1)
echo "got=[$out]  exit=$?"

echo ""
echo "=== Q1b: session_name (NO -t, no client) ==="
out=$("$REAL_TMUX" -L "$SOCK" display-message -p '#{session_name}' 2>&1)
echo "got=[$out]  exit=$?"

echo ""
echo "=== Q2: new-window -t zs: -c RESOLVEDDIR -n basename (no client) ==="
"$REAL_TMUX" -L "$SOCK" new-window -t zs: -c "$RESOLVEDDIR" -n "$(basename "$RESOLVEDDIR")"
echo "new-window exit=$?"

echo ""
echo "=== Q3: assert new window via list-windows -F ==="
"$REAL_TMUX" -L "$SOCK" list-windows -t zs: -F 'idx=#{window_index} name=#{window_name} cwd=#{pane_current_path}'

echo ""
echo "=== Q3b: capture newest window id, assert via display-message -t <id> ==="
# newest window = highest index
WINID=$("$REAL_TMUX" -L "$SOCK" list-windows -t zs: -F '#{window_id}' -f '#{window_index}:>' | tail -1)
echo "WINID=$WINID"
echo "cwd  via -t WINID: [$("$REAL_TMUX" -L "$SOCK" display-message -t "$WINID" -p '#{pane_current_path}')]"
echo "name via -t WINID: [$("$REAL_TMUX" -L "$SOCK" display-message -t "$WINID" -p '#{window_name}')]"

echo ""
echo "=== Q4: spaced query recombination sanity (shell, not tmux) ==="
set -- proj ect extra
echo "args(\$*)=[$*]"
echo "basename of RESOLVEDDIR=[$(basename "$RESOLVEDDIR")]"

# cleanup
"$REAL_TMUX" -L "$SOCK" kill-server 2>/dev/null || true
rm -rf "$WORKDIR" "$RESOLVEDDIR"
echo ""
echo "[done]"
