package registry

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

const sessionsFileName = "sessions.json"

type Status string

const (
	StatusIdle     Status = "idle"
	StatusWorking  Status = "working"
	StatusToolCall Status = "tool_call"
	StatusWaiting  Status = "waiting"
)

type Session struct {
	ID          string `json:"id"`
	TmuxTarget  string `json:"tmux_target"`
	TmuxSession string `json:"tmux_session,omitempty"`
	TmuxWindow  string `json:"tmux_window,omitempty"`
	TmuxPane    string `json:"tmux_pane,omitempty"`
	CWD         string `json:"cwd"`
	Title       string `json:"title"`
	LastPrompt  string `json:"last_prompt,omitempty"`
	Branch      string `json:"branch"`
	Agent       string `json:"agent"`
	Model       string `json:"model,omitempty"`
	Status      Status `json:"status"`
	ToolName    string `json:"tool_name"`
	UpdatedAt   string `json:"updated_at,omitempty"`
}

type File struct {
	Version  int       `json:"version"`
	Sessions []Session `json:"sessions"`
}

func DefaultPath() (string, error) {
	stateHome := os.Getenv("XDG_STATE_HOME")
	if stateHome == "" {
		home, err := os.UserHomeDir()
		if err != nil {
			return "", err
		}
		stateHome = filepath.Join(home, ".local", "state")
	}
	return filepath.Join(stateHome, "agent-sesh", sessionsFileName), nil
}

func Load(path string) ([]Session, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return nil, nil
		}
		return nil, err
	}
	if len(data) == 0 {
		return nil, nil
	}

	var file File
	if err := json.Unmarshal(data, &file); err != nil {
		// Back-compat: bare array written by early tooling.
		var sessions []Session
		if err2 := json.Unmarshal(data, &sessions); err2 != nil {
			return nil, fmt.Errorf("parse registry %s: %w", path, err)
		}
		return sessions, nil
	}
	if file.Version == 0 {
		file.Version = 1
	}
	return file.Sessions, nil
}

func Save(path string, sessions []Session) error {
	if path == "" {
		return fmt.Errorf("registry path is empty")
	}
	file := File{Version: 1, Sessions: sessions}
	data, err := json.MarshalIndent(file, "", "  ")
	if err != nil {
		return err
	}
	data = append(data, '\n')
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	return os.WriteFile(path, data, 0o644)
}

func PruneMissingPanes(sessions []Session, paneExists func(string) bool) []Session {
	if paneExists == nil {
		return sessions
	}
	out := make([]Session, 0, len(sessions))
	for _, s := range sessions {
		target := strings.TrimSpace(s.TmuxTarget)
		if target == "" {
			continue
		}
		if paneExists(target) {
			out = append(out, s)
		}
	}
	return out
}
