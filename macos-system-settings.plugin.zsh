# Helper function to get macOS version
_get_macos_version() {
    sw_vers -productVersion | cut -d. -f1
}

# Modern settings links for macOS 15+
# source: https://macmost.com/mac-settings-links
# tested as of Nov 18, 2024 on macOS Sequoia 15.2
declare -A macos_settings_links=(
    ["Accessibility"]="com.apple.Accessibility"
    ["Appearance"]="com.apple.Appearance-Settings.extension"
    ["AppleAccount"]="com.apple.systempreferences.AppleIDSettings"
    ["AppleIntelligenceSiri"]="com.apple.Siri"
    ["Battery"]="com.apple.Battery"
    ["Bluetooth"]="com.apple.BluetoothSettings"
    ["ControlCenter"]="com.apple.ControlCenter"
    ["DesktopDock"]="com.apple.Desktop-Settings.extension"
    ["Displays"]="com.apple.Displays-Settings.extension"
    ["Family"]="com.apple.Family-Settings.extension"
    ["Focus"]="com.apple.Focus"
    ["GameCenter"]="com.apple.Game-Center"
    ["General"]="com.apple.systempreferences.GeneralSettings"
    ["General/About"]="com.apple.SystemProfiler.AboutExtension"
    ["General/AirPlayHandoff"]="com.apple.AirDrop-Handoff-Settings.extension"
    ["General/AppleCare"]="com.apple.Coverage-Settings.extension"
    ["General/AutoFillPasswords"]="com.apple.Passwords"
    ["General/DateTime"]="com.apple.Date-Time-Settings.extension"
    ["General/DeviceManagement"]="com.apple.Profiles-Settings.extension"
    ["General/LanguageRegion"]="com.apple.Localization-Settings.extension"
    ["General/LoginItemsExtensions"]="com.apple.LoginItems-Settings.extension"
    ["General/Sharing"]="com.apple.Sharing-Settings.extension"
    ["General/SoftwareUpdate"]="com.apple.Software-Update-Settings.extension"
    ["General/StartupDisk"]="com.apple.Startup-Disk-Settings.extension"
    ["General/Storage"]="com.apple.settings.Storage"
    ["General/TimeMachine"]="com.apple.Time-Machine-Settings.extension"
    ["General/TransferReset"]="com.apple.Transfer-Reset-Settings.extension"
    ["iCloud"]="com.apple.systempreferences.AppleIDSettings?iCloud"
    ["InternetAccounts"]="com.apple.Internet"
    ["Keyboard"]="com.apple.Keyboard"
    ["LockScreen"]="com.apple.Lock"
    ["Mouse"]="com.apple.Mouse"
    ["Network"]="com.apple.Network"
    ["Notifications"]="com.apple.Notifications"
    ["PrivacySecurity"]="com.apple.settings.PrivacySecurity.extension"
    ["ScreenSaver"]="com.apple.ScreenSaver-Settings.extension"
    ["ScreenTime"]="com.apple.Screen-Time"
    ["Sounds"]="com.apple.Sound"
    ["Spotlight"]="com.apple.Spotlight"
    ["TouchIDPassword"]="com.apple.Touch-ID-Settings.extension"
    ["Trackpad"]="com.apple.Trackpad"
    ["UsersGroups"]="com.apple.Users-Groups-Settings.extension"
    ["WalletApplePay"]="com.apple.Wallet"
    ["Wallpaper"]="com.apple.Wallpaper-Settings.extension"
    ["WiFi"]="com.apple.Wi-Fi-Settings.extension"
)

# Legacy path for older macOS versions
settings_path="/System/Library/PreferencePanes"

# Helper function to get available system settings
_get_system_settings() {
    if [[ $(_get_macos_version) -ge 15 ]]; then
        printf "%s\n" "${(@k)macos_settings_links}"
    else
        if [[ ! -d "$settings_path" ]]; then
            echo "Error: Could not find System Settings directory" >&2
            return 1
        fi
        find "$settings_path" -name "*.prefPane" -exec basename {} .prefPane \;
    fi
}

# Helper function for debug output
_debug() {
    [[ -n "$DEBUG_MAC_SYSTEM_SETTINGS" ]] && echo "$@" >&2
}

# Define the main command
settings() {
    local panel="$1"
    if [[ -z "$panel" ]]; then
        _get_system_settings
        return 0
    fi

    # For macOS 15+, use the known working links
    if [[ $(_get_macos_version) -ge 15 ]]; then
        # Try exact match first
        if [[ -n "${macos_settings_links[$panel]}" ]]; then
            _debug "Found exact match for '$panel'"
            _debug "Opening: x-apple.systempreferences:${macos_settings_links[$panel]}"
            open "x-apple.systempreferences:${macos_settings_links[$panel]}"
            return 0
        fi
        
        # Try case-insensitive partial match
        local found_key=""
        for key in "${(@k)macos_settings_links}"; do
            if [[ ${key:l} == *${panel:l}* ]]; then
                found_key="$key"
                _debug "Found partial match: '$found_key' for input '$panel'"
                break
            fi
        done

        if [[ -n "$found_key" ]]; then
            _debug "Opening: x-apple.systempreferences:${macos_settings_links[$found_key]}"
            open "x-apple.systempreferences:${macos_settings_links[$found_key]}"
            return 0
        fi
    else
        # Legacy method for older macOS versions
        local found_pane=$(find "$settings_path" -name "*.prefPane" -exec basename {} .prefPane \; | \
            grep -i "^${panel}$")

        if [[ -n "$found_pane" ]]; then
            # Try direct bundle open
            if open -b com.apple.systempreferences "$settings_path/${found_pane}.prefPane" 2>/dev/null; then
                return 0
            fi
        fi
    fi

    echo "Failed to open settings panel: $panel"
    echo "Available panels:"
    _get_system_settings | sed 's/^/  /'
    return 1
} 