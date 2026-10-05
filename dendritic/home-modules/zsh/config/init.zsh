# nu ports with no upstream integration.

# ── Ctrl-O: edit the current command line in $EDITOR ───────────────────────────
# `edit-command-line` is the autoloadable function bundled with zsh (not the
# optional zsh/edit module this build lacks).
autoload -Uz edit-command-line
zle -N edit-command-line

bindkey -M viins '^O' edit-command-line

if (( $+functions[zvm_bindkey] )); then
  zvm_bindkey vicmd '^O' edit-command-line
  zvm_bindkey visual '^O' edit-command-line
fi

# ── Ctrl-Right: accept the next word of the inline suggestion (nu parity) ─────
# Both widgets are in ZSH_AUTOSUGGEST_PARTIAL_ACCEPT_WIDGETS, so the key accepts
# what the cursor crosses (Right still takes the whole hint); vi's `E` because
# vi-forward-word stops on the word's first char; zvm_bindkey because
# zsh-vi-mode's "nex" readkey engine ignores plain bindkey.
if (( $+functions[zvm_bindkey] )); then
  zvm_bindkey viins '^[[1;5C' forward-word
  zvm_bindkey vicmd '^[[1;5C' vi-forward-blank-word-end
else
  bindkey -M viins '^[[1;5C' forward-word
fi

# ── nvim with a persistent session (nu: def --env v) ─────────────────────────
function v {
  NVIM_PERSIST_SESSION=1 command nvim "$@"
}
