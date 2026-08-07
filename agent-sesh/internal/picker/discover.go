package picker

import (
	"fmt"
	"os"
	"strings"

	"github.com/mattgmak/agent-sesh/internal/registry"
	"github.com/mattgmak/agent-sesh/internal/tmux"
)

const discoveredPrefix = "discovered:"

func isDiscovered(session registry.Session) bool {
	return strings.HasPrefix(session.ID, discoveredPrefix)
}

func mergeDiscoveredSessions(registered []registry.Session) []registry.Session {
	if os.Getenv("AGENT_SESH_DISABLE_DISCOVER") == "1" {
		return registered
	}
	known := make(map[string]struct{}, len(registered))
	for _, session := range registered {
		target := strings.TrimSpace(session.TmuxTarget)
		if target != "" {
			known[target] = struct{}{}
		}
	}

	paneIDs, err := tmux.ListPaneIDs()
	if err != nil {
		return registered
	}

	out := append([]registry.Session(nil), registered...)
	for _, paneID := range paneIDs {
		if _, ok := known[paneID]; ok {
			continue
		}
		if !tmux.PaneHasPiAgent(paneID) {
			continue
		}

		info := tmux.PaneInfoFor(paneID)
		title := "pi session"
		if info.CurrentPath != "" {
			title = info.CurrentPath
		}
		out = append(out, registry.Session{
			ID:          discoveredPrefix + strings.TrimPrefix(paneID, "%"),
			TmuxTarget:  paneID,
			TmuxSession: info.SessionName,
			TmuxWindow:  info.WindowIndex,
			TmuxPane:    info.PaneIndex,
			CWD:         info.CurrentPath,
			Title:       title,
			Agent:       "pi",
			Status:      registry.StatusIdle,
		})
	}

	return out
}

func sessionPaneLabel(session registry.Session) string {
	if window, pane, ok := sessionPaneCoords(session); ok {
		return fmt.Sprintf("%s.%s", window, pane)
	}
	return ""
}

func sessionPaneCoords(session registry.Session) (window, pane string, ok bool) {
	window = strings.TrimSpace(session.TmuxWindow)
	pane = strings.TrimSpace(session.TmuxPane)
	if window != "" && pane != "" {
		return window, pane, true
	}
	return tmux.PaneLocation(session.TmuxTarget)
}
