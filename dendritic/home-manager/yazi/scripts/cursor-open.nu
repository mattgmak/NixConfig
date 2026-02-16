#!/usr/bin/env nu

def main [...paths: string] {
  let quoted_paths = $paths | each { |f| $"\"($f)\"" }

  # let tmp = (^mktemp /tmp/yazi-cursor-debug.XXXXXX.log | str trim)
  # let args_text = ($quoted_paths | str join " ")
  # $"cursor -g $args_text\n" | save --append $tmp

  ^cursor -g ...$quoted_paths
}
