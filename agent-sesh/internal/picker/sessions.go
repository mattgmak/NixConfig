package picker

import (
	"strings"

	"github.com/mattgmak/agent-sesh/internal/registry"
	"github.com/mattgmak/agent-sesh/internal/tmux"
)

func defaultSanitizeOpts() registry.SanitizeOptions {
	return registry.SanitizeOptions{
		PaneExists: tmux.PaneExists,
		HasAgent: func(target, agent string) bool {
			switch agent {
			case "", "pi":
				return tmux.PaneHasPiAgent(target)
			default:
				return false
			}
		},
	}
}

func loadSessionsFast(path string) ([]registry.Session, error) {
	defer profileStart("loadSessionsFast")()
	sessions, err := registry.Load(path)
	if err != nil {
		return nil, err
	}
	sanitized, _ := registry.Sanitize(sessions, registry.SanitizeOptions{})
	return sanitized, nil
}

func loadSessionsFull(path string) ([]registry.Session, error) {
	defer profileStart("loadSessionsFull")()
	sessions, err := registry.Load(path)
	if err != nil {
		return nil, err
	}
	sanitized, pruned := registry.Sanitize(sessions, defaultSanitizeOpts())
	if len(pruned) > 0 || len(sanitized) != len(sessions) {
		_ = registry.Save(path, sanitized)
	}
	sessions = mergeDiscoveredSessions(sanitized)
	return enrichSessions(sessions), nil
}

func loadSessions(path string) ([]registry.Session, error) {
	return loadSessionsFull(path)
}

func sanitizeAndPersist(path string, sessions []registry.Session) []registry.Session {
	loaded, err := loadSessionsFull(path)
	if err != nil {
		return sessions
	}
	return loaded
}

func enrichSessions(sessions []registry.Session) []registry.Session {
	out := make([]registry.Session, len(sessions))
	for i, session := range sessions {
		out[i] = enrichSession(session)
	}
	return out
}

func enrichSession(session registry.Session) registry.Session {
	if session.TmuxSession != "" && session.CWD != "" {
		return session
	}
	defer profileStart("enrichSession")()
	info := tmux.PaneInfoFor(session.TmuxTarget)
	if session.TmuxSession == "" && info.SessionName != "" {
		session.TmuxSession = info.SessionName
	}
	if session.TmuxWindow == "" && info.WindowIndex != "" {
		session.TmuxWindow = info.WindowIndex
	}
	if session.TmuxPane == "" && info.PaneIndex != "" {
		session.TmuxPane = info.PaneIndex
	}
	if session.CWD == "" && info.CurrentPath != "" {
		session.CWD = info.CurrentPath
	}
	return session
}

func mergeRegistryFields(dst, src registry.Session) registry.Session {
	dst.Status = src.Status
	dst.ToolName = src.ToolName
	dst.UpdatedAt = src.UpdatedAt
	dst.LastPrompt = src.LastPrompt
	dst.Branch = src.Branch
	dst.Title = src.Title
	dst.Model = src.Model
	if src.CWD != "" {
		dst.CWD = src.CWD
	}
	if src.TmuxSession != "" {
		dst.TmuxSession = src.TmuxSession
	}
	if src.TmuxWindow != "" {
		dst.TmuxWindow = src.TmuxWindow
	}
	if src.TmuxPane != "" {
		dst.TmuxPane = src.TmuxPane
	}
	return dst
}

// refreshSessionsFromRegistry updates live status fields without re-scanning tmux.
func refreshSessionsFromRegistry(current, fresh []registry.Session) []registry.Session {
	defer profileStart("refreshSessionsFromRegistry")()

	freshByTarget := make(map[string]registry.Session, len(fresh))
	for _, session := range fresh {
		target := strings.TrimSpace(session.TmuxTarget)
		if target != "" {
			freshByTarget[target] = session
		}
	}

	out := make([]registry.Session, 0, len(current)+len(fresh))
	seen := make(map[string]struct{}, len(current))

	for _, session := range current {
		target := strings.TrimSpace(session.TmuxTarget)
		if target == "" {
			continue
		}
		if freshSession, ok := freshByTarget[target]; ok {
			session = mergeRegistryFields(session, freshSession)
			out = append(out, session)
			seen[target] = struct{}{}
			continue
		}
		if strings.HasPrefix(session.ID, discoveredPrefix) {
			out = append(out, session)
		}
	}

	for target, session := range freshByTarget {
		if _, ok := seen[target]; ok {
			continue
		}
		out = append(out, enrichSession(session))
	}
	return out
}
