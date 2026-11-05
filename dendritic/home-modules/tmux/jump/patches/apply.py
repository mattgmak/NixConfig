#!/usr/bin/env python3
"""tmux-jump patch: enter copy-mode before capture-pane.

Upstream 0.5.5 captures the pane, opens the popup, and only then enters
copy-mode. The popup costs 50 to 200 ms, and any output that arrives in that
window scrolls the pane, so the captured rows no longer match the rows the
copy-mode cursor moves over. Copy-mode freezes the viewport, so entering it
first keeps the capture and the cursor on the same rows.
"""

from __future__ import annotations

import pathlib
import sys

COPY_MODE = """if [ "$in_copy" != 1 ]; then
\ttmux copy-mode -t "$pane" 2>/dev/null || exit 0
\tentered_copy=1
fi"""

LATE = f"""
{COPY_MODE}
tmux send-keys -t "$pane" -X top-line 2>/dev/null || exit 0
"""
LATE_FIXED = """
tmux send-keys -t "$pane" -X top-line 2>/dev/null || exit 0
"""
EARLY = """cap="$tmpdir/cap"
res="$tmpdir/res"
"""
EARLY_FIXED = f"""cap="$tmpdir/cap"
res="$tmpdir/res"

{COPY_MODE}
"""


def patch(path: pathlib.Path) -> None:
    text = path.read_text()
    if EARLY_FIXED in text and LATE not in text:
        return
    if LATE not in text or EARLY not in text:
        raise SystemExit(f"copy-mode move patch: pattern not found in {path}")
    text = text.replace(LATE, LATE_FIXED, 1)
    path.write_text(text.replace(EARLY, EARLY_FIXED, 1))


if __name__ == "__main__":
    patch(pathlib.Path(sys.argv[1]))
