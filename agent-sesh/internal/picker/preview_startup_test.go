package picker

import (
	"testing"
)

func TestWindowSizeSchedulesPreview(t *testing.T) {
	for _, s := range sampleSessions() {
		invalidatePreviewCache(s.TmuxTarget)
	}

	m := testModel(sampleSessions())
	m.width = 120
	m.height = 24
	m.syncInputWidth()

	cmd := (&m).schedulePreview()
	if cmd == nil {
		t.Fatal("expected preview command when terminal is sized")
	}
}
