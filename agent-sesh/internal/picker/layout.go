package picker

import (
	"strings"

	"github.com/charmbracelet/lipgloss"

	"github.com/mattgmak/agent-sesh/internal/registry"
)

const (
	headerLines          = 2
	fallbackVisibleCount = 5
	maxListWidth         = 60
	minListWidth         = 40
	previewPadding       = 1
	previewWidthPct      = 55
	previewMinWidth      = 100
)

func visibleCount(height int) int {
	available := height - headerLines
	if available < 1 {
		return fallbackVisibleCount
	}
	return available
}

func previewChrome() int {
	return previewPadding + 1
}

func previewCols(width int, split bool) int {
	if !split || width < previewMinWidth {
		return 0
	}
	cols := width * previewWidthPct / 100
	if rest := width - maxListWidth; rest > cols {
		cols = rest
	}
	if max := width - minListWidth; cols > max {
		cols = max
	}
	if cols <= previewChrome() {
		return 0
	}
	return cols
}

func listCols(width int, split bool) int {
	w := width
	if split {
		w = width - previewCols(width, true)
	}
	if w < minListWidth {
		w = minListWidth
	}
	if w > maxListWidth {
		w = maxListWidth
	}
	return w
}

func listWindow(cursor, offset, itemCount, visible int) (newOffset, end int) {
	if itemCount == 0 {
		return 0, 0
	}
	if cursor >= itemCount {
		cursor = itemCount - 1
	}
	if cursor < offset {
		offset = cursor
	}
	if cursor >= offset+visible {
		offset = cursor - visible + 1
	}
	end = offset + visible
	if end > itemCount {
		end = itemCount
	}
	return offset, end
}

type listRenderOpts struct {
	showCursor bool
	emptyText  string
}

func truncateLine(line string, width int) string {
	if width < 1 {
		return ""
	}
	if lipgloss.Width(line) <= width {
		return line
	}
	return lipgloss.NewStyle().MaxWidth(width).Render(line)
}

func renderListFrame(
	items []registry.Session,
	cursor int,
	offset int,
	visible int,
	lineWidth int,
	opts listRenderOpts,
	renderLine func(session registry.Session, width int) string,
) string {
	if visible < 1 {
		return ""
	}

	lines := make([]string, 0, visible)

	if len(items) == 0 {
		empty := opts.emptyText
		if empty == "" {
			empty = "  (no sessions)"
		}
		lines = append(lines, empty)
		for len(lines) < visible {
			lines = append(lines, "")
		}
		return strings.Join(lines, "\n")
	}

	_, end := listWindow(cursor, offset, len(items), visible)
	shown := end - offset
	padTop := visible - shown

	for i := 0; i < padTop; i++ {
		lines = append(lines, "")
	}

	// Bottom-aligned: oldest row higher on screen, newest nearest the bottom.
	for i := end - 1; i >= offset; i-- {
		prefix := "  "
		if opts.showCursor && i == cursor {
			prefix = cursorStyle.Render("> ")
		}
		body := renderLine(items[i], lineWidth-lipgloss.Width(prefix))
		lines = append(lines, prefix+body)
	}

	for len(lines) < visible {
		lines = append(lines, "")
	}
	if len(lines) > visible {
		lines = lines[:visible]
	}
	return strings.Join(lines, "\n")
}

func clipLines(text string, width, rows int) string {
	return clipLinesRange(text, width, rows, false)
}

func clipLinesTail(text string, width, rows int) string {
	return clipLinesRange(text, width, rows, true)
}

func clipLinesRange(text string, width, rows int, tail bool) string {
	if width < 1 || rows < 1 {
		return ""
	}

	lines := strings.Split(strings.ReplaceAll(text, "\r\n", "\n"), "\n")
	if len(lines) > rows {
		if tail {
			lines = lines[len(lines)-rows:]
		} else {
			lines = lines[:rows]
		}
	}

	clip := lipgloss.NewStyle().MaxWidth(width)
	for i, line := range lines {
		line = clip.Render(line)
		if strings.Contains(line, "\x1b") && !strings.HasSuffix(line, "\x1b[0m") {
			line += "\x1b[0m"
		}
		lines[i] = line
	}
	return strings.Join(lines, "\n")
}

func padFrame(content string, height int) string {
	if height < 1 {
		return content
	}
	lines := strings.Split(strings.TrimSuffix(content, "\n"), "\n")
	for len(lines) < height {
		lines = append(lines, "")
	}
	if len(lines) > height {
		lines = lines[:height]
	}
	return strings.Join(lines, "\n")
}

func renderPreviewPane(content string, cols, rows int, previewErr error, loading bool) string {
	faint := lipgloss.NewStyle().Faint(true)

	var body string
	switch {
	case previewErr != nil:
		body = faint.Render("Preview unavailable: " + previewErr.Error())
	case loading:
		body = faint.Render("Loading preview...")
	case strings.TrimSpace(content) == "":
		body = faint.Render("No preview")
	default:
		body = content
	}

	body = clipLinesTail(body, cols-previewChrome(), rows)

	return lipgloss.NewStyle().
		Border(lipgloss.NormalBorder(), false, false, false, true).
		BorderForeground(lipgloss.Color("8")).
		PaddingLeft(previewPadding).
		PaddingTop(headerLines).
		Width(cols).
		Height(headerLines + rows).
		Render(body)
}
