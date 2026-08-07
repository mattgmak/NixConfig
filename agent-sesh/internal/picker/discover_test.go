package picker

import (
	"strings"
	"testing"

	"github.com/mattgmak/agent-sesh/internal/registry"
)

func TestSessionPaneLabel(t *testing.T) {
	session := registry.Session{
		TmuxWindow: "2",
		TmuxPane:   "1",
	}
	if got := sessionPaneLabel(session); got != "2.1" {
		t.Fatalf("sessionPaneLabel() = %q, want 2.1", got)
	}
}

func TestMergeDiscoveredSessionsKeepsRegistered(t *testing.T) {
	t.Setenv("AGENT_SESH_DISABLE_DISCOVER", "1")
	registered := []registry.Session{
		{ID: "a", TmuxTarget: "%1", Agent: "pi"},
	}
	got := mergeDiscoveredSessions(registered)
	if len(got) != 1 || got[0].ID != "a" {
		t.Fatalf("mergeDiscoveredSessions() = %+v", got)
	}
}

func TestFormatSessionLineIncludesPane(t *testing.T) {
	t.Setenv("AGENT_SESH_DISABLE_DISCOVER", "1")
	session := registry.Session{
		ID:          "1",
		TmuxTarget:  "%1",
		TmuxSession: "nixconfig",
		TmuxWindow:  "1",
		TmuxPane:    "2",
		LastPrompt:  "fix multi-pane picker",
		Agent:       "pi",
		Status:      registry.StatusWorking,
	}
	line := formatSessionLine(session, 120)
	if !strings.Contains(line, iconPane) || !strings.Contains(line, "1.2") {
		t.Fatalf("expected pane label in line, got %q", line)
	}
}
