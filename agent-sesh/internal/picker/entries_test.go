package picker

import (
	"strings"
	"testing"

	"github.com/mattgmak/agent-sesh/internal/registry"
)

func TestFormatSessionEntryLimitsLongPrompt(t *testing.T) {
	long := strings.Repeat("word ", 40)
	session := registry.Session{
		TmuxSession: "demo",
		LastPrompt:  long,
		Status:      registry.StatusWorking,
		Agent:       "pi",
	}

	lines := formatSessionEntry(session, 40)
	if len(lines) > 1+maxPromptLines {
		t.Fatalf("expected at most %d prompt lines, got %d lines total: %q", maxPromptLines, len(lines), lines)
	}
	promptSection := strings.Join(lines[1:], "\n")
	if !strings.Contains(promptSection, "…") {
		t.Fatalf("expected truncated prompt to end with ellipsis, got %q", promptSection)
	}
}

func TestLimitRunes(t *testing.T) {
	if got := limitRunes("hello", 10); got != "hello" {
		t.Fatalf("limitRunes() = %q, want hello", got)
	}
	if got := limitRunes("hello world", 6); got != "hello…" {
		t.Fatalf("limitRunes() = %q, want hello…", got)
	}
}
