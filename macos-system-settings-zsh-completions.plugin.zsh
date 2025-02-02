#!/usr/bin/env zsh
#
# macos-system-settings-zsh-completions.plugin.zsh
#
# A single-file plugin providing:
#   - The `settings` command for opening panels
#   - Completions that present "Displays-Settings" instead of "com.apple.Displays-Settings.extension"

# ------------------------------
#  1) Setup & Paths
# ------------------------------
# Directory of this plugin file (so we can read relative files).
PLUGIN_DIR="${0:A:h}"

# For macOS 15+ discovered IDs (raw lines like "com.apple.Displays-Settings.extension")
BUNDLE_FILE_15="$PLUGIN_DIR/v15/macOS_System_Settings_bundle_identifiers.txt"
UNCONFIRMED_FILE_15="$PLUGIN_DIR/v15/unconfirmed_preference_panels.txt"

# For older macOS .prefPane
LEGACY_SETTINGS_PATH="/System/Library/PreferencePanes"

# ------------------------------
#  2) OS version helper
# ------------------------------
_get_macos_version() {
    local version
    version="$(sw_vers -productVersion)"
    echo "${version%%.*}"
}

# ------------------------------
#  3) Build "label|rawID" for macOS 15
#    e.g. "Displays-Settings|com.apple.Displays-Settings.extension"
# ------------------------------
_get_macos_15_label_id_pairs() {
    local lines=()

    # Read official discovered lines
    if [[ -f "$BUNDLE_FILE_15" ]]; then
        while IFS= read -r line; do
            lines+="$line"
        done < "$BUNDLE_FILE_15"
    fi
    
    # Read unconfirmed lines (if any)
    if [[ -f "$UNCONFIRMED_FILE_15" ]]; then
        while IFS= read -r line; do
            lines+="$line"
        done < "$UNCONFIRMED_FILE_15"
    fi

    # Deduplicate and sort
    lines=($(printf '%s\n' "${lines[@]}" | sort -u))

    # Transform each raw "com.apple.Displays-Settings.extension" 
    # into "Displays-Settings|com.apple.Displays-Settings.extension"
    #   * remove leading "com.apple."
    #   * remove trailing ".extension"
    #   * keep the middle part, e.g. "Displays-Settings"
    local output=()
    for raw_id in "${lines[@]}"; do
        # strip prefix
        local label="${raw_id#com.apple.}"
        # remove ".extension" (if present)
        label="${label%.extension}"

        # e.g. raw_id = "com.apple.Displays-Settings.extension"
        #      label  = "Displays-Settings"
        output+=("$label|$raw_id")
    done

    # Print lines like "Displays-Settings|com.apple.Displays-Settings.extension"
    printf '%s\n' "${output[@]}"
}

# ------------------------------
#  4) Build "label|rawID" for older macOS
#     e.g. "Network|Network" for .prefPane name
# ------------------------------
_get_macos_legacy_label_id_pairs() {
    if [[ -d "$LEGACY_SETTINGS_PATH" ]]; then
        # Each prefPane yields e.g. "Network" or "Displays"
        local pane
        find "$LEGACY_SETTINGS_PATH" -name "*.prefPane" -exec basename {} .prefPane \; | sort -u |
        while IFS= read -r pane; do
            # We just output "Network|Network"
            echo "$pane|$pane"
        done
    fi
}

# ------------------------------
#  5) MASTER function: returns lines "Label|RawID" 
# ------------------------------
_get_system_settings() {
    local osver="$(_get_macos_version)"

    if (( osver >= 15 )); then
        _get_macos_15_label_id_pairs
    else
        _get_macos_legacy_label_id_pairs
    fi
}

# ------------------------------
#  6) The `settings` command
# ------------------------------
settings() {
    local user_input="$1"
    local osver="$(_get_macos_version)"

    # If no argument, just list all *labels* (the left side of "Label|RawID")
    if [[ -z "$user_input" ]]; then
        _get_system_settings | while IFS='|' read -r lbl raw; do
            echo "$lbl"
        done
        return 0
    fi

    # Load all "Label|RawID" lines
    local -a entries
    entries=($(_get_system_settings))

    # We'll do a two-pass match: exact (case-insensitive), then partial substring.
    local matched_raw=""
    local matched_label=""
    
    # pass 1: exact match ignoring case
    for e in "${entries[@]}"; do
        local lbl="${e%%|*}"
        local raw="${e#*|}"
        if [[ "${lbl:l}" == "${user_input:l}" ]]; then
            matched_label="$lbl"
            matched_raw="$raw"
            break
        fi
    done

    # pass 2: if still empty, do substring match (case-insensitive)
    if [[ -z "$matched_raw" ]]; then
        for e in "${entries[@]}"; do
            local lbl="${e%%|*}"
            local raw="${e#*|}"
            if [[ "${lbl:l}" == *"${user_input:l}"* ]]; then
                matched_label="$lbl"
                matched_raw="$raw"
                break
            fi
        done
    fi

    if [[ -z "$matched_raw" ]]; then
        echo "Failed to open settings panel: '$user_input'"
        echo "Available panels:"
        _get_system_settings | while IFS='|' read -r lbl raw; do
            echo "  $lbl"
        done
        return 1
    fi

    # If we found a match, open it differently depending on OS
    if (( osver >= 15 )); then
        # matched_raw is like "com.apple.Displays-Settings.extension"
        open "x-apple.systempreferences:$matched_raw"
    else
        # matched_raw is like "Network", so open the .prefPane
        open -b com.apple.systempreferences "$LEGACY_SETTINGS_PATH/${matched_raw}.prefPane" 2>/dev/null
    fi
}

# ------------------------------
#  7) The completion function
# ------------------------------
#compdef settings

_macos_system_settings() {
  local -a panels
  local line label raw

  # We'll read "Label|RawID" from _get_system_settings
  while IFS='|' read -r label raw; do
    # We'll show "label" as the completion text,
    # with a short help message like "Open <label> panel"
    panels+=("$label:Open $label panel")
  done < <(_get_system_settings)

  _describe -V 'settings panel' panels
}