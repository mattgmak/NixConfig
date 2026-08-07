package picker

import (
	"fmt"
	"os"
	"strings"
	"time"

	"charm.land/bubbles/v2/textinput"
	tea "charm.land/bubbletea/v2"
	"charm.land/lipgloss/v2"

	"github.com/mattgmak/agent-sesh/internal/registry"
	"github.com/mattgmak/agent-sesh/internal/tmux"
)

type mode int

const (
	modeNormal mode = iota
	modeRename
)

const (
	refreshInterval = 3 * time.Second
)

// Nerd Font 3 MDI codepoints (from nerd-fonts bin/scripts/lib/i_md.sh).
const (
	iconIdle     = "\U000F0766" // 󰝦 circle-outline
	iconWorking  = "\U000F070E" // 󰜎 run
	iconToolCall = "\U000F1322" // 󱌢 hammer-screwdriver
	iconWaiting  = "\U000F0150" // 󰅐 clock-outline
	iconFolder   = "\U000F0256" // 󰉖 folder-outline
	iconBranch   = "\U000F062C" // 󰘬 source-branch
	iconAgent    = "\U000F06A9" // 󰚩 robot
	iconSession  = "\U000F018D" // 󰆍 console
	iconPane     = "\U000F0BCC" // 󰯌 view-split-vertical
	iconPrompt   = "\U000F036A" // 󰍪 message-text-outline
	iconAttach   = "\U000F0339" // 󰌹 link-variant
	iconKillPane = "\U000F0158" // 󰅘 close-box-outline
	iconKillSess = "\U000F05E8" // 󰗨 delete-forever
	iconNewWin   = "\U000F05B1" // 󰖱 window-open
	iconFilter   = "\U000F0349" // 󰍉 magnify
	iconRename   = "\U000F0455" // 󰑕 rename-box
	iconQuit     = "\U000F0206" // 󰈆 exit-to-app
)

type tickMsg struct{}

type previewLoadedMsg struct {
	seq      int
	id       string
	revision string
	content  string
	err      error
}

type sessionsLoadedMsg struct {
	sessions []registry.Session
	err      error
}

type model struct {
	sessions        []registry.Session
	cursor          int
	selectedID      string
	filter          textinput.Model
	rename          textinput.Model
	mode            mode
	width           int
	height          int
	registry        string
	statusLine      string
	quitting        bool
	attach          bool
	previewContent  string
	previewErr      error
	previewPending  string
	previewName     string
	previewRevision string
	previewSeq      int
	loading         bool
}

func Run() error {
	initTerminalColors()

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

	sessions, err := loadSessionsFast(path)
	if err != nil {
		return err
	}

	filter := textinput.New()
	filter.Prompt = "> "
	filter.CharLimit = 120
	filter.Focus()

	rename := textinput.New()
	rename.Prompt = iconRename + " "
	rename.CharLimit = 120

	m := model{
		sessions: sessions,
		filter:   filter,
		rename:   rename,
		registry: path,
		loading:  true,
	}
	m.reconcileCursor()

	profile := detectColorProfile()
	opts := []tea.ProgramOption{tea.WithColorProfile(profile)}
	if term := strings.TrimSpace(os.Getenv("TERM")); term != "" {
		opts = append(opts, tea.WithEnvironment(append(os.Environ(), "TERM="+term)))
	}

	// tmux display-popup -E already owns the pane; alt-screen fights it and bleeds
	// the underlying pi UI through the picker.
	if _, err := tea.NewProgram(m, opts...).Run(); err != nil {
		return err
	}
	return nil
}

func pruneAndPersist(path string, sessions []registry.Session) []registry.Session {
	return sanitizeAndPersist(path, sessions)
}

func (m model) Init() tea.Cmd {
	return tea.Batch(textinput.Blink, scheduleRefresh(), m.loadSessionsAsync(), m.schedulePreview())
}

func (m model) loadSessionsAsync() tea.Cmd {
	path := m.registry
	return func() tea.Msg {
		sessions, err := loadSessionsFull(path)
		return sessionsLoadedMsg{sessions: sessions, err: err}
	}
}

func scheduleRefresh() tea.Cmd {
	return tea.Tick(refreshInterval, func(t time.Time) tea.Msg {
		return tickMsg{}
	})
}

func (m model) filteredSessions() []registry.Session {
	query := strings.TrimSpace(strings.ToLower(m.filter.Value()))
	if query == "" {
		return m.sessions
	}
	out := make([]registry.Session, 0, len(m.sessions))
	for _, session := range m.sessions {
		searchKey := strings.ToLower(strings.Join([]string{
			session.Title,
			session.LastPrompt,
			session.TmuxSession,
			session.TmuxWindow,
			session.TmuxPane,
			sessionPaneLabel(session),
			session.CWD,
			session.Branch,
			string(session.Status),
			session.ToolName,
			session.Agent,
			session.TmuxTarget,
		}, " "))
		if strings.Contains(searchKey, query) {
			out = append(out, session)
		}
	}
	return out
}

