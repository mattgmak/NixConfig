package tmux

import "testing"

func TestParseTarget(t *testing.T) {
	tests := []struct {
		name   string
		in     string
		kind   TargetKind
		normal string
	}{
		{"empty", "", TargetUnknown, ""},
		{"whitespace", "  ", TargetUnknown, ""},
		{"pane id", "%42", TargetPane, "%42"},
		{"pane id trimmed", "  %42  ", TargetPane, "%42"},
		{"window target", "mysession:1.2", TargetWindow, "mysession:1.2"},
		{"session name", "agent-sesh", TargetSession, "agent-sesh"},
		{"session with dash", "my-agent-sesh", TargetSession, "my-agent-sesh"},
		{"window with colon only", "foo:0", TargetWindow, "foo:0"},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			kind, normalized := ParseTarget(tc.in)
			if kind != tc.kind || normalized != tc.normal {
				t.Errorf("ParseTarget(%q) = (%v, %q), want (%v, %q)", tc.in, kind, normalized, tc.kind, tc.normal)
			}
		})
	}
}

func TestPaneExistsEmpty(t *testing.T) {
	if PaneExists("") || PaneExists("   ") {
		t.Fatal("expected false for empty pane target")
	}
}
