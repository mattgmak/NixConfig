package picker

import (
	"os"
	"strings"

	"charm.land/lipgloss/v2"
	"charm.land/lipgloss/v2/compat"
	"github.com/charmbracelet/colorprofile"

	"github.com/mattgmak/agent-sesh/internal/registry"
)

var (
	cursorStyle = lipgloss.NewStyle().Foreground(lipgloss.ANSIColor(2)).Bold(true)
	matchStyle  = lipgloss.NewStyle().Foreground(lipgloss.ANSIColor(1)).Bold(true)
	normalStyle = lipgloss.NewStyle()
	dimStyle    = lipgloss.NewStyle().Foreground(lipgloss.ANSIColor(8)).Faint(true)
	branchStyle = lipgloss.NewStyle().Foreground(lipgloss.ANSIColor(14)).Bold(true)
	toolStyle   = lipgloss.NewStyle().Foreground(lipgloss.ANSIColor(5)).Bold(true)
	mutedStyle  = lipgloss.NewStyle().Foreground(lipgloss.ANSIColor(8)).Faint(true)
	faintStyle  = lipgloss.NewStyle().Faint(true)
	borderStyle = lipgloss.NewStyle().Foreground(lipgloss.ANSIColor(8))
)

func initTerminalColors() {
	profile := detectColorProfile()
	compat.Profile = profile
	lipgloss.Writer.Profile = profile
}

func detectColorProfile() colorprofile.Profile {
	if os.Getenv("NO_COLOR") != "" {
		return colorprofile.Ascii
	}
	if forced, ok := colorProfileFromEnv(); ok {
		return forced
	}
	return colorprofile.Detect(os.Stdout, os.Environ())
}

func colorProfileFromEnv() (colorprofile.Profile, bool) {
	term := os.Getenv("TERM")
	colorTerm := strings.ToLower(os.Getenv("COLORTERM"))
	switch {
	case colorTerm == "truecolor" || colorTerm == "24bit":
		return colorprofile.TrueColor, true
	case strings.Contains(term, "256color"):
		return colorprofile.ANSI256, true
	case strings.Contains(term, "color"), strings.Contains(term, "ansi"):
		return colorprofile.ANSI, true
	default:
		return colorprofile.Ascii, false
	}
}

func statusLabelStyle(status registry.Status) lipgloss.Style {
	switch status {
	case registry.StatusWorking:
		return lipgloss.NewStyle().Foreground(lipgloss.ANSIColor(2)).Bold(true)
	case registry.StatusWaiting:
		return lipgloss.NewStyle().Foreground(lipgloss.ANSIColor(3))
	case registry.StatusToolCall:
		return lipgloss.NewStyle().Foreground(lipgloss.ANSIColor(5)).Bold(true)
	default:
		return lipgloss.NewStyle().Foreground(lipgloss.ANSIColor(8))
	}
}
