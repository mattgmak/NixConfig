package picker

import (
	"strings"
	"testing"

	"github.com/charmbracelet/bubbles/textinput"

	"github.com/mattgmak/agent-sesh/internal/registry"
)

func testModel(sessions []registry.Session) model {
	filter := textinput.New()
	filter.Prompt = "⚡  "
	return model{sessions: sessions, filter: filter, height: 24, width: 80}
}

func sampleSessions() []registry.Session {
	return []registry.Session{
		{
			ID:         "1",
			TmuxTarget: "%1",
			CWD:        "/Users/you/NixConfig/agent-sesh",
			Branch:     "main",
			Title:      "agent-sesh specs",
			Status:     registry.StatusWorking,
			Agent:      "pi",
		},
		{
			ID:         "2",
			TmuxTarget: "%2",
			CWD:        "/Users/you/other-project",
			Branch:     "dev",
			Title:      "other work",
			Status:     registry.StatusToolCall,
			ToolName:   "Shell: go test",
			Agent:      "pi",
		},
		{
			ID:         "3",
			TmuxTarget: "%3",
			CWD:        "/tmp",
			Title:      "idle pane",
			Status:     registry.StatusIdle,
			Agent:      "pi",
		},
	}
}

func TestFilteredSessionsNoFilter(t *testing.T) {
	m := testModel(sampleSessions())
	if got := len(m.filteredSessions()); got != 3 {
		t.Fatalf("len(filteredSessions()) = %d, want 3", got)
	}
}

func TestFilteredSessionsByTitle(t *testing.T) {
	m := testModel(sampleSessions())
	m.filter.SetValue("other")
	got := m.filteredSessions()
	if len(got) != 1 || got[0].Title != "other work" {
		t.Fatalf("filtered by title: got %+v", got)
	}
}

func TestFilteredSessionsByStatus(t *testing.T) {
	m := testModel(sampleSessions())
	m.filter.SetValue("tool_call")
	got := m.filteredSessions()
	if len(got) != 1 || got[0].Status != registry.StatusToolCall {
		t.Fatalf("filtered by status: got %+v", got)
	}
}

func TestFilteredSessionsByToolName(t *testing.T) {
	m := testModel(sampleSessions())
	m.filter.SetValue("go test")
	got := m.filteredSessions()
	if len(got) != 1 || got[0].ToolName != "Shell: go test" {
		t.Fatalf("filtered by tool name: got %+v", got)
	}
}

func TestSelected(t *testing.T) {
	m := testModel(sampleSessions())
	m.cursor = 1

	session, ok := m.selected()
	if !ok || session.Title != "other work" {
		t.Fatalf("selected() = (%+v, %v), want other work", session, ok)
	}

	m.cursor = 99
	if _, ok := m.selected(); ok {
		t.Fatal("expected no selection past end of list")
	}
}

func TestSelectedEmpty(t *testing.T) {
	m := testModel(nil)
	if _, ok := m.selected(); ok {
		t.Fatal("expected no selection for empty sessions")
	}
}

func TestStatusIcon(t *testing.T) {
	tests := []struct {
		status registry.Status
		want   string
	}{
		{registry.StatusWorking, iconWorking},
		{registry.StatusWaiting, iconWaiting},
		{registry.StatusToolCall, iconToolCall},
		{registry.StatusIdle, iconIdle},
		{registry.Status("unknown"), iconIdle},
	}

	for _, tc := range tests {
		if got := statusIcon(tc.status); got != tc.want {
			t.Errorf("statusIcon(%q) = %q, want %q", tc.status, got, tc.want)
		}
	}
}

func TestReconcileCursorKeepsSelectionByID(t *testing.T) {
	m := testModel(sampleSessions())
	m.cursor = 1
	m.selectedID = "2"

	m.sessions = []registry.Session{
		m.sessions[2],
		m.sessions[0],
		m.sessions[1],
	}

	m.reconcileCursor()
	if m.cursor != 2 {
		t.Fatalf("cursor = %d, want 2 (session id 2)", m.cursor)
	}
	if m.selectedID != "2" {
		t.Fatalf("selectedID = %q, want %q", m.selectedID, "2")
	}
}

func TestShortCWD(t *testing.T) {
	tests := []struct {
		in   string
		want string
	}{
		{"/Users/you/proj", "/Users/you/proj"},
		{"/a/b/c/d/e", ".../c/d/e"},
		{"", ""},
		{"/one", "/one"},
	}

	for _, tc := range tests {
		if got := shortCWD(tc.in); got != tc.want {
			t.Errorf("shortCWD(%q) = %q, want %q", tc.in, got, tc.want)
		}
	}
}

func TestReloadQuitsWhenSessionsEmpty(t *testing.T) {
	m := testModel(sampleSessions())
	m.registry = t.TempDir() + "/missing.json"
	m.sessions = nil
	m = m.reload()
	if !m.quitting {
		t.Fatal("expected reload with no sessions to mark quitting")
	}
}

func TestViewShowsSessionsInSplitMode(t *testing.T) {
	m := testModel(sampleSessions())
	m.width = 120
	m.height = 24
	m.syncInputWidth()

	out := m.View()
	if !strings.Contains(out, "agent-sesh specs") {
		t.Fatalf("expected session title in split view, got:\n%s", out)
	}
}

func TestPreviewLoadingOnlyBeforeFirstFetch(t *testing.T) {
	m := testModel(sampleSessions())
	m.width = 120
	m.height = 24
	m.syncInputWidth()

	out := m.View()
	if !strings.Contains(out, "Loading preview") {
		t.Fatalf("expected loading before first preview, got:\n%s", out)
	}

	m.previewName = "1"
	m.previewContent = "\x1b[31mcolored\x1b[0m"
	m.previewPending = "2"

	out = m.View()
	if strings.Contains(out, "Loading preview") {
		t.Fatalf("expected previous preview while pending fetch, got:\n%s", out)
	}
	if !strings.Contains(out, "\x1b[31m") {
		t.Fatalf("expected colored preview content, got:\n%s", out)
	}
}

func TestBottomAlignedCursorMovesUpToOlderSession(t *testing.T) {
	m := testModel(sampleSessions())
	m.width = 80
	m.height = 24
	m.cursor = 0
	m.selectedID = "1"
	m.reconcileCursor()

	before := m.View()
	m = m.setCursor(m.cursor + 1)
	after := m.View()

	session, ok := m.selected()
	if !ok || session.ID != "2" {
		t.Fatalf("up should move to older session, got %+v", session)
	}
	if before == after {
		t.Fatal("expected cursor move to change rendered view")
	}
}

func TestHeaderViewUsesFilterByDefault(t *testing.T) {
	m := testModel(sampleSessions())
	if !strings.Contains(m.headerView(), "⚡") {
		t.Fatalf("expected sesh-style prompt in header, got %q", m.headerView())
	}
}

func TestHeaderViewUsesRenameInRenameMode(t *testing.T) {
	m := testModel(sampleSessions())
	m.mode = modeRename
	m.rename = textinput.New()
	m.rename.Prompt = iconRename + " "
	if !strings.Contains(m.headerView(), iconRename) {
		t.Fatalf("expected rename prompt, got %q", m.headerView())
	}
}
