package picker

import (
	"sync"

	"github.com/mattgmak/agent-sesh/internal/registry"
)

type previewCacheEntry struct {
	revision string
	content  string
	err      error
}

var previewCache sync.Map // tmux target -> previewCacheEntry

// previewRevision keys cached pane captures; refresh only when agent activity changes.
func previewRevision(session registry.Session) string {
	return string(session.Status) + "\x00" + session.ToolName + "\x00" + session.UpdatedAt
}

func getPreviewCache(target, revision string) (content string, err error, ok bool) {
	if target == "" || revision == "" {
		return "", nil, false
	}
	raw, ok := previewCache.Load(target)
	if !ok {
		return "", nil, false
	}
	entry := raw.(previewCacheEntry)
	if entry.revision != revision {
		return "", nil, false
	}
	return entry.content, entry.err, true
}

func getPreviewCacheAny(target string) (content string, err error, revision string, ok bool) {
	if target == "" {
		return "", nil, "", false
	}
	raw, ok := previewCache.Load(target)
	if !ok {
		return "", nil, "", false
	}
	entry := raw.(previewCacheEntry)
	return entry.content, entry.err, entry.revision, true
}

func setPreviewCache(target, revision, content string, err error) {
	if target == "" || revision == "" {
		return
	}
	previewCache.Store(target, previewCacheEntry{
		revision: revision,
		content:  content,
		err:      err,
	})
}

func invalidatePreviewCache(target string) {
	if target == "" {
		return
	}
	previewCache.Delete(target)
}
