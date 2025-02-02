#!/usr/bin/env zsh

# ------------------------------------------------------------------------
# macos-system-settings-zsh-completions.plugin.zsh
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

    local raw_ids
    raw_ids=($(_get_system_settings))  # e.g. com.apple.Displays-Settings.extension, etc.

    # We'll do a function to produce the same "label" we used in the completion:
    local transform_raw_to_label() {
      local tmp="$1"
      tmp="${tmp#com.apple.}"          # remove leading com.apple.
      tmp="${tmp%.extension}"          # remove trailing .extension
      echo "$tmp"
    }

    # Try to match the user input against each label
    local matched_raw=""

    # 1) Attempt exact, case-insensitive
    for r in "${raw_ids[@]}"; do
        local label="$(transform_raw_to_label "$r")"
        if [[ "${label:l}" == "${panel:l}" ]]; then
            matched_raw="$r"
            break
        fi
    done

    # 2) If no exact match found, attempt a partial/substring match
    if [[ -z "$matched_raw" ]]; then
        for r in "${raw_ids[@]}"; do
            local label="$(transform_raw_to_label "$r")"
            if [[ "${label:l}" == *"${panel:l}"* ]]; then
                matched_raw="$r"
                break
            fi
        done
    fi

    # If still empty, no match was found
    if [[ -z "$matched_raw" ]]; then
        echo "Failed to find settings panel: $panel"
        echo "Available panels:"
        _get_system_settings | sed 's/^/  /'
        return 1
    fi

    # Now open matched_raw
    if (( osver >= 15 )); then
        open "x-apple.systempreferences:$matched_raw"
    else
        # old macOS fallback
        open -b com.apple.systempreferences \
           "$LEGACY_SETTINGS_PATH/${matched_raw}.prefPane"
    fi
}

# completion function
#compdef settings
#compdef settings
_macos_system_settings() {
  local -a panels
  local raw label

  while IFS= read -r raw; do
    # If raw == "com.apple.Displays-Settings.extension", produce "Displays-Settings"
    label="$raw"
    label="${label#com.apple.}"          # remove leading "com.apple."
    label="${label%.extension}"          # remove trailing ".extension" if present
    # (you can also remove "systempreferences." or other patterns if needed)

    # Provide "label" as the typed completion, 
    # and a short help text "Open <label>" or "Open <raw>," your choice:
    # The left part before the colon is what's inserted on the command line,
    # The right part after the colon is the short help text.
    panels+=("$label:Open $label")
  done < <(_get_system_settings)

  # Now let Zsh do its standard prefix matching (e.g. "disp" matches "Displays-Settings").
  _describe -V 'settings panel' panels
}