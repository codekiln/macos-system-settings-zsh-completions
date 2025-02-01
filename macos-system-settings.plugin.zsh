# Helper function to get available system settings
_get_system_settings() {
    # Get all bundles in System Settings
    local settings_path="/System/Library/PreferencePanes"
    local settings_app="/System/Applications/System Settings.app/Contents/Resources/SystemSettings"
    
    # First try the modern System Settings (macOS Ventura and later)
    if [[ -d "$settings_app" ]]; then
        find "$settings_app" -name "*.extension" -exec basename {} .extension \; | \
            sed 's/com.apple.\(.*\)-Settings/\1/' | \
            tr '[:upper:]' '[:lower:]'
    # Fall back to older System Preferences
    elif [[ -d "$settings_path" ]]; then
        find "$settings_path" -name "*.prefPane" -exec basename {} .prefPane \; | \
            tr '[:upper:]' '[:lower:]'
    fi
}

# Define the main command
settings() {
    local panel="$1"
    if [[ -z "$panel" ]]; then
        echo "Usage: settings <panel-name>"
        return 1
    fi

    # Convert panel name to proper case and format
    panel=$(echo "$panel" | tr '[:upper:]' '[:lower:]')
    local extension="com.apple.${panel}-Settings.extension"
    
    # Try to open the settings panel
    if ! open "x-apple.systempreferences:${extension}" 2>/dev/null; then
        echo "Failed to open settings panel: $panel"
        echo "Available panels:"
        _get_system_settings | sed 's/^/  /'
        return 1
    fi
} 