func (m model) selected() (registry.Session, bool) {
	items := m.filteredSessions()
	if len(items) == 0 || m.cursor >= len(items) {
		return registry.Session{}, false
	}
	return items[m.cursor], true
}

func (m *model) reconcileCursor() {
	items := m.filteredSessions()
	if len(items) == 0 {
		m.cursor = 0
		m.selectedID = ""
		return
	}

	if m.selectedID != "" {
		for i, session := range items {
			if session.ID == m.selectedID {
				m.cursor = i
				return
			}
		}
	}

	if m.cursor >= len(items) {
		m.cursor = len(items) - 1
	}
	if m.cursor < 0 {
		m.cursor = 0
	}
	m.selectedID = items[m.cursor].ID
}

func (m model) splitActive() bool {
	return splitActive(m.width, m.height, len(m.filteredSessions()) > 0)
}

func (m model) highlightedID() (string, bool) {
	session, ok := m.selected()
	if !ok {
		return "", false
	}
	return session.ID, true
}

func (m *model) schedulePreview() tea.Cmd {
	if !m.splitActive() {
		m.previewSeq++
		m.previewName, m.previewPending, m.previewContent, m.previewErr, m.previewRevision = "", "", "", nil, ""
		return nil
	}

	session, ok := m.selected()
	if !ok {
		m.previewSeq++
		m.previewName, m.previewPending, m.previewContent, m.previewErr, m.previewRevision = "", "", "", nil, ""
		return nil
	}

	id := session.ID
	rev := previewRevision(session)
	if id == m.previewName && rev == m.previewRevision && m.previewPending == "" {
		return nil
	}
	if id == m.previewPending {
		return nil
	}

	target := strings.TrimSpace(session.TmuxTarget)
	if content, err, hit := getPreviewCache(target, rev); hit {
		profileNote("schedulePreview", "cache hit "+target)
		m.previewName = id
		m.previewRevision = rev
		m.previewContent = content
		m.previewErr = err
		m.previewPending = ""
		return nil
	}

	if content, err, _, hit := getPreviewCacheAny(target); hit {
		m.previewName = id
		m.previewContent = content
		m.previewErr = err
	}

	m.previewSeq++
	m.previewPending = id
	seq := m.previewSeq
	return m.fetchPreview(seq, id, target, rev)
}

func (m model) fetchPreview(seq int, id, target, revision string) tea.Cmd {
	return func() tea.Msg {
		defer profileStart("fetchPreview " + target)()
		if target == "" {
			return previewLoadedMsg{seq: seq, id: id, revision: revision, content: "", err: nil}
		}
		content, err := tmux.CapturePane(target, 0)
		setPreviewCache(target, revision, content, err)
		return previewLoadedMsg{seq: seq, id: id, revision: revision, content: content, err: err}
	}
}

func (m model) reload() model {
	defer profileStart("reload")()
	fresh, err := registry.Load(m.registry)
	if err != nil {
		m.statusLine = err.Error()
		return m
	}
	m.sessions = refreshSessionsFromRegistry(m.sessions, fresh)
	if len(m.sessions) == 0 {
		m.quitting = true
		return m
	}
	m.reconcileCursor()
	return m
}

func (m model) reloadFull() model {
	defer profileStart("reloadFull")()
	m.sessions = pruneAndPersist(m.registry, m.sessions)
	if len(m.sessions) == 0 {
		m.quitting = true
		return m
	}
	m.reconcileCursor()
	return m
}

func (m model) setCursor(index int) model {
	items := m.filteredSessions()
	if len(items) == 0 {
		m.cursor = 0
		m.selectedID = ""
		return m
	}
	if index < 0 {
		index = 0
	}
	if index >= len(items) {
		index = len(items) - 1
	}
	m.cursor = index
	m.selectedID = items[index].ID
	return m
}

