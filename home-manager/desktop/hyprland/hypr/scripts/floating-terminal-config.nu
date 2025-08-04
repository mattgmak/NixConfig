#! /usr/bin/env nu

let dir_cache_file = $"($env.HOME)/.cache/floating-terminal"

def get_dir_cache_path [] {
    if not ($dir_cache_file | path exists) {
        return $"($env.HOME)"
    }
    return (cat $dir_cache_file)
}

let dir = get_dir_cache_path
cd $dir
echo $dir
$env.config.hooks.pre_prompt = $env.config.hooks.pre_prompt | append {
    let new_dir = pwd
    $new_dir | save -f $dir_cache_file
}
