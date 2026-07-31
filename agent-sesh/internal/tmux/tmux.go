package tmux

import (
	"fmt"
	"os/exec"
	"strings"
)

func PaneExists(target string) bool {
	if strings.TrimSpace(target) == "" {
		return false
	}
	err := exec.Command("tmux", "list-panes", "-t", target, "-F", "#{pane_id}").Run()
	return err == nil
}

func CapturePane(target string, lines int) (string, error) {
	target = strings.TrimSpace(target)
	if target == "" {
		return "", fmt.Errorf("empty pane target")
	}

	// Match sesh: capture-pane -e -p -t TARGET (colors + visible pane).
	out, err := exec.Command("tmux", "capture-pane", "-e", "-p", "-t", target).Output()
	if err == nil && strings.TrimSpace(string(out)) != "" {
		return string(out), nil
	}

	// Full-screen TUIs (pi) render on the alternate screen.
	out, err = exec.Command("tmux", "capture-pane", "-e", "-p", "-a", "-q", "-t", target).Output()
	if err == nil && strings.TrimSpace(string(out)) != "" {
		return string(out), nil
	}

	if lines <= 0 {
		lines = 200
	}
	out, err = exec.Command(
		"tmux", "capture-pane", "-e", "-p", "-J", "-S", fmt.Sprintf("-%d", lines), "-t", target,
	).Output()
	if err != nil {
		return "", err
	}
	return string(out), nil
}

func SwitchClient(target string) error {
	return exec.Command("tmux", "switch-client", "-t", target).Run()
}

func SessionName(target string) (string, error) {
	out, err := exec.Command("tmux", "display-message", "-p", "-t", target, "#{session_name}").Output()
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(out)), nil
}

func PanePath(target string) (string, error) {
	out, err := exec.Command("tmux", "display-message", "-p", "-t", target, "#{pane_current_path}").Output()
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(out)), nil
}

func RenameSession(session string, name string) error {
	name = strings.TrimSpace(name)
	if name == "" {
		return fmt.Errorf("session name cannot be empty")
	}
	return exec.Command("tmux", "rename-session", "-t", session, name).Run()
}

func KillPane(target string) error {
	return exec.Command("tmux", "kill-pane", "-t", target).Run()
}

func KillSession(name string) error {
	return exec.Command("tmux", "kill-session", "-t", name).Run()
}

func NewWindowAtPanePath(target string) error {
	path, err := PanePath(target)
	if err != nil {
		return err
	}
	session, err := SessionName(target)
	if err != nil {
		return err
	}
	args := []string{"new-window", "-t", session}
	if path != "" {
		args = append(args, "-c", path)
	}
	return exec.Command("tmux", args...).Run()
}

// TargetKind classifies a tmux target string.
type TargetKind int

const (
	TargetUnknown TargetKind = iota
	TargetPane
	TargetWindow
	TargetSession
)

// ParseTarget inspects common tmux target forms without calling tmux.
func ParseTarget(target string) (TargetKind, string) {
	target = strings.TrimSpace(target)
	if target == "" {
		return TargetUnknown, ""
	}
	if strings.HasPrefix(target, "%") {
		return TargetPane, target
	}
	if strings.Contains(target, ":") {
		return TargetWindow, target
	}
	return TargetSession, target
}