func (m model) syncInputWidth() {
	width := m.contentWidth() - 4
	if width < 8 {
		width = 8
	}
	m.filter.SetWidth(width)
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case previewLoadedMsg:
		if msg.seq != m.previewSeq {
			return m, nil
		}
		m.previewPending = ""
		m.previewName = msg.id
		m.previewRevision = msg.revision
		m.previewContent = msg.content
		m.previewErr = msg.err
		return m, nil

	case sessionsLoadedMsg:
		if msg.err != nil {
			m.statusLine = msg.err.Error()
			m.loading = false
			return m, nil
		}
		m.loading = false
		m.sessions = msg.sessions
		if len(m.sessions) == 0 {
			m.quitting = true
			return m, tea.Quit
		}
		m.reconcileCursor()
		return m, m.schedulePreview()

	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
		m.syncInputWidth()
		m.reconcileCursor()
		return m, m.schedulePreview()

	case tickMsg:
		oldRev := ""
		if session, ok := m.selected(); ok {
			oldRev = previewRevision(session)
		}
		m = m.reload()
		if m.quitting {
			return m, tea.Quit
		}
		cmd := scheduleRefresh()
		if session, ok := m.selected(); ok && previewRevision(session) != oldRev {
			cmd = tea.Batch(cmd, m.schedulePreview())
		}
		return m, cmd

	case tea.KeyPressMsg:
		if m.mode == modeRename {
			switch msg.String() {
			case "esc":
				m.mode = modeNormal
				m.rename.SetValue("")
				m.statusLine = ""
				m.filter.Focus()
				return m, nil
			case "enter":
				name := strings.TrimSpace(m.rename.Value())
				session, ok := m.selected()
				if !ok {
					m.mode = modeNormal
					m.filter.Focus()
					return m, nil
				}
				sessionName, err := tmux.SessionName(session.TmuxTarget)
				if err != nil {
					m.statusLine = err.Error()
				} else if name == "" {
					m.statusLine = "session name cannot be empty"
				} else if err := tmux.RenameSession(sessionName, name); err != nil {
					m.statusLine = err.Error()
				} else {
					m.statusLine = fmt.Sprintf("renamed session to %s", name)
					m = m.reload()
					if m.quitting {
						return m, tea.Quit
					}
				}
				m.mode = modeNormal
				m.rename.SetValue("")
				m.filter.Focus()
				return m, nil
			}
			var cmd tea.Cmd
			m.rename, cmd = m.rename.Update(msg)
			return m, cmd
		}

		switch msg.String() {
		case "ctrl+c", "q":
			m.quitting = true
			return m, tea.Quit
		case "esc":
			if strings.TrimSpace(m.filter.Value()) != "" {
				m.filter.SetValue("")
				m.reconcileCursor()
				return m, m.schedulePreview()
			}
			m.quitting = true
			return m, tea.Quit
		case "up", "k":
			m = m.setCursor(m.cursor + 1)
			return m, m.schedulePreview()
		case "down", "j":
			m = m.setCursor(m.cursor - 1)
			return m, m.schedulePreview()
		case "enter":
			if m.loading {
				return m, nil
			}
			session, ok := m.selected()
			if !ok {
				return m, nil
			}
			if err := tmux.SwitchClient(session.TmuxTarget); err != nil {
				m.statusLine = err.Error()
				return m, nil
			}
			m.attach = true
			m.quitting = true
			return m, tea.Quit
		case "ctrl+x":
			session, ok := m.selected()
			if !ok {
				return m, nil
			}
			if err := tmux.KillPane(session.TmuxTarget); err != nil {
				m.statusLine = err.Error()
				return m, nil
			}
			m = m.reloadFull()
			if m.quitting {
				return m, tea.Quit
			}
			return m, m.schedulePreview()
		case "ctrl+X":
			session, ok := m.selected()
			if !ok {
				return m, nil
			}
			name, err := tmux.SessionName(session.TmuxTarget)
			if err != nil {
				m.statusLine = err.Error()
				return m, nil
			}
			if err := tmux.KillSession(name); err != nil {
				m.statusLine = err.Error()
				return m, nil
			}
			m = m.reloadFull()
			if m.quitting {
				return m, tea.Quit
			}
			return m, m.schedulePreview()
		case "ctrl+t":
			session, ok := m.selected()
			if !ok {
				return m, nil
			}
			if err := tmux.NewWindowAtPanePath(session.TmuxTarget); err != nil {
				m.statusLine = err.Error()
				return m, nil
			}
			m.statusLine = "new window created"
			return m, nil
		case "ctrl+r":
			session, ok := m.selected()
			if !ok {
				return m, nil
			}
			currentName, err := tmux.SessionName(session.TmuxTarget)
			if err != nil {
				m.statusLine = err.Error()
				return m, nil
			}
			m.mode = modeRename
			m.rename.SetValue(currentName)
			m.rename.Focus()
			return m, textinput.Blink
		}

		prevValue := m.filter.Value()
		var cmd tea.Cmd
		m.filter, cmd = m.filter.Update(msg)
		if m.filter.Value() != prevValue {
			m.cursor = 0
			m.reconcileCursor()
			return m, tea.Batch(cmd, m.schedulePreview())
		}
		return m, cmd
	}

	return m, nil
}

