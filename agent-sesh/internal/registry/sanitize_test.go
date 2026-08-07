package registry

import (
	"testing"
	"time"
)

func TestSanitizeDedupesByTargetKeepsNewest(t *testing.T) {
	now := time.Date(2026, 8, 7, 12, 0, 0, 0, time.UTC)
	sessions := []Session{
		{ID: "old", TmuxTarget: "%1", UpdatedAt: now.Add(-time.Hour).Format(time.RFC3339)},
		{ID: "new", TmuxTarget: "%1", UpdatedAt: now.Format(time.RFC3339)},
	}

	kept, removed := Sanitize(sessions, SanitizeOptions{
		PaneExists: func(string) bool { return true },
		HasAgent:   func(string, string) bool { return true },
		Now:        func() time.Time { return now },
	})

	if len(kept) != 1 || kept[0].ID != "new" {
		t.Fatalf("kept = %+v, want newest id new", kept)
	}
	if len(removed) != 1 || removed[0].Reason != "duplicate tmux target" {
		t.Fatalf("removed = %+v", removed)
	}
}

func TestSanitizeDropsMissingPaneAndNonAgent(t *testing.T) {
	sessions := []Session{
		{ID: "gone", TmuxTarget: "%1", Agent: "pi"},
		{ID: "lazygit", TmuxTarget: "%2", Agent: "pi"},
		{ID: "live", TmuxTarget: "%3", Agent: "pi"},
	}

	kept, removed := Sanitize(sessions, SanitizeOptions{
		PaneExists: func(target string) bool { return target == "%2" || target == "%3" },
		HasAgent: func(target, agent string) bool {
			return target == "%3"
		},
	})

	if len(kept) != 1 || kept[0].ID != "live" {
		t.Fatalf("kept = %+v", kept)
	}
	if len(removed) != 2 {
		t.Fatalf("removed = %+v, want 2", removed)
	}
}
