# Extra config

def --env y [...args] {
	let tmp = (mktemp -t "yazi-cwd.XXXXXX")
	yazi ...$args --cwd-file $tmp
	let cwd = (open $tmp)
	if $cwd != "" and $cwd != $env.PWD {
 		z $cwd
	}
	rm -fp $tmp
}

alias s = sesh connect (sesh list --icons | fzf --ansi)
