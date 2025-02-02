# Path to System Settings
settings_path="/System/Library/PreferencePanes"

# Helper function to get available system settings
_get_system_settings() {
    if [[ ! -d "$settings_path" ]]; then
        echo "Error: Could not find System Settings directory" >&2
        return 1
    fi

    # List all preference panes, strip .prefPane extension
    find "$settings_path" -name "*.prefPane" -exec basename {} .prefPane \;
}

# Define the main command
settings() {
    local panel="$1"
    if [[ -z "$panel" ]]; then
        _get_system_settings
        return 0
    fi

    # Find the matching preference pane
    local found_pane=$(find "$settings_path" -name "*.prefPane" -exec basename {} .prefPane \; | \
        grep -i "^${panel}$")

    if [[ -n "$found_pane" ]]; then
        # Try different methods in order until one works
        
        # 1. Try direct bundle open
        # technique credit: https://gist.github.com/rmcdongit/f66ff91e0dad78d4d6346a75ded4b751
        if open -b com.apple.systempreferences "$settings_path/${found_pane}.prefPane" 2>/dev/null; then
            return 0
        fi
        
        # 2. Try different URL schemes
        if open "x-apple.systempreferences:com.apple.preference.${found_pane}" 2>/dev/null; then
            return 0
        elif open "x-apple.systempreferences:com.apple.${found_pane}.extension" 2>/dev/null; then
            return 0
        elif open "x-apple.systempreferences:com.apple.${found_pane}-Settings.extension" 2>/dev/null; then
            return 0
        fi
    fi

    echo "Failed to open settings panel: $panel"
    echo "Available panels:"
    _get_system_settings | sed 's/^/  /'
    return 1
} 