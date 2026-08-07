package debug

import (
	"encoding/json"
	"fmt"
	"io"
	"strings"
	"text/tabwriter"

	"github.com/mattgmak/agent-sesh/internal/registry"
	"github.com/mattgmak/agent-sesh/internal/tmux"
)

func defaultSanitizeOpts() registry.SanitizeOptions {
	return registry.SanitizeOptions{
		PaneExists: tmux.PaneExists,
		HasAgent: func(target, agent string) bool {
			switch strings.TrimSpace(agent) {
			case "", "pi":
				return tmux.PaneHasPiAgent(target)
			default:
				return false
			}
		},
	}
}

// Registry prints the raw sessions.json contents.
func Registry(w io.Writer) error {
	path, err := registry.DefaultPath()
	if err != nil {
		return err
	}
	sessions, err := registry.Load(path)
	if err != nil {
		return err
	}
	enc := json.NewEncoder(w)
	enc.SetIndent("", "  ")
	return enc.Encode(registry.File{Version: 1, Sessions: sessions})
}

// Validate runs sanitize and prints kept/pruned rows.
func Validate(w io.Writer) error {
	path, err := registry.DefaultPath()
	if err != nil {
		return err
	}
	sessions, err := registry.Load(path)
	if err != nil {
		return err
	}

	kept, removed := registry.Sanitize(sessions, defaultSanitizeOpts())
	fmt.Fprintf(w, "registry: %s\n", path)
	fmt.Fprintf(w, "loaded: %d  kept: %d  pruned: %d\n\n", len(sessions), len(kept), len(removed))

	if len(removed) > 0 {
		fmt.Fprintln(w, "pruned:")
		tw := tabwriter.NewWriter(w, 0, 0, 2, ' ', 0)
		fmt.Fprintln(tw, "TARGET\tREASON\tID\tTITLE")
		for _, row := range removed {
			fmt.Fprintf(tw, "%s\t%s\t%s\t%s\n",
				row.Session.TmuxTarget,
				row.Reason,
				shortID(row.Session.ID),
				row.Session.Title,
			)
		}
		_ = tw.Flush()
		fmt.Fprintln(w)
	}

	if len(kept) > 0 {
		fmt.Fprintln(w, "kept:")
		tw := tabwriter.NewWriter(w, 0, 0, 2, ' ', 0)
		fmt.Fprintln(tw, "TARGET\tSESSION\tAGENT\tSTATUS\tPROMPT")
		for _, session := range kept {
			fmt.Fprintf(tw, "%s\t%s\t%s\t%s\t%s\n",
				session.TmuxTarget,
				sessionName(session),
				session.Agent,
				session.Status,
				shortText(promptFor(session), 48),
			)
		}
		return tw.Flush()
	}
	return nil
}

// Panes prints registry rows alongside live tmux pane state.
func Panes(w io.Writer) error {
	path, err := registry.DefaultPath()
	if err != nil {
		return err
	}
	sessions, err := registry.Load(path)
	if err != nil {
		return err
	}
	sessions, _ = registry.Sanitize(sessions, defaultSanitizeOpts())

	tw := tabwriter.NewWriter(w, 0, 0, 2, ' ', 0)
	fmt.Fprintln(tw, "TARGET\tSESSION\tREGISTRY\tLIVE_CMD\tPI\tPROMPT")
	for _, session := range sessions {
		info := tmux.PaneInfoFor(session.TmuxTarget)
		fmt.Fprintf(tw, "%s\t%s\t%s\t%s\t%t\t%s\n",
			session.TmuxTarget,
			sessionName(session),
			shortID(session.ID),
			info.CurrentCommand,
			info.HasPiAgent,
			shortText(promptFor(session), 40),
		)
	}
	if err := tw.Flush(); err != nil {
		return err
	}
	return Discover(w)
}

// Pane prints detailed metadata for one tmux target.
func Pane(w io.Writer, target string) error {
	info := tmux.PaneInfoFor(target)
	enc := json.NewEncoder(w)
	enc.SetIndent("", "  ")
	return enc.Encode(info)
}

// Discover lists panes with pi running that are missing from the registry.
func Discover(w io.Writer) error {
	path, err := registry.DefaultPath()
	if err != nil {
		return err
	}
	sessions, err := registry.Load(path)
	if err != nil {
		return err
	}
	sessions, _ = registry.Sanitize(sessions, defaultSanitizeOpts())

	known := make(map[string]struct{}, len(sessions))
	for _, session := range sessions {
		known[strings.TrimSpace(session.TmuxTarget)] = struct{}{}
	}

	paneIDs, err := tmux.ListPaneIDs()
	if err != nil {
		return err
	}

	var missing []tmux.PaneInfo
	for _, paneID := range paneIDs {
		info := tmux.PaneInfoFor(paneID)
		if !info.HasPiAgent {
			continue
		}
		if _, ok := known[paneID]; ok {
			continue
		}
		missing = append(missing, info)
	}

	if len(missing) == 0 {
		fmt.Fprintln(w, "discover: no unregistered pi panes")
		return nil
	}

	fmt.Fprintln(w, "discover: pi panes missing from registry:")
	tw := tabwriter.NewWriter(w, 0, 0, 2, ' ', 0)
	fmt.Fprintln(tw, "TARGET\tSESSION\tCMD\tPATH")
	for _, info := range missing {
		fmt.Fprintf(tw, "%s\t%s:%s.%s\t%s\t%s\n",
			info.PaneID,
			info.SessionName,
			info.WindowIndex,
			info.PaneIndex,
			info.CurrentCommand,
			info.CurrentPath,
		)
	}
	return tw.Flush()
}

func sessionName(session registry.Session) string {
	if name := strings.TrimSpace(session.TmuxSession); name != "" {
		return name
	}
	if name, err := tmux.SessionName(session.TmuxTarget); err == nil {
		return name
	}
	return "?"
}

func promptFor(session registry.Session) string {
	if prompt := strings.TrimSpace(session.LastPrompt); prompt != "" {
		return prompt
	}
	return session.Title
}

func shortID(id string) string {
	id = strings.TrimSpace(id)
	if len(id) <= 8 {
		return id
	}
	return id[:8]
}

func shortText(text string, max int) string {
	text = strings.TrimSpace(text)
	if max <= 0 || len(text) <= max {
		return text
	}
	if max <= 3 {
		return text[:max]
	}
	return text[:max-3] + "..."
}
