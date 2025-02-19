# Function to extract plugin info from Nix file
def extract_plugin_info [plugin_name: string] {
    let nix_file = $"plugins/($plugin_name).nix"
    if not ($nix_file | path exists) {
        echo $"Error: Plugin file ($nix_file) not found"
        exit 1
    }

    let content = (open $nix_file)
    let lines = ($content | lines)

    # Detect fetcher type
    let is_github = ($lines | any { |line| $line =~ "fetchFromGitHub" })
    let is_git = ($lines | any { |line| $line =~ "fetchgit" })

    # Extract values based on fetcher type
    let info = if $is_github {
        # Extract GitHub-specific values
        let owner = ($lines | find "owner = " | first | str replace -r ".*\"(.*)\".*" "$1" | str trim)
        let repo = ($lines | find "repo = " | first | str replace -r ".*\"(.*)\".*" "$1" | str trim)
        {
            type: "github",
            owner: $owner,
            repo: $repo,
            url: $"https://github.com/($owner)/($repo).git"
        }
    } else if $is_git {
        # Extract Git URL
        let url = ($lines | find "url = " | first | str replace -r ".*\"(.*)\".*" "$1" | str trim)
        {
            type: "git",
            url: $url,
            repo: ($url | str replace ".git$" "" | split row "/" | last)
        }
    } else {
        echo "Error: Unknown fetcher type in Nix file"
        exit 1
    }

    # Handle case where rev and hash are not yet set
    let current_rev = if ($lines | find "rev = " | is-empty) { "main" } else { ($lines | find "rev = " | first | str replace -r ".*\"(.*)\".*" "$1" | str trim) }
    let current_hash = if ($lines | find "hash = " | is-empty) { "" } else { ($lines | find "hash = " | first | str replace -r ".*\"(.*)\".*" "$1" | str trim) }
    let current_version = if ($lines | find "version = " | is-empty) { "" } else { ($lines | find "version = " | first | str replace -r ".*\"(.*)\".*" "$1" | str trim) }

    $info | merge {
        current_rev: $current_rev,
        current_hash: $current_hash,
        current_version: $current_version
    }
}

# Function to update Nix file with new values
def update_nix_file [plugin_name: string, new_rev: string, new_hash: string] {
    let nix_file = $"plugins/($plugin_name).nix"
    let new_version = $"unstable-" + (date now | format date "%Y-%m-%d")
    let lines = (open $nix_file | lines)

    let updated = ($lines | each { |line|
        if ($line | str contains 'rev = "') {
            $line | str replace -r '".*"' $"\"($new_rev)\""
        } else if ($line | str contains 'version = "') {
            $line | str replace -r '".*"' $"\"($new_version)\""
        } else if ($line | str contains 'hash = ') {
            # Handle both single-line and multi-line patterns
            $line | str replace -r 'hash = .*' $"hash = \"($new_hash)\";"
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
        if $info.type == "github" {
            $"
[($name)]
src.git = \"($info.url)\"
fetch.github = \"($info.owner)/($info.repo)\"
"
        } else {
            $"
[($name)]
src.git = \"($info.url)\"
src.branch = \"master\"
"
        }
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

# Function to get latest git info
def get_git_info [url: string] {
    # Create a temporary directory
    mkdir plugins/update/_sources
    cd plugins/update/_sources

    # Clone the repository
    git clone $url temp
    cd temp

    # Get the latest commit hash
    let latest_rev = (git rev-parse HEAD | str trim)

    # Get the hash
    let latest_hash = (nix hash path . --type sha256 | str trim)

    # Cleanup
    cd ../..
    rm -rf _sources

    {
        rev: $latest_rev,
        hash: $latest_hash
    }
}

# Function to update a single plugin
def update_plugin [plugin_name: string] {
    print $"\nChecking ($plugin_name)..."

    # Extract current info from Nix file
    let info = (extract_plugin_info $plugin_name)

    # Get latest info based on type
    let result = if $info.type == "github" {
        # Parse nvfetcher output for GitHub repos
        let nvfetcher_result = (parse_nvfetcher_output $plugin_name)
        {
            latest_rev: $nvfetcher_result.version,
            latest_hash: $nvfetcher_result.src.sha256
        }
    } else {
        # Use git commands for other git repos
        let git_info = (get_git_info $info.url)
        {
            latest_rev: $git_info.rev,
            latest_hash: $git_info.hash
        }
    }

    let new_version = $"unstable-" + (date now | format date "%Y-%m-%d")

    print $"\n($info.repo) Plugin:"
    print $"Current version:  ($info.current_version)"
    print $"Current revision: ($info.current_rev)"
    print $"Current hash:     ($info.current_hash)"
    print $"Latest revision:  ($result.latest_rev)"
    print $"Latest hash:      ($result.latest_hash)"
    print $"New version:      ($new_version)"

    if $info.current_rev == $result.latest_rev {
        print $"\n[✓] Plugin is up to date"
        false  # Return false to indicate no update was needed
    } else {
        print $"\n[!] Update available!"

        # Update the Nix file
        update_nix_file $plugin_name $result.latest_rev $result.latest_hash
        print $"\n[✓] Updated ($plugin_name).nix with new values:"
        print $"version = \"($new_version)\";"
        print $"rev = \"($result.latest_rev)\";"
        print $"hash = \"($result.latest_hash)\";"
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

    # Create temporary nvfetcher config only for GitHub plugins
    let github_plugins = ($plugin_names | each { |name|
        let info = (extract_plugin_info $name)
        if $info.type == "github" { $name } else { null }
    } | compact)

    if not ($github_plugins | is-empty) {
        create_nvfetcher_config $github_plugins
        nvfetcher --build-dir plugins/update/_sources -c plugins/update/nvfetcher.toml
    }

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
    rm -rf plugins/update
}
