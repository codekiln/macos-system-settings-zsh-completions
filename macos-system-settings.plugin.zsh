#!/usr/bin/env zsh

# ------------------------------------------------------------------------
# macos-system-settings.plugin.zsh
#
# This plugin provides a `settings` command for opening System Settings 
# (Ventura+), or System Preferences (older macOS). For macOS 15, we read 
# discovered panel IDs from local text files (v15/).
# ------------------------------------------------------------------------

# Directory of this plugin file. Allows reading files relative to the plugin.
# This zsh trick uses the extended variable forms to get the full directory path.
PLUGIN_DIR="${0:A:h}"

# Where we store the known macOS 15 identifiers
BUNDLE_FILE_15="$PLUGIN_DIR/v15/macOS_System_Settings_bundle_identifiers.txt"
UNCONFIRMED_FILE_15="$PLUGIN_DIR/v15/unconfirmed_preference_panels.txt"

# For older macOS (pre-15) we still rely on .prefPane
LEGACY_SETTINGS_PATH="/System/Library/PreferencePanes"

# ------------------------------------------------------------------------
# Helper: Returns the *major* macOS version (e.g., 14, 15).
# ------------------------------------------------------------------------
_get_macos_version() {
    local version
    version="$(sw_vers -productVersion)"
    echo "${version%%.*}"
}

# ------------------------------------------------------------------------
# Gather "modern" settings identifiers for macOS 15.
# Returns them as lines on stdout.
# ------------------------------------------------------------------------
_get_macos_15_identifiers() {
    local lines=()

    if [[ -f "$BUNDLE_FILE_15" ]]; then
        # "mapfile" or "read" to load lines into array
        while IFS= read -r line; do
            lines+="$line"
        done < "$BUNDLE_FILE_15"
    fi
    
    if [[ -f "$UNCONFIRMED_FILE_15" ]]; then
        while IFS= read -r line; do
            lines+="$line"
        done < "$UNCONFIRMED_FILE_15"
    fi

    # Return them sorted & unique in case there's overlap
    printf '%s\n' "${lines[@]}" | sort -u
}

# ------------------------------------------------------------------------
# MAIN function to get a list of *available* "panels" 
# that the user might type for completion.
# ------------------------------------------------------------------------
_get_system_settings() {
    local osver="$(_get_macos_version)"

    if (( osver >= 15 )); then
        # For macOS 15, read from text files
        _get_macos_15_identifiers
    else
        # For older OS versions, just list the .prefPane files
        if [[ -d "$LEGACY_SETTINGS_PATH" ]]; then
            find "$LEGACY_SETTINGS_PATH" -name "*.prefPane" -exec basename {} .prefPane \; | sort
        else
            echo "Error: Could not find System Settings directory" >&2
        fi
    fi
}

# ------------------------------------------------------------------------
# Debug helper (enabled if DEBUG_MAC_SYSTEM_SETTINGS is set).
# ------------------------------------------------------------------------
_debug() {
    [[ -n "$DEBUG_MAC_SYSTEM_SETTINGS" ]] && echo "$@" >&2
}

# ------------------------------------------------------------------------
# The 'settings' command
#
# Usage: settings [panelName]
# ------------------------------------------------------------------------
settings() {
    local panel="$1"
    local osver="$(_get_macos_version)"

    # If user didn't specify a panel, just list what's available
    if [[ -z "$panel" ]]; then
        _get_system_settings
        return 0
    fi

    if (( osver >= 15 )); then
        # On macOS 15, we’ll do partial or exact match against the lines from the text files.
        local all_ids
        all_ids=($(_get_macos_15_identifiers))

        # 1) Try exact match
        local matched_id
        for id in "${all_ids[@]}"; do
            if [[ "$id" == "$panel" ]]; then
                matched_id="$id"
                break
            fi
        done

        # 2) If we didn't find an exact match, do a case-insensitive partial match.
        if [[ -z "$matched_id" ]]; then
            for id in "${all_ids[@]}"; do
                # Convert both sides to lowercase and see if it "contains" the user's input
                if [[ "${id:l}" == *"${panel:l}"* ]]; then
                    matched_id="$id"
                    break
                fi
            done
        fi

        if [[ -n "$matched_id" ]]; then
            _debug "Opening: x-apple.systempreferences:${matched_id}"
            open "x-apple.systempreferences:${matched_id}"
            return 0
        fi
    else
        # For older macOS: search the .prefPane by exact or partial name
        if [[ -d "$LEGACY_SETTINGS_PATH" ]]; then
            # Attempt to find a prefPane whose base name matches panel
            local found_pane
            found_pane="$(
                find "$LEGACY_SETTINGS_PATH" -name "*.prefPane" -exec basename {} .prefPane \; \
                  | grep -i "^${panel}$" \
                  | head -n 1
            )"

            # If no exact match, do partial
            if [[ -z "$found_pane" ]]; then
                found_pane="$(
                    find "$LEGACY_SETTINGS_PATH" -name "*.prefPane" -exec basename {} .prefPane \; \
                      | grep -i "${panel}" \
                      | head -n 1
                )"
            fi

            if [[ -n "$found_pane" ]]; then
                _debug "Opening legacy prefPane: $found_pane"
                open -b com.apple.systempreferences "$LEGACY_SETTINGS_PATH/${found_pane}.prefPane" 2>/dev/null \
                  && return 0
            fi
        fi
    fi

    # If we get here, we failed to find a matching panel
    echo "Failed to open settings panel: '$panel'"
    echo "Available panels:"
    _get_system_settings | sed 's/^/  /'
    return 1
}