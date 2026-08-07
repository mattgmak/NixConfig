package picker

import (
	"os"
	"strings"
	"testing"
	"time"
)

func TestProfileWritesToFileNotStderr(t *testing.T) {
	logPath := t.TempDir() + "/profile.log"
	t.Setenv("AGENT_SESH_PROFILE", logPath)

	path, err := initProfile()
	if err != nil {
		t.Fatalf("initProfile: %v", err)
	}
	if path != logPath {
		t.Fatalf("initProfile path = %q, want %q", path, logPath)
	}

	done := profileStart("sample-op")
	time.Sleep(time.Millisecond)
	done()
	profileNote("schedulePreview", "cache hit %0")
	closeProfile()

	data, err := os.ReadFile(logPath)
	if err != nil {
		t.Fatalf("read profile log: %v", err)
	}
	text := string(data)
	if !strings.Contains(text, "sample-op") {
		t.Fatalf("expected timed sample-op in log, got:\n%s", text)
	}
	if !strings.Contains(text, "cache hit %0") {
		t.Fatalf("expected note in log, got:\n%s", text)
	}
	if !strings.Contains(text, "summary") {
		t.Fatalf("expected summary in log, got:\n%s", text)
	}
}

func TestProfileDisabledByDefault(t *testing.T) {
	t.Setenv("AGENT_SESH_PROFILE", "")
	path, err := initProfile()
	if err != nil {
		t.Fatalf("initProfile: %v", err)
	}
	if path != "" {
		t.Fatalf("expected profiling disabled, got path %q", path)
	}
	done := profileStart("ignored")
	done()
}
