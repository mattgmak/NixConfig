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
	modeFilter
	modeRename
)

const (
	refreshInterval = 3 * time.Second
	previewDebounce = 60 * time.Millisecond
)

// Nerd Font / MDI symbols (require a Nerd Font in the terminal).
const (
	iconIdle     = "\U000F0765" // 󰝥 circle-outline
	iconWorking  = "\U000F095F" // 󰥟 run
	iconToolCall = "\U000F08BB" // 󰢻 hammer-screwdriver
	iconWaiting  = "\U000F09FA" // 󰧺 clock-outline
	iconFolder   = "\U000F024B" // 󰉋 folder-outline
	iconBranch   = "\U000F062C" // 󰘬 source-branch
	iconAgent    = "\U000F06B8" // 󰚩 robot
	iconAttach   = "\U000F0C5B" // 󰱝 link-variant
	iconKillPane = "\U000F0A7A" // 󰩺 close-box-outline
	iconKillSess = "\U000F0B7E" // 󰭾 delete-forever
	iconNewWin   = "\U000F02E0" // 󰋠 window-plus (approx)
	iconFilter   = "\U000F0349" // 󰍉 magnify
	iconRename   = "\U000F0648" // 󰙈 rename-box
	iconQuit     = "\U000F05AD" // 󰖭 exit-to-app
)

type tickMsg struct{}

type previewFetchMsg struct {
	seq int
	id  string
}

type previewLoadedMsg struct {
	seq     int
	id      string
	content string
	err     error
}

type model struct {
	sessions       []registry.Session
	cursor         int
	listOffset     int
	selectedID     string
	filter         textinput.Model
	rename         textinput.Model
	mode           mode
	width          int
	height         int
	registry       string
	statusLine     string
	quitting       bool
	attach         bool
	previewContent string
	previewErr     error
	previewPending string
	previewName    string
	previewSeq     int
}

