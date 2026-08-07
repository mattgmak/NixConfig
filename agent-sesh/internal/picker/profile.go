package picker

import (
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"sync"
	"time"
)

type profileStat struct {
	count int
	total time.Duration
	max   time.Duration
}

var (
	profileMu     sync.Mutex
	profileWriter io.Writer
	profileFile   *os.File
	profilePath   string
	profileStats  map[string]*profileStat
)

func initProfile() (string, error) {
	raw := strings.TrimSpace(os.Getenv("AGENT_SESH_PROFILE"))
	if raw == "" {
		return "", nil
	}

	path := raw
	if raw == "1" || strings.EqualFold(raw, "true") {
		stateHome := os.Getenv("XDG_STATE_HOME")
		if stateHome == "" {
			home, err := os.UserHomeDir()
			if err != nil {
				return "", err
			}
			stateHome = filepath.Join(home, ".local", "state")
		}
		path = filepath.Join(stateHome, "agent-sesh", "profile.log")
	}

	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return "", err
	}

	f, err := os.OpenFile(path, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0o644)
	if err != nil {
		return "", err
	}

	profileMu.Lock()
	profileFile = f
	profileWriter = f
	profilePath = path
	profileStats = make(map[string]*profileStat)
	profileMu.Unlock()

	fmt.Fprintf(f, "agent-sesh profile started %s pid=%d\n", time.Now().Format(time.RFC3339), os.Getpid())
	return path, nil
}

func closeProfile() string {
	profileMu.Lock()
	defer profileMu.Unlock()

	if profileFile == nil {
		return ""
	}

	writeProfileSummaryLocked()
	path := profilePath
	_ = profileFile.Close()
	profileFile = nil
	profileWriter = nil
	profileStats = nil
	return path
}

func writeProfileSummaryLocked() {
	if profileWriter == nil || len(profileStats) == 0 {
		return
	}

	names := make([]string, 0, len(profileStats))
	for name := range profileStats {
		names = append(names, name)
	}
	sort.Strings(names)

	fmt.Fprintln(profileWriter, "agent-sesh profile: summary")
	for _, name := range names {
		stat := profileStats[name]
		avg := stat.total / time.Duration(stat.count)
		fmt.Fprintf(profileWriter, "agent-sesh profile: %-28s count=%4d total=%12s avg=%10s max=%10s\n",
			name, stat.count, stat.total.Round(time.Microsecond), avg.Round(time.Microsecond), stat.max.Round(time.Microsecond))
	}
}

func profileStart(name string) func() {
	if profileWriter == nil {
		return func() {}
	}
	start := time.Now()
	return func() {
		elapsed := time.Since(start)
		profileRecord(name, elapsed)
		profileWrite(name, elapsed.String())
	}
}

func profileNote(name, detail string) {
	if profileWriter == nil {
		return
	}
	profileWrite(name, detail)
}

func profileWrite(name, detail string) {
	profileMu.Lock()
	defer profileMu.Unlock()
	if profileWriter == nil {
		return
	}
	fmt.Fprintf(profileWriter, "agent-sesh profile: %s %s\n", name, detail)
}

func profileRecord(name string, elapsed time.Duration) {
	profileMu.Lock()
	defer profileMu.Unlock()
	stat, ok := profileStats[name]
	if !ok {
		stat = &profileStat{}
		profileStats[name] = stat
	}
	stat.count++
	stat.total += elapsed
	if elapsed > stat.max {
		stat.max = elapsed
	}
}
