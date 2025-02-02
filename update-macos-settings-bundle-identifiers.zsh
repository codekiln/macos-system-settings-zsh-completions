#!/usr/bin/env zsh
#
# macos-system-settings.plugin.zsh
#
# Provides a `settings` command and a function `_get_system_settings` that
# returns lines in the form "label|identifier". Example:
#   "Displays|com.apple.Displays-Settings.extension"
#   "Touch-ID|com.apple.Touch-ID-Settings.extension"
#

# Directory of this plugin, so we can load relative files
PLUGIN_DIR="${0:A:h}"

# Where we store the known macOS 15 identifiers
BUNDLE_FILE_15="$PLUGIN_DIR/v15/macOS_System_Settings_bundle_identifiers.txt"
UNCONFIRMED_FILE_15="$PLUGIN_DIR/v15/unconfirmed_preference_panels.txt"

LEGACY_SETTINGS_PATH="/System/Library/PreferencePanes"

# -----------------------------------------------------------
# Helper: Return major macOS version (14, 15, etc.)
# -----------------------------------------------------------
_get_macos_version() {
    local ver
    ver="$(sw_vers -productVersion)"
    echo "${ver%%.*}"
}

# -----------------------------------------------------------
# For macOS 15: read lines from the discovered text files
# and convert them into "label|identifier".
# -----------------------------------------------------------
_get_macos_15_identifiers() {
    local lines=()

    # read official ones
    if [[ -f "$BUNDLE_FILE_15" ]]; then
        while IFS= read -r line; do
            lines+="$line"
        done < "$BUNDLE_FILE_15"
    fi

    # read unconfirmed if you want them
    if [[ -f "$UNCONFIRMED_FILE_15" ]]; then
        while IFS= read -r line; do
            lines+="$line"
        done < "$UNCONFIRMED_FILE_15"
    fi

    # remove duplicates; we only want unique lines of "com.apple.XXXX"
    lines=(${(u)lines})

    # For each raw com.apple.* line, create a user-friendly label.
    # Output format: "LABEL|IDENTIFIER".
    local output=()
    for identifier in "${lines[@]}"; do
        local label="$identifier"

        # 1) Remove "com.apple."
        label="${label#com.apple.}"

        # 2) Remove possible leading "systempreferences."
        label="${label#systempreferences.}"

        # 3) Remove common suffix patterns:
        #    e.g. "-Settings.extension", ".extension", "-Settings", "-extension"
        #    We'll just chain multiple seds or one big one:
        label="$(echo "$label" \
          | sed 's/-Settings\.extension$//' \
          | sed 's/\.extension$//' \
          | sed 's/-Settings$//' \
          | sed 's/-extension$//')"

        # 4) Lowercase or keep as is? Some people prefer to keep the mixed case
        #    We could keep "Touch-ID" or "Touch-Id". Let's preserve the original casing.

        # Store in "LABEL|IDENTIFIER" format
        output+=("$label|$identifier")
    done

    # Sort by label
    # We'll do a custom sort that sorts by label only (before the pipe).
    # We can do that with `sort -t'|' -k1,1`.
    # But zsh's builtin sort might not have that. Let's just do:
    printf '%s\n' "${output[@]}" | sort -t'|' -k1,1 
}

# -----------------------------------------------------------
# For older macOS: list prefPane names.
# We'll just output "PaneName|PaneName" to keep it consistent.
# -----------------------------------------------------------
_get_macos_legacy_identifiers() {
    if [[ ! -d "$LEGACY_SETTINGS_PATH" ]]; then
        return
    fi

    # find .prefPane => output lines as "Displays|Displays", "Keyboard|Keyboard", etc.
    find "$LEGACY_SETTINGS_PATH" -name "*.prefPane" -exec basename {} .prefPane \; \
      | sort | uniq \
      | while read -r name; do
          echo "$name|$name"
        done
}

# -----------------------------------------------------------
# MAIN: Return lines of "LABEL|IDENTIFIER" for completion 
# and for the settings function to parse.
# -----------------------------------------------------------
_get_system_settings() {
    local osver="$(_get_macos_version)"

    if (( osver >= 15 )); then
        _get_macos_15_identifiers
    else
        _get_macos_legacy_identifiers
    fi
}

# -----------------------------------------------------------
# Debug
# -----------------------------------------------------------
_debug() {
    [[ -n "$DEBUG_MAC_SYSTEM_SETTINGS" ]] && echo "$@" >&2
}

# -----------------------------------------------------------
# The 'settings' command
#   Usage: settings [panelLabel]
# 
# We'll interpret the user's input as the "label" portion. 
# Then we find the matching "identifier" from _get_system_settings.
# -----------------------------------------------------------
settings() {
    local panel="$1"
    local osver="$(_get_macos_version)"

    # If no panel specified, just list the user-friendly labels
    if [[ -z "$panel" ]]; then
        # Print them in one column, showing label only
        _get_system_settings | while IFS='|' read -r label identifier; do
            echo "$label"
        done
        return 0
    fi

    local -a entries
    entries=($(_get_system_settings))

    local matched_identifier=""
    local matched_label=""

    # 1) Try exact match on the label (case-insensitive).
    for e in "${entries[@]}"; do
        local label="${e%%|*}"
        local identifier="${e#*|}"
        
        if [[ "${label:l}" == "${panel:l}" ]]; then
            matched_label="$label"
            matched_identifier="$identifier"
            break
        fi
    done

    # 2) If no exact match, do partial match (case-insensitive substring).
    if [[ -z "$matched_identifier" ]]; then
        for e in "${entries[@]}"; do
            local label="${e%%|*}"
            local identifier="${e#*|}"

            if [[ "${label:l}" == *"${panel:l}"* ]]; then
                matched_label="$label"
                matched_identifier="$identifier"
                break
            fi
        done
    fi

    if [[ -z "$matched_identifier" ]]; then
        echo "Failed to open settings panel: '$panel'"
        echo "Available panels:"
        _get_system_settings | while IFS='|' read -r lbl ident; do
            echo "  $lbl"
        done
        return 1
    fi

    # Now open the matched identifier
    if (( osver >= 15 )); then
        # For macOS 15, it's "com.apple.*"
        _debug "Opening: x-apple.systempreferences:$matched_identifier"
        open "x-apple.systempreferences:$matched_identifier"
    else
        # For older macOS, the identifier is the .prefPane name
        _debug "Opening legacy prefPane: $matched_identifier"
        open -b com.apple.systempreferences "$LEGACY_SETTINGS_PATH/${matched_identifier}.prefPane" 2>/dev/null
    fi
}

# End of file