# macos-system-settings-zsh-completions

A Zsh plugin that provides tab completions for quickly opening macOS **System Settings** (formerly System Preferences) directly from the terminal.  

## Overview

- **Human‐readable completions**: Type `settings disp<TAB>` and you’ll see `displays` as an option—no `com.apple.Displays-Settings.extension` needed.  
- **Works on macOS Ventura and later** (including macOS 15 “Sequoia”).  
- **Falls back** to legacy `.prefPane` files on older macOS versions.  

When you choose a completion like `settings displays`, the plugin under the hood runs:

~~~bash
open "x-apple.systempreferences:com.apple.Displays-Settings.extension"
~~~

## Installation

### Oh My Zsh

1. **Clone** this repository into `$ZSH_CUSTOM/plugins` (by default `~/.oh-my-zsh/custom/plugins`):
   ~~~bash
   git clone https://github.com/codekiln/macos-system-settings-zsh-completions.git \
     ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/macos-system-settings-zsh-completions
   ~~~

2. **Add** the plugin to your Oh My Zsh configuration in `~/.zshrc`:
   ~~~bash
   plugins=(... macos-system-settings-zsh-completions)
   ~~~

3. **Restart** your shell or run:
   ~~~bash
   source ~/.zshrc
   ~~~

That’s it! Now typing `settings` followed by a partial name and pressing `<TAB>` will show suggestions.

## Usage

- **List all panels**:
  ~~~bash
  settings <TAB>
  ~~~
  You’ll see suggestions like:
  ~~~
  $ settings                        
  Accessibility-Settings                            -- Open Accessibility-Settings panel
  AirDrop-Handoff-Settings                          -- Open AirDrop-Handoff-Settings panel
  Appearance-Settings                               -- Open Appearance-Settings panel
  Battery-Settings                                  -- Open Battery-Settings panel
  BluetoothSettings                                 -- Open BluetoothSettings panel
  CD-DVD-Settings                                   -- Open CD-DVD-Settings panel
  ~~~

- **Open a specific panel**:
~~~bash
settings displays
settings trackpad
settings battery
~~~
Under the hood, it’s equivalent to:
~~~bash
open "x-apple.systempreferences:com.apple.Displays-Settings.extension"
~~~

## Examples

~~~bash
# Open Display settings
settings displays

# Open Keyboard settings
settings keyboard

# Open Battery settings
settings battery
~~~

## Under the Hood

1. For **macOS 15** and newer:  
 - We maintain a list of discovered `com.apple.*` bundle identifiers in `v15/`.  
 - The plugin shows these as human‐friendly labels (e.g., `displays` instead of `com.apple.Displays-Settings.extension`).  
 - When you run `settings displays`, it internally calls `open "x-apple.systempreferences:com.apple.Displays-Settings.extension"`.

2. For **older macOS**:  
 - We fall back to enumerating `.prefPane` files in `/System/Library/PreferencePanes`.  
 - Completions appear as the pane names (e.g., `Network`, `Keyboard`).  
 - Running `settings network` uses `open -b com.apple.systempreferences /System/Library/PreferencePanes/Network.prefPane`.

### Updating the macOS 15 Bundles

If Apple adds or changes panels on macOS 15, you can regenerate the list locally:

1. Run:
 ~~~bash
 ./update-macos-settings-bundle-identifiers.zsh
 ~~~
 This script parses the built-in `Sidebar.plist` and the `System Settings` binary to discover updated panel IDs.  

2. It writes them to:
  * [macOS_System_Settings_bundle_identifiers.txt](./v15/macOS_System_Settings_bundle_identifiers.txt)
  * [v15/unconfirmed_preference_panels.txt](./v15/unconfirmed_preference_panels.txt)

3. The plugin then automatically reads those files and presents them as completions.

## Contributing

Contributions are welcome! Feel free to submit issues and pull requests. If you find a missing or broken panel, please let us know or regenerate the text files and submit a PR.

## License

[MIT License](LICENSE)
