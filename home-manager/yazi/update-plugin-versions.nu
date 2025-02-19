# Function to extract plugin info from Nix file
def extract_plugin_info [plugin_name: string] {
    let nix_file = $"plugins/($plugin_name).nix"
    if not ($nix_file | path exists) {
        echo $"Error: Plugin file ($nix_file) not found"
        exit 1
    }

    let content = (open $nix_file)
    let lines = ($content | lines)

    # Extract values using Nushell's built-in commands
    let owner = ($lines | find "owner = " | first | str replace -r ".*\"(.*)\".*" "$1" | str trim)
    let repo = ($lines | find "repo = " | first | str replace -r ".*\"(.*)\".*" "$1" | str trim)
    let current_rev = ($lines | find "rev = " | first | str replace -r ".*\"(.*)\".*" "$1" | str trim)
    let current_hash = ($lines | find "hash = " | first | str replace -r ".*\"(.*)\".*" "$1" | str trim)
    let current_version = ($lines | find "version = " | first | str replace -r ".*\"(.*)\".*" "$1" | str trim)

    {
        owner: $owner,
        repo: $repo,
        current_rev: $current_rev,
        current_hash: $current_hash,
        current_version: $current_version
    }
}

# Function to update Nix file with new values
def update_nix_file [plugin_name: string, new_rev: string, new_hash: string] {
    let nix_file = $"plugins/($plugin_name).nix"
    let content = (open $nix_file | lines)
    let new_version = $"unstable-" + (date now | format date "%Y-%m-%d")

    # Update the values while preserving formatting
    let updated = ($content | each { |line|
        if ($line | str contains "rev = ") {
            $line | str replace -r "\".*\"" $"\"($new_rev)\""
        } else if ($line | str contains "hash = ") {
            $line | str replace -r "\".*\"" $"\"($new_hash)\""
        } else if ($line | str contains "version = ") {
            $line | str replace -r "\".*\"" $"\"($new_version)\""
        } else {
            $line
        }
    })

    $updated | str join "\n" | save -f $nix_file
}

# Function to create temporary nvfetcher config
def create_nvfetcher_config [plugins: list<string>] {
    let config = ($plugins | each { |name|
        let info = (extract_plugin_info $name)
        $"
[($name)]
src.git = \"https://github.com/($info.owner)/($info.repo).git\"
fetch.github = \"($info.owner)/($info.repo)\"
"
    } | str join "\n")

    mkdir plugins/update
    $config | save -f plugins/update/nvfetcher.toml
}

# Function to wait for file to exist
def wait_for_file [file_path: string, max_attempts: int = 30] {
    mut attempts = 0
    while (not ($file_path | path exists)) and ($attempts < $max_attempts) {
        sleep 1sec
        $attempts = $attempts + 1
    }

    if (not ($file_path | path exists)) {
        echo $"Error: Timeout waiting for ($file_path) after ($max_attempts) seconds"
        exit 1
    }
}

# Function to parse nvfetcher output
def parse_nvfetcher_output [plugin_name: string] {
    let json_file = "plugins/update/_sources/generated.json"
    wait_for_file $json_file

    let content = (cat $json_file)
    $content | from json | get $plugin_name
}

# Function to update a single plugin
def update_plugin [plugin_name: string] {
    print $"\nChecking ($plugin_name)..."

    # Extract current info from Nix file
    let info = (extract_plugin_info $plugin_name)

    # Parse the results
    let result = (parse_nvfetcher_output $plugin_name)
    let latest_rev = $result.version
    let latest_hash = $result.src.sha256
    let new_version = $"unstable-" + (date now | format date "%Y-%m-%d")

    print $"\n($info.repo) Plugin:"
    print $"Current version:  ($info.current_version)"
    print $"Current revision: ($info.current_rev)"
    print $"Current hash:     ($info.current_hash)"
    print $"Latest revision:  ($latest_rev)"
    print $"Latest hash:      ($latest_hash)"
    print $"New version:      ($new_version)"

    if $info.current_rev == $latest_rev {
        print $"\n[✓] Plugin is up to date"
        false  # Return false to indicate no update was needed
    } else {
        print $"\n[!] Update available!"

        # Update the Nix file
        update_nix_file $plugin_name $latest_rev $latest_hash
        print $"\n[✓] Updated ($plugin_name).nix with new values:"
        print $"version = \"($new_version)\";"
        print $"rev = \"($latest_rev)\";"
        print $"hash = \"($latest_hash)\";"
        true  # Return true to indicate an update was performed
    }
}

# Main function to update plugin versions
def main [
    ...plugin_names: string # Names of the plugins to update
] {
    if ($plugin_names | is-empty) {
        print "Error: Please provide at least one plugin name"
        exit 1
    }

    print $"Fetching latest versions for plugins: ($plugin_names | str join ', ')"

    # Create temporary nvfetcher config for all plugins
    create_nvfetcher_config $plugin_names

    # Run nvfetcher with custom build directory
    nvfetcher --build-dir plugins/update/_sources -c plugins/update/nvfetcher.toml

    # Update each plugin
    let updated_count = ($plugin_names | each { |name| update_plugin $name } | where { |x| $x == true } | length)

    # Summary
    if $updated_count == 0 {
        print "\n[✓] All plugins are up to date"
    } else if $updated_count == 1 {
        print "\n[✓] Updated 1 plugin"
    } else {
        print $"\n[✓] Updated ($updated_count) plugins"
    }

    # Cleanup
    rm plugins/update/nvfetcher.toml
    rm -rf plugins/update/_sources
}
