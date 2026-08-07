package picker

import (
	"strings"
	"testing"

	"charm.land/lipgloss/v2/compat"
	"github.com/charmbracelet/colorprofile"
)

func TestFormatSessionLineHasColorWhenProfileSet(t *testing.T) {
	compat.Profile = colorprofile.ANSI256
	t.Cleanup(func() { compat.Profile = colorprofile.Ascii })

	s := sampleSessions()[0]
	line := formatSessionLine(s, 80)
	if !strings.Contains(line, "\x1b[") {
		t.Fatalf("expected ANSI color escapes with ANSI256 profile, got %q", line)
	}
}

func TestFormatSessionLineIncludesToolOnFirstLine(t *testing.T) {
	compat.Profile = colorprofile.ANSI256
	t.Cleanup(func() { compat.Profile = colorprofile.Ascii })

	s := sampleSessions()[1]
	line := formatSessionLine(s, 120)
	lines := strings.Split(line, "\n")
	if len(lines) < 2 {
		t.Fatalf("expected multiline tool_call entry, got %q", line)
	}
	if !strings.Contains(lines[0], "go test") {
		t.Fatalf("expected tool name on first line, got %q", lines[0])
	}
}

func TestRenderPreviewPanePreservesANSI(t *testing.T) {
	compat.Profile = colorprofile.ANSI256
	t.Cleanup(func() { compat.Profile = colorprofile.Ascii })

	body := "\x1b[31mred\x1b[0m\nplain"
	out := renderPreviewPane(body, 40, 5, nil, false)
	if !strings.Contains(out, "\x1b[31m") {
		t.Fatalf("expected preview pane to preserve ANSI, got %q", out)
	}
}

func TestRenderPreviewPanePreservesMultilineANSI(t *testing.T) {
	compat.Profile = colorprofile.Ascii
	t.Cleanup(func() { compat.Profile = colorprofile.Ascii })

	body := "line1\n\x1b[32mgreen\x1b[0m\nline3"
	out := renderPreviewPane(body, 40, 5, nil, false)
	if strings.Count(out, "\n") < 2 {
		t.Fatalf("expected multiline preview output, got %q", out)
	}
	if !strings.Contains(out, "\x1b[32m") {
		t.Fatalf("expected embedded ANSI preserved across lines, got %q", out)
	}
}
