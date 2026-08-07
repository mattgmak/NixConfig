package registry

import (
	"strings"
	"time"
)

// PruneReason explains why a session was removed during Sanitize.
type PruneReason struct {
	Session Session
	Reason  string
}

// SanitizeOptions controls registry cleanup before display or persistence.
type SanitizeOptions struct {
	PaneExists func(string) bool
	HasAgent   func(target, agent string) bool
	Now        func() time.Time
}

// Sanitize drops invalid registry rows and returns removed sessions with reasons.
func Sanitize(sessions []Session, opts SanitizeOptions) ([]Session, []PruneReason) {
	if len(sessions) == 0 {
		return nil, nil
	}

	now := opts.Now
	if now == nil {
		now = time.Now
	}

	kept := make([]Session, 0, len(sessions))
	removed := make([]PruneReason, 0)

	// Keep the newest row per tmux pane target.
	byTarget := make(map[string]Session, len(sessions))
	for _, session := range sessions {
		target := strings.TrimSpace(session.TmuxTarget)
		if target == "" {
			removed = append(removed, PruneReason{Session: session, Reason: "missing tmux target"})
			continue
		}

		existing, ok := byTarget[target]
		if !ok || sessionUpdatedAfter(session, existing, now()) {
			if ok {
				removed = append(removed, PruneReason{Session: existing, Reason: "duplicate tmux target"})
			}
			byTarget[target] = session
			continue
		}
		removed = append(removed, PruneReason{Session: session, Reason: "duplicate tmux target"})
	}

	for _, session := range byTarget {
		target := strings.TrimSpace(session.TmuxTarget)

		if opts.PaneExists != nil && !opts.PaneExists(target) {
			removed = append(removed, PruneReason{Session: session, Reason: "pane missing"})
			continue
		}

		agent := strings.TrimSpace(session.Agent)
		if agent == "" {
			agent = "pi"
		}
		if opts.HasAgent != nil && !opts.HasAgent(target, agent) {
			removed = append(removed, PruneReason{Session: session, Reason: "agent not running in pane"})
			continue
		}

		kept = append(kept, session)
	}

	return kept, removed
}

func sessionUpdatedAfter(a, b Session, now time.Time) bool {
	at, aOK := parseUpdatedAt(a.UpdatedAt, now)
	bt, bOK := parseUpdatedAt(b.UpdatedAt, now)
	switch {
	case aOK && bOK:
		return at.After(bt)
	case aOK:
		return true
	case bOK:
		return false
	default:
		return a.ID > b.ID
	}
}

func parseUpdatedAt(value string, fallback time.Time) (time.Time, bool) {
	value = strings.TrimSpace(value)
	if value == "" {
		return fallback, false
	}
	t, err := time.Parse(time.RFC3339Nano, value)
	if err != nil {
		t, err = time.Parse(time.RFC3339, value)
	}
	if err != nil {
		return fallback, false
	}
	return t, true
}
