package picker

import (
	"strings"

	"github.com/charmbracelet/x/ansi"
)

// truncateANSI shortens visible width without stripping embedded SGR sequences.
func truncateANSI(line string, width int) string {
	if width < 1 {
		return ""
	}
	if ansi.StringWidth(line) <= width {
		return line
	}
	return ansi.Truncate(line, width, "")
}

// wrapANSI soft-wraps a line to width, preserving embedded SGR sequences.
func wrapANSI(line string, width int) []string {
	if width < 1 {
		return []string{ensureResetSuffix(line)}
	}
	if ansi.StringWidth(line) <= width {
		return []string{ensureResetSuffix(line)}
	}
	wrapped := ansi.Wrap(line, width, " \t")
	if wrapped == "" {
		return nil
	}
	lines := strings.Split(wrapped, "\n")
	for i, part := range lines {
		lines[i] = ensureResetSuffix(part)
	}
	return lines
}

// ensureResetSuffix keeps capture-pane colors from bleeding into chrome.
func ensureResetSuffix(line string) string {
	if strings.Contains(line, "\x1b") && !strings.HasSuffix(line, "\x1b[0m") {
		return line + "\x1b[0m"
	}
	return line
}
