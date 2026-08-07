package picker

import (
	"testing"

	"github.com/mattgmak/agent-sesh/internal/registry"
)

func TestPreviewCacheRoundTrip(t *testing.T) {
	target := "%test-preview-cache"
	rev := "working\x00Shell\x002026-01-01T00:00:00Z"
	invalidatePreviewCache(target)

	if _, _, ok := getPreviewCache(target, rev); ok {
		t.Fatal("expected empty cache")
	}

	setPreviewCache(target, rev, "hello", nil)
	content, err, ok := getPreviewCache(target, rev)
	if !ok || content != "hello" || err != nil {
		t.Fatalf("cache miss: ok=%v content=%q err=%v", ok, content, err)
	}
}

func TestPreviewCacheRevisionMismatch(t *testing.T) {
	target := "%test-preview-rev"
	invalidatePreviewCache(target)

	setPreviewCache(target, "idle\x00\x00", "old", nil)
	if _, _, ok := getPreviewCache(target, "working\x00Shell\x00"); ok {
		t.Fatal("expected revision mismatch to miss cache")
	}
}

func TestPreviewRevision(t *testing.T) {
	session := registry.Session{
		Status:    registry.StatusToolCall,
		ToolName:  "Read",
		UpdatedAt: "2026-01-02T12:00:00Z",
	}
	got := previewRevision(session)
	want := string(registry.StatusToolCall) + "\x00Read\x002026-01-02T12:00:00Z"
	if got != want {
		t.Fatalf("previewRevision() = %q, want %q", got, want)
	}
}

func TestSchedulePreviewUsesCacheWithoutFetch(t *testing.T) {
	m := testModel(sampleSessions())
	m.width = 120
	m.height = 24
	m.syncInputWidth()

	session := sampleSessions()[0]
	rev := previewRevision(session)
	setPreviewCache(session.TmuxTarget, rev, "cached pane", nil)

	cmd := (&m).schedulePreview()
	if cmd != nil {
		t.Fatal("expected cache hit to skip tmux fetch command")
	}
	if m.previewContent != "cached pane" {
		t.Fatalf("expected cached preview, got %q", m.previewContent)
	}
	if m.previewRevision != rev {
		t.Fatalf("expected revision %q, got %q", rev, m.previewRevision)
	}
}

func TestRefreshSessionsFromRegistry(t *testing.T) {
	current := []registry.Session{{
		ID:          "1",
		TmuxTarget:  "%1",
		TmuxSession: "nixconfig",
		Status:      registry.StatusIdle,
	}}
	fresh := []registry.Session{{
		ID:         "1",
		TmuxTarget: "%1",
		Status:     registry.StatusWorking,
		ToolName:   "Shell",
		UpdatedAt:  "2026-01-02T12:00:00Z",
	}}

	got := refreshSessionsFromRegistry(current, fresh)
	if len(got) != 1 {
		t.Fatalf("expected one session, got %d", len(got))
	}
	if got[0].Status != registry.StatusWorking || got[0].ToolName != "Shell" {
		t.Fatalf("unexpected merged session: %+v", got[0])
	}
	if got[0].TmuxSession != "nixconfig" {
		t.Fatalf("expected tmux metadata preserved, got %+v", got[0])
	}
}
