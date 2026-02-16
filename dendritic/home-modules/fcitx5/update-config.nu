# Update fcitx5 config
let files = (
    ls ~/.config/fcitx5/*
    | where name !~ '.*\.hm-backup$'
    | get name
)

print "Copying the following files:"
$files | each { |it| print $"  ($it)" }
print ""

$files | each { |it|
    cp $it ~/NixConfig/home-manager/fcitx5/config/ -r
    print $"Copied: ($it)"
} | ignore
