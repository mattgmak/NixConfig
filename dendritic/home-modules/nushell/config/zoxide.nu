# Guarded zoxide init for nushell.
# PWD hook only on interactive shells — skip on pi/lean-ctx `nu -c` spawns (orphan nu +
# zoxide env_change hook can spin at ~80% CPU and hammer db.zo scores).
# Opt out per-invocation: PI_NO_ZOXIDE=1 nu -c '...'
#
# `z`/`zi` defs must live outside the guard: exports inside `if` blocks are not visible
# to custom defs defined later in config.nu (e.g. yazi `y` wrapper calling `z $cwd`).

export def --env --wrapped __zoxide_z [...rest: directory] {
  let path = match $rest {
    [] => {'~'},
    [ '-' ] => {'-'},
    [ $arg ] if ($arg | path expand | path type) == 'dir' => {$arg}
    _ => {
      ^zoxide query --exclude $env.PWD -- ...$rest | str trim -r -c "\n"
    }
  }
  cd $path
}

export def --env --wrapped __zoxide_zi [...rest: string] {
  cd $'(^zoxide query --interactive -- ...$rest | str trim -r -c "\n")'
}

export alias z = __zoxide_z
export alias zi = __zoxide_zi

if $nu.is-interactive and ($env.PI_NO_ZOXIDE? != "1") {
  export-env {
    $env.config = (
      $env.config?
      | default {}
      | upsert hooks { default {} }
      | upsert hooks.env_change { default {} }
      | upsert hooks.env_change.PWD { default [] }
    )
    let __zoxide_hooked = (
      $env.config.hooks.env_change.PWD | any { try { get __zoxide_hook } catch { false } }
    )
    if not $__zoxide_hooked {
      $env.config.hooks.env_change.PWD = ($env.config.hooks.env_change.PWD | append {
        __zoxide_hook: true,
        code: {|_, dir| ^zoxide add -- $dir}
      })
    }
  }
}
