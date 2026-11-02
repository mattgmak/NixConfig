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

# ── Vi: system clipboard paste and the `_` motion ────────────────────────────
# ZVM_SYSTEM_CLIPBOARD_ENABLED (zsh.nix) copies each yank and delete to the
# system clipboard. Plain `p` reads the zsh register only, so rebind it to read
# the clipboard first. An empty clipboard falls back to the register.
function vi_paste_system_after() {
  if [[ -n "$(zvm_clipboard_get)" ]]; then
    zvm_paste_clipboard_after
  else
    zvm_vi_put_after
  fi
}

function vi_paste_system_before() {
  if [[ -n "$(zvm_clipboard_get)" ]]; then
    zvm_paste_clipboard_before
  else
    zvm_vi_put_before
  fi
}

# zle has no `_` widget. Its vi-goto-column wants a numeric argument.
function vi_first_non_blank() {
  local pre=
  (( CURSOR > 0 )) && pre=${BUFFER[1,CURSOR]}
  local -i bol=1 i=0
  [[ $pre == *$'\n'* ]] && bol=$(( ${#${pre%$'\n'*}} + 2 ))
  local rest=${BUFFER[bol,-1]}
  rest=${rest%%$'\n'*}
  while (( i < ${#rest} )) && [[ ${rest[i+1]} == [[:blank:]] ]]; do
    (( i++ ))
  done
  local -i pos=$(( bol + i - 1 ))
  (( pos > ${#BUFFER} - 1 )) && pos=$(( ${#BUFFER} - 1 ))
  (( pos < 0 )) && pos=0
  CURSOR=$pos
}

# Nvim sends `c`, `C` and `x` to the black hole register (config.lua). zsh keeps
# the clipboard clean for `x` already. Void the copy for both change paths.
if (( $+functions[zvm_clipboard_copy_buffer] )); then
  typeset -g ZVM_CLIPBOARD_VOID=0
  functions[zvm_vi_change_orig]=$functions[zvm_vi_change]
  functions[zvm_vi_change_eol_orig]=$functions[zvm_vi_change_eol]
  functions[zvm_clipboard_copy_orig]=$functions[zvm_clipboard_copy_buffer]

  function zvm_vi_change() {
    ZVM_CLIPBOARD_VOID=1
    zvm_vi_change_orig "$@"
    ZVM_CLIPBOARD_VOID=0
  }

  function zvm_vi_change_eol() {
    ZVM_CLIPBOARD_VOID=1
    zvm_vi_change_eol_orig "$@"
    ZVM_CLIPBOARD_VOID=0
  }

  function zvm_clipboard_copy_buffer() {
    (( ZVM_CLIPBOARD_VOID )) && return
    zvm_clipboard_copy_orig "$@"
  }
fi

zle -N vi_paste_system_after
zle -N vi_paste_system_before
zle -N vi_first_non_blank

if (( $+functions[zvm_bindkey] )); then
  zvm_bindkey vicmd 'p' vi_paste_system_after
  zvm_bindkey vicmd 'P' vi_paste_system_before
  zvm_bindkey vicmd '_' vi_first_non_blank
fi
