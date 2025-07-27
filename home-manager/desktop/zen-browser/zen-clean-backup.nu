#!/usr/bin/env nu

let chrome_dir = $"($env.HOME)/.zen/GoofyZen/chrome"

def get_backup_paths [dir] {
  let items = ls -a $dir
#   return an array of paths that contains .hm-backup
  let files = $items | where type == "file"
  let backup_paths = $files | where name =~ ".hm-backup"
  print $"Found ($backup_paths | length) backup files in ($dir)"
  $backup_paths | each { |path| print $"($path.name)" }
  let dir_paths = $items | where type == "dir"
  print $"Found ($dir_paths | length) directories in ($dir)"
  $dir_paths | each { |path| print $"($path.name)" }
  let recursive_backup_paths = $dir_paths | each { |path| get_backup_paths $path.name } | flatten
  $recursive_backup_paths | each { |path| print $"($path.name)" }
  return [ ...$backup_paths, ...$recursive_backup_paths ]
}

let backup_paths = get_backup_paths $chrome_dir
print $"Found ($backup_paths | length) backup files"
for path in $backup_paths {
  print $"($path)"
}
print $"What to do with backup files? \(delete [d]/copy over [c]/ignore [I]\)"
let answer = (input)
if $answer == "d" {
  for path in $backup_paths {
    print $"Removing ($path.name)"
    rm -r $path.name
  }
}
if $answer == "c" {
  let target_dir = $"($env.HOME)/NixConfig/home-manager/desktop/zen-browser/chrome"
  for path in $backup_paths {
    let subpath = $path.name | split row "/chrome/" | get 1 | split row ".hm-backup" | get 0
    let target_path = $"($target_dir)/($subpath)"
    print $"Copying ($path.name) to ($target_path)"
    cp -r $path.name $target_path
  }
}
