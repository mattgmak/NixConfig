package picker

import (
	"fmt"
	"io"
	"os"
	"os/exec"
	"strings"

	"github.com/mattgmak/agent-sesh/internal/registry"
	"github.com/mattgmak/agent-sesh/internal/tmux"
)

// List writes one fzf-friendly line per session. The display text may include
// embedded newlines so multiline titles/previews stay intact in --ansi mode.
func List(w io.Writer) error {
	path, err := registry.DefaultPath()
	if err != nil {
		return err
	}
	sessions, err := registry.Load(path)
	if err != nil {
		return err
	}
	sessions = sanitizeAndPersist(path, sessions)
	for _, session := range sessions {
		if _, err := fmt.Fprintln(w, formatFzfLine(session)); err != nil {
			return err
		}
	}
	return nil
}

// Preview writes tmux capture-pane output for a session id or tmux target.
func Preview(w io.Writer, key string) error {
	path, err := registry.DefaultPath()
	if err != nil {
		return err
	}
	sessions, err := registry.Load(path)
	if err != nil {
		return err
	}

	key = strings.TrimSpace(key)
	var session registry.Session
	var found bool
	for _, s := range sessions {
		if s.ID == key || s.TmuxTarget == key || s.Title == key {
			session = s
			found = true
			break
		}
	}
	target := key
	revision := ""
	if found {
		target = session.TmuxTarget
		revision = previewRevision(session)
	}
	if revision != "" {
		if content, err, ok := getPreviewCache(target, revision); ok {
			_, err = io.WriteString(w, content)
			return err
		}
	}
	content, err := tmux.CapturePane(target, 0)
	if err != nil {
		return err
	}
	if revision != "" {
		setPreviewCache(target, revision, content, nil)
	}
	_, err = io.WriteString(w, content)
	return err
}

// RunFzf launches an sesh-style fzf picker with multiline ANSI preview.
func RunFzf() error {
	if _, err := initProfile(); err != nil {
		return fmt.Errorf("init profile: %w", err)
	}
	defer func() {
		if path := closeProfile(); path != "" {
			fmt.Fprintf(os.Stderr, "agent-sesh: profile log %s\n", path)
		}
	}()

	path, err := registry.DefaultPath()
	if err != nil {
		return err
	}
	sessions, err := registry.Load(path)
	if err != nil {
		return err
	}
	sessions = sanitizeAndPersist(path, sessions)
	if len(sessions) == 0 {
		return nil
	}

	self, err := os.Executable()
	if err != nil {
		return err
	}

	preview := fmt.Sprintf("%s preview {1}", self)
	cmd := exec.Command(
		"fzf",
		"--tmux", "90%,90%",
		"--no-sort",
		"--ansi",
		"--border", "rounded",
		"--border-label", " agent-sesh ",
		"--input-border", "rounded",
		"--preview-border", "rounded",
		"--prompt", "> ",
		"--header", "  Enter attach  ^x kill pane  ^X kill session  ^t new window",
		"--bind", "tab:down,btab:up",
		"--preview-window", "right:40%",
		"--preview", preview,
		"--delimiter", "\t",
		"--with-nth", "2..",
	)
	cmd.Stdin = strings.NewReader(formatFzfInput(sessions))
	cmd.Env = os.Environ()
	cmd.Stderr = os.Stderr

	out, err := cmd.Output()
	if err != nil {
		if exit, ok := err.(*exec.ExitError); ok && exit.ExitCode() == 130 {
			return nil
		}
		return err
	}

	line := strings.TrimSpace(string(out))
	if line == "" {
		return nil
	}
	fields := strings.SplitN(line, "\t", 2)
	id := fields[0]
	for _, session := range sessions {
		if session.ID != id {
			continue
		}
		return tmux.SwitchClient(session.TmuxTarget)
	}
	return fmt.Errorf("session %q not found", id)
}

func formatFzfInput(sessions []registry.Session) string {
	var b strings.Builder
	for _, session := range sessions {
		b.WriteString(formatFzfLine(session))
		b.WriteByte('\n')
	}
	return b.String()
}

func formatFzfLine(session registry.Session) string {
	label := formatSessionLine(session, 120)
	label = strings.ReplaceAll(label, "\t", " ")
	return session.ID + "\t" + label
}