func Run() error {
	initTerminalColors()

	path, err := registry.DefaultPath()
	if err != nil {
		return err
	}

	sessions, err := registry.Load(path)
	if err != nil {
		return err
	}
	sessions = pruneAndPersist(path, sessions)
	if len(sessions) == 0 {
		return nil
	}

	filter := textinput.New()
	filter.Prompt = "⚡  "
	filter.Placeholder = "filter sessions"
	filter.CharLimit = 120

	rename := textinput.New()
	rename.Prompt = iconRename + " "
	rename.CharLimit = 120

	m := model{
		sessions: sessions,
		filter:   filter,
		rename:   rename,
		registry: path,
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
	pruned := registry.PruneMissingPanes(sessions, tmux.PaneExists)
	if len(pruned) != len(sessions) {
		if err := registry.Save(path, pruned); err == nil {
			return pruned
		}
	}
	return pruned
}

func (m model) Init() tea.Cmd {
	return tea.Batch(textinput.Blink, scheduleRefresh(), m.schedulePreview())
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
		m.listOffset = 0
		m.selectedID = ""
		return
	}

	if m.selectedID != "" {
		for i, session := range items {
			if session.ID == m.selectedID {
				m.cursor = i
				m.listOffset, _ = listWindow(m.cursor, m.listOffset, len(items), visibleCount(m.height))
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
	m.listOffset, _ = listWindow(m.cursor, m.listOffset, len(items), visibleCount(m.height))
}

func (m model) splitActive() bool {
	return len(m.filteredSessions()) > 0 && m.width >= previewMinWidth
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
		m.previewName, m.previewPending, m.previewContent, m.previewErr = "", "", "", nil
		return nil
	}

	id, ok := m.highlightedID()
	if !ok {
		m.previewSeq++
		m.previewName, m.previewPending, m.previewContent, m.previewErr = "", "", "", nil
		return nil
	}
	if id == m.previewName || id == m.previewPending {
		return nil
	}

	m.previewSeq++
	m.previewPending = id
	seq := m.previewSeq
	return tea.Tick(previewDebounce, func(time.Time) tea.Msg {
		return previewFetchMsg{seq: seq, id: id}
	})
}

func (m model) fetchPreview(seq int, id string) tea.Cmd {
	return func() tea.Msg {
		var target string
		for _, session := range m.sessions {
			if session.ID == id {
				target = session.TmuxTarget
				break
			}
		}
		if target == "" {
			return previewLoadedMsg{seq: seq, id: id, content: "", err: nil}
		}
		if !tmux.PaneExists(target) {
			return previewLoadedMsg{seq: seq, id: id, err: fmt.Errorf("pane %s is gone", target)}
		}
		content, err := tmux.CapturePane(target, 0)
		return previewLoadedMsg{seq: seq, id: id, content: content, err: err}
	}
}

func (m model) reload() model {
	sessions, err := registry.Load(m.registry)
	if err != nil {
		m.statusLine = err.Error()
		return m
	}
	m.sessions = pruneAndPersist(m.registry, sessions)
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
	m.listOffset, _ = listWindow(m.cursor, m.listOffset, len(items), visibleCount(m.height))
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
	case previewFetchMsg:
		if msg.seq != m.previewSeq {
			return m, nil
		}
		return m, m.fetchPreview(msg.seq, msg.id)

	case previewLoadedMsg:
		if msg.seq != m.previewSeq {
			return m, nil
		}
		m.previewPending = ""
		m.previewName = msg.id
		m.previewContent = msg.content
		m.previewErr = msg.err
		return m, nil

	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
		m.syncInputWidth()
		m.reconcileCursor()
		return m, nil

	case tickMsg:
		m = m.reload()
		if m.quitting {
			return m, tea.Quit
		}
		return m, tea.Batch(m.schedulePreview(), scheduleRefresh())

	case tea.KeyPressMsg:
		if m.mode == modeRename {
			switch msg.String() {
			case "esc":
				m.mode = modeNormal
				m.rename.SetValue("")
				m.statusLine = ""
				return m, nil
			case "enter":
				name := strings.TrimSpace(m.rename.Value())
				session, ok := m.selected()
				if !ok {
					m.mode = modeNormal
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
				return m, nil
			}
			var cmd tea.Cmd
			m.rename, cmd = m.rename.Update(msg)
			return m, cmd
		}

		if m.mode == modeFilter {
			switch msg.String() {
			case "esc":
				m.mode = modeNormal
				m.filter.SetValue("")
				m.filter.Blur()
				m.listOffset = 0
				m.reconcileCursor()
				return m, m.schedulePreview()
			case "enter":
				m.mode = modeNormal
				m.filter.Blur()
				return m, m.schedulePreview()
			}
			var cmd tea.Cmd
			m.filter, cmd = m.filter.Update(msg)
			m.listOffset = 0
			m.reconcileCursor()
			return m, tea.Batch(cmd, m.schedulePreview())
		}

		switch msg.String() {
		case "ctrl+c", "q", "esc":
			m.quitting = true
			return m, tea.Quit
		case "up", "k":
			m = m.setCursor(m.cursor + 1)
			return m, m.schedulePreview()
		case "down", "j":
			m = m.setCursor(m.cursor - 1)
			return m, m.schedulePreview()
		case "/":
			m.mode = modeFilter
			m.filter.Focus()
			m.syncInputWidth()
			return m, textinput.Blink
		case "enter":
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
			m = m.reload()
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
			m = m.reload()
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

func formatSessionLine(session registry.Session, width int) string {
	icon := statusLabelStyle(session.Status).Render(statusIcon(session.Status))
	title := normalStyle.Render(session.Title)
	if session.Branch != "" {
		title = dimStyle.Render(session.Branch) + " " + title
	}
	first := truncateLine(icon+" "+title, width)
	if session.Status == registry.StatusToolCall && session.ToolName != "" {
		indent := strings.Repeat(" ", lipgloss.Width(icon)+1)
		second := truncateLine(indent+matchStyle.Render(session.ToolName), width)
		return first + "\n" + second
	}
	return first
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
	return listCols(m.width, m.splitActive())
}

func (m model) View() tea.View {
	if m.quitting && m.attach {
		return tea.NewView("")
	}
	if m.width == 0 || m.height == 0 {
		return tea.NewView("Loading...")
	}

	var b strings.Builder
	b.WriteString(m.headerView())
	b.WriteString("\n\n")

	visible := visibleCount(m.height)
	lineWidth := m.contentWidth()
	items := m.filteredSessions()
	listBody := renderListFrame(
		items,
		m.cursor,
		m.listOffset,
		visible,
		lineWidth,
		listRenderOpts{showCursor: true},
		formatSessionLine,
	)
	b.WriteString(listBody)

	content := strings.TrimSuffix(b.String(), "\n")
	if cols := previewCols(m.width, m.splitActive()); cols > 0 {
		loading := m.previewName == ""
		list := lipgloss.NewStyle().
			Width(lineWidth).
			MaxWidth(lineWidth).
			Render(content)
		content = lipgloss.JoinHorizontal(
			lipgloss.Top,
			list,
			renderPreviewPane(m.previewContent, cols, visible, m.previewErr, loading),
		)
	}

	return tea.NewView(content)
}
