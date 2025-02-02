#!/usr/bin/env zsh
#
# macos-system-settings-zsh-completions.plugin.zsh
#

# 1) Local completion styles for the `settings` command
#    This ensures case-insensitive + partial substring matching
zstyle ":completion:*:*:settings:*" matcher-list \
  "m:{a-zA-Z}={a-zA-Z}"   \
  "r:|?=**"

# Optionally let the user pick from a menu of matches if there are multiple
# zstyle ":completion:*:*:settings:*" menu select

# 2) compdef so that `_macos_system_settings` is used for `settings`
#compdef settings

# 3) The rest of your plugin logic remains the same
#    (The code below is your existing single-file plugin, just with the new zstyle lines above.)

# ------------------------------
#  Setup & Paths
# ------------------------------
PLUGIN_DIR="${0:A:h}"
BUNDLE_FILE_15="$PLUGIN_DIR/v15/macOS_System_Settings_bundle_identifiers.txt"
UNCONFIRMED_FILE_15="$PLUGIN_DIR/v15/unconfirmed_preference_panels.txt"
LEGACY_SETTINGS_PATH="/System/Library/PreferencePanes"

_get_macos_version() {
    local version
    version="$(sw_vers -productVersion)"
    echo "${version%%.*}"
}

_get_macos_15_label_id_pairs() {
    local lines=()

    if [[ -f "$BUNDLE_FILE_15" ]]; then
        while IFS= read -r line; do
            lines+="$line"
        done < "$BUNDLE_FILE_15"
    fi
    if [[ -f "$UNCONFIRMED_FILE_15" ]]; then
        while IFS= read -r line; do
            lines+="$line"
        done < "$UNCONFIRMED_FILE_15"
    fi

    lines=($(printf '%s\n' "${lines[@]}" | sort -u))
    local output=()
    for raw_id in "${lines[@]}"; do
        local label="${raw_id#com.apple.}"
        label="${label%.extension}"
        output+=("$label|$raw_id")
    done
    printf '%s\n' "${output[@]}"
}

_get_macos_legacy_label_id_pairs() {
    if [[ -d "$LEGACY_SETTINGS_PATH" ]]; then
        find "$LEGACY_SETTINGS_PATH" -name "*.prefPane" -exec basename {} .prefPane \; | sort -u |
        while IFS= read -r pane; do
            echo "$pane|$pane"
        done
    fi
}

_get_system_settings() {
    local osver="$(_get_macos_version)"
    if (( osver >= 15 )); then
        _get_macos_15_label_id_pairs
    else
        _get_macos_legacy_label_id_pairs
    fi
}

settings() {
    local user_input="$1"
    local osver="$(_get_macos_version)"

    if [[ -z "$user_input" ]]; then
        _get_system_settings | while IFS='|' read -r lbl raw; do
            echo "$lbl"
        done
        return 0
    fi

    local -a entries
    entries=($(_get_system_settings))

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

    # pass 2: partial substring ignoring case
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

    # open for macOS 15 or older
    if (( osver >= 15 )); then
        open "x-apple.systempreferences:$matched_raw"
    else
        open -b com.apple.systempreferences "$LEGACY_SETTINGS_PATH/${matched_raw}.prefPane" 2>/dev/null
    fi
}

_macos_system_settings() {
  local -a panels
  local line label raw

  while IFS='|' read -r label raw; do
    panels+=("$label:Open $label panel")
  done < <(_get_system_settings)

  _describe -V 'settings panel' panels
}