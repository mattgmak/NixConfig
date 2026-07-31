package picker

import (
	"fmt"
	"strings"
	"testing"

	"github.com/charmbracelet/lipgloss"
)

func TestVisibleCount(t *testing.T) {
	if got := visibleCount(24); got != 22 {
		t.Fatalf("visibleCount(24) = %d, want 22", got)
	}
	if got := visibleCount(1); got != fallbackVisibleCount {
		t.Fatalf("visibleCount(1) = %d, want fallback %d", got, fallbackVisibleCount)
	}
}

func TestRenderListFrameBottomAligned(t *testing.T) {
	items := sampleSessions()
	visible := 6
	out := renderListFrame(items, 0, 0, visible, 58, listRenderOpts{showCursor: true}, formatSessionLine)
	lines := strings.Split(out, "\n")
	if len(lines) != visible {
		t.Fatalf("got %d lines, want %d", len(lines), visible)
	}
	if lines[0] != "" || lines[1] != "" || lines[2] != "" {
		t.Fatalf("expected top padding, got %#v", lines[:3])
	}
	if !strings.Contains(lines[visible-1], "agent-sesh specs") {
		t.Fatalf("newest session should sit on bottom line, got %q", lines[visible-1])
	}
	if !strings.Contains(lines[visible-3], "idle pane") {
		t.Fatalf("oldest session should sit above newer ones, got %q", lines[visible-3])
	}
}

func TestRenderListFrameFixedHeightWhenScrolling(t *testing.T) {
	items := sampleSessions()
	visible := 2
	out := renderListFrame(items, 2, 1, visible, 58, listRenderOpts{showCursor: true}, formatSessionLine)
	if strings.Count(out, "\n")+1 != visible {
		t.Fatalf("expected exactly %d lines, got:\n%s", visible, out)
	}
}

func TestClipLinesKeepsHead(t *testing.T) {
	in := strings.Join([]string{"one", "two", "three", "four"}, "\n")
	got := clipLines(in, 80, 2)
	want := "one\ntwo"
	if got != want {
		t.Fatalf("clipLines() = %q, want %q", got, want)
	}
}

func TestClipLinesPreservesANSI(t *testing.T) {
	in := "\x1b[31mred\x1b[0m\nplain"
	got := clipLines(in, 80, 2)
	lines := strings.Split(got, "\n")
	if len(lines) != 2 {
		t.Fatalf("expected 2 lines, got %d: %q", len(lines), got)
	}
	if !strings.Contains(lines[0], "\x1b[31m") {
		t.Fatalf("expected ansi preserved, got %q", lines[0])
	}
	if !strings.HasSuffix(lines[0], "\x1b[0m") {
		t.Fatalf("expected reset suffix on colored line, got %q", lines[0])
	}
}

func TestClipLinesTailKeepsBottom(t *testing.T) {
	in := strings.Join([]string{"one", "two", "three", "four"}, "\n")
	got := clipLinesTail(in, 80, 2)
	want := "three\nfour"
	if got != want {
		t.Fatalf("clipLinesTail() = %q, want %q", got, want)
	}
}

func TestTruncateLineDoesNotWrap(t *testing.T) {
	long := strings.Repeat("x", 120)
	got := truncateLine(long, 20)
	if strings.Count(got, "\n") > 0 {
		t.Fatalf("truncateLine wrapped: %q", got)
	}
	if lipgloss.Width(got) > 20 {
		t.Fatalf("truncateLine width = %d, want <= 20", lipgloss.Width(got))
	}
}

func TestPadFrame(t *testing.T) {
	got := padFrame("a\nb", 4)
	lines := strings.Split(got, "\n")
	if len(lines) != 4 {
		t.Fatalf("len(lines) = %d, want 4", len(lines))
	}
	if lines[2] != "" || lines[3] != "" {
		t.Fatalf("expected trailing padding, got %#v", lines)
	}
}

func TestViewFillsTerminalHeight(t *testing.T) {
	for _, height := range []int{10, 24, 50} {
		t.Run(fmt.Sprintf("height-%d", height), func(t *testing.T) {
			m := testModel(sampleSessions())
			m.width = 120
			m.height = height
			m.syncInputWidth()

			lines := strings.Split(m.View(), "\n")
			if len(lines) != height {
				t.Fatalf("frame height = %d, want %d", len(lines), height)
			}
		})
	}
}

func TestViewStableOnCursorMove(t *testing.T) {
	m := testModel(sampleSessions())
	m.width = 120
	m.height = 24
	m.syncInputWidth()

	before := strings.Split(m.View(), "\n")
	m = m.setCursor(1)
	after := strings.Split(m.View(), "\n")
	if len(before) != len(after) {
		t.Fatalf("cursor move changed frame height: %d -> %d", len(before), len(after))
	}
}

func TestViewNoPreviewWithoutSessions(t *testing.T) {
	m := testModel(nil)
	m.width = 120
	m.height = 24
	out := m.View()
	if strings.Contains(out, "│") {
		t.Fatalf("did not expect preview divider without sessions, got:\n%s", out)
	}
}

func TestSplitActiveRequiresSessions(t *testing.T) {
	m := testModel(nil)
	m.width = 120
	if m.splitActive() {
		t.Fatal("split should be inactive with no sessions")
	}
	m.sessions = sampleSessions()
	if !m.splitActive() {
		t.Fatal("split should be active when sessions exist")
	}
}
