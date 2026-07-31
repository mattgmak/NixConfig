package registry

import (
	"os"
	"path/filepath"
	"testing"
)

func TestLoadMissingFile(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "sessions.json")

	sessions, err := Load(path)
	if err != nil {
		t.Fatalf("Load: %v", err)
	}
	if sessions != nil {
		t.Fatalf("expected nil sessions, got %v", sessions)
	}
}

func TestSaveAndLoad(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "sessions.json")
	want := []Session{
		{
			ID:         "abc",
			TmuxTarget: "%1",
			CWD:        "/tmp",
			Title:      "test",
			Status:     StatusWorking,
		},
	}

	if err := Save(path, want); err != nil {
		t.Fatalf("Save: %v", err)
	}

	got, err := Load(path)
	if err != nil {
		t.Fatalf("Load: %v", err)
	}
	if len(got) != 1 {
		t.Fatalf("len(got) = %d, want 1", len(got))
	}
	if got[0].ID != want[0].ID || got[0].TmuxTarget != want[0].TmuxTarget {
		t.Fatalf("got %+v, want %+v", got[0], want[0])
	}
}

func TestPruneMissingPanes(t *testing.T) {
	sessions := []Session{
		{TmuxTarget: "%1"},
		{TmuxTarget: "%2"},
		{TmuxTarget: " "},
		{TmuxTarget: "main"},
	}

	exists := func(target string) bool {
		return target == "%1" || target == "main"
	}

	got := PruneMissingPanes(sessions, exists)
	if len(got) != 2 {
		t.Fatalf("len(got) = %d, want 2", len(got))
	}
	if got[0].TmuxTarget != "%1" || got[1].TmuxTarget != "main" {
		t.Fatalf("got %+v", got)
	}

	unchanged := PruneMissingPanes(sessions, nil)
	if len(unchanged) != len(sessions) {
		t.Fatalf("expected no pruning when checker is nil")
	}
}

func TestDefaultPath(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)

	path, err := DefaultPath()
	if err != nil {
		t.Fatalf("DefaultPath: %v", err)
	}
	want := filepath.Join(home, ".local", "state", "agent-sesh", sessionsFileName)
	if path != want {
		t.Fatalf("got %q, want %q", path, want)
	}
}

func TestSaveEmptyPath(t *testing.T) {
	if err := Save("", nil); err == nil {
		t.Fatal("expected error for empty path")
	}
}

func TestLoadInvalidJSON(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "sessions.json")
	if err := os.WriteFile(path, []byte("{"), 0o644); err != nil {
		t.Fatal(err)
	}
	if _, err := Load(path); err == nil {
		t.Fatal("expected parse error")
	}
}

func TestLoadVersionedFile(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "sessions.json")
	data := `{
  "version": 1,
  "sessions": [
    {
      "id": "abc",
      "tmux_target": "%1",
      "cwd": "/tmp",
      "title": "test",
      "status": "working",
      "agent": "pi"
    }
  ]
}
`
	if err := os.WriteFile(path, []byte(data), 0o644); err != nil {
		t.Fatal(err)
	}

	sessions, err := Load(path)
	if err != nil {
		t.Fatalf("Load: %v", err)
	}
	if len(sessions) != 1 || sessions[0].ID != "abc" {
		t.Fatalf("got %+v", sessions)
	}
}

func TestLoadBareArray(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "sessions.json")
	data := `[{"id":"legacy","tmux_target":"%9","cwd":"/tmp","title":"legacy","status":"idle","agent":"pi"}]`
	if err := os.WriteFile(path, []byte(data), 0o644); err != nil {
		t.Fatal(err)
	}

	sessions, err := Load(path)
	if err != nil {
		t.Fatalf("Load: %v", err)
	}
	if len(sessions) != 1 || sessions[0].ID != "legacy" {
		t.Fatalf("got %+v", sessions)
	}
}

func TestLoadEmptyFile(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "sessions.json")
	if err := os.WriteFile(path, nil, 0o644); err != nil {
		t.Fatal(err)
	}

	sessions, err := Load(path)
	if err != nil {
		t.Fatalf("Load: %v", err)
	}
	if sessions != nil {
		t.Fatalf("expected nil sessions for empty file, got %v", sessions)
	}
}

func TestDefaultPathXDG(t *testing.T) {
	stateHome := t.TempDir()
	t.Setenv("XDG_STATE_HOME", stateHome)
	t.Setenv("HOME", t.TempDir())

	path, err := DefaultPath()
	if err != nil {
		t.Fatalf("DefaultPath: %v", err)
	}
	want := filepath.Join(stateHome, "agent-sesh", sessionsFileName)
	if path != want {
		t.Fatalf("got %q, want %q", path, want)
	}
}