func statusIcon(status registry.Status) string {
	switch status {
	case registry.StatusWorking:
		return iconWorking
	case registry.StatusWaiting:
		return iconWaiting
	case registry.StatusToolCall:
		return iconToolCall
	default:
		return iconIdle
	}
}

const (
	maxPromptLines = 2
)

func limitRunes(text string, max int) string {
	if max < 1 {
		return ""
	}
	runes := []rune(text)
	if len(runes) <= max {
		return text
	}
	if max == 1 {
		return "…"
	}
	return string(runes[:max-1]) + "…"
}

func limitPromptLines(lines []string, width, maxLines int) []string {
	if maxLines < 1 || len(lines) <= maxLines {
		return lines
	}
	lines = lines[:maxLines]
	last := lines[len(lines)-1]
	if !strings.HasSuffix(last, "…") {
		lines[len(lines)-1] = truncateANSI(last, width-1) + "…"
	}
	return lines
}

func shortCWD(path string) string {
	if path == "" {
		return ""
	}
	parts := strings.Split(strings.Trim(path, "/"), "/")
	if len(parts) <= 3 {
		return path
	}
	return ".../" + strings.Join(parts[len(parts)-3:], "/")
}

func formatSessionEntry(session registry.Session, width int) []string {
	status := statusLabelStyle(session.Status).Render(statusIcon(session.Status))
	sessionName := strings.TrimSpace(session.TmuxSession)
	if sessionName == "" {
		sessionName = "?"
	}
	agent := strings.TrimSpace(session.Agent)
	if agent == "" {
		agent = "pi"
	}

	metaParts := []string{
		status,
		normalStyle.Render(iconSession + " " + sessionName),
	}
	if paneLabel := sessionPaneLabel(session); paneLabel != "" {
		metaParts = append(metaParts, normalStyle.Render(iconPane+" "+paneLabel))
	}
	metaParts = append(metaParts, normalStyle.Render(iconAgent+" "+agent))
	if branch := strings.TrimSpace(session.Branch); branch != "" {
		metaParts = append(metaParts, branchStyle.Render(iconBranch+" "+branch))
	}
	if tool := strings.TrimSpace(session.ToolName); tool != "" {
		metaParts = append(metaParts, toolStyle.Render(iconToolCall+" "+tool))
	}
	if cwd := shortCWD(strings.TrimSpace(session.CWD)); cwd != "" {
		metaParts = append(metaParts, mutedStyle.Render(iconFolder+" "+cwd))
	}

	lines := wrapANSI(strings.Join(metaParts, " "), width)

	prompt := strings.TrimSpace(session.LastPrompt)
	if prompt == "" {
		prompt = strings.TrimSpace(session.Title)
	}
	if prompt == "" {
		prompt = "(no prompt)"
	}
	prompt = limitRunes(prompt, width*maxPromptLines)
	promptLines := wrapANSI(dimStyle.Render(iconPrompt+" "+prompt), width)
	promptLines = limitPromptLines(promptLines, width, maxPromptLines)
	for i := 1; i < len(promptLines); i++ {
		promptLines[i] = strings.Repeat(" ", 2) + promptLines[i]
	}
	return append(lines, promptLines...)
}

func formatSessionLine(session registry.Session, width int) string {
	return strings.Join(formatSessionEntry(session, width), "\n")
}

func (m model) headerView() string {
	switch m.mode {
	case modeRename:
		return "  " + m.rename.View()
	default:
		return "  " + m.filter.View()
	}
}

func (m model) contentWidth() int {
	if m.width < 1 {
		return maxListWidth
	}
	return contentWidth(m.width)
}

func (m model) View() tea.View {
	if m.quitting && m.attach {
		return tea.NewView("")
	}
	if m.width == 0 || m.height == 0 {
		return tea.NewView("Loading...")
	}

	var b strings.Builder
	visible := visibleCount(m.height)
	listWidth := m.contentWidth()
	items := m.filteredSessions()

	b.WriteString(m.headerView())
	b.WriteString("\n\n")

	if m.loading && len(items) == 0 {
		b.WriteString(formatLoadingBody(visible, "Loading sessions..."))
	} else {
		listBody := renderListFrame(
			items,
			m.cursor,
			visible,
			listWidth,
			listRenderOpts{showCursor: true},
			formatSessionEntry,
		)
		b.WriteString(listBody)
	}

	content := strings.TrimSuffix(b.String(), "\n")

	if cols := previewCols(m.width); m.splitActive() && cols > 0 {
		list := lipgloss.NewStyle().
			Width(listWidth).
			MaxWidth(listWidth).
			Render(content)
		preview := renderPreviewPane(
			m.previewContent,
			cols,
			visible,
			m.previewErr,
			m.previewName == "",
		)
		content = lipgloss.JoinHorizontal(lipgloss.Top, list, preview)
	}

	return tea.NewView(content)
}
