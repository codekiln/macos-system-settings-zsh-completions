# macos-system-settings-zsh-completions

A zsh plugin that provides auto-completions for opening macOS System Settings (formerly System Preferences) directly from the terminal.

## Overview

This plugin makes it easier to quickly access macOS System Settings by providing tab completions for various settings panels. It works with both the newer System Settings (macOS Ventura and later) and System Preferences (older macOS versions).

## Installation

### Oh My Zsh

1. Clone this repository into `$ZSH_CUSTOM/plugins` (by default `~/.oh-my-zsh/custom/plugins`):

~~~bash
git clone https://github.com/yourusername/macos-system-settings-zsh-completions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/macos-system-settings
~~~

2. Add the plugin to your Oh My Zsh configuration in `~/.zshrc`:

~~~bash
plugins=(... macos-system-settings)
~~~

3. Restart your shell or run:

~~~bash
source ~/.zshrc
~~~

## Usage

Simply type `settings` and press TAB to see available completions. For example:

~~~bash
settings <TAB>
# Shows completions like:
# displays    - Open Display settings
# keyboard    - Open Keyboard settings
# trackpad    - Open Trackpad settings
# battery     - Open Battery settings
# general     - Open General settings
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

The plugin uses macOS's URL scheme for System Settings. For example, when you run `settings displays`, it executes:

~~~bash
open "x-apple.systempreferences:com.apple.Displays-Settings.extension"
~~~

## Contributing

Contributions are welcome! Feel free to submit issues and pull requests.

## License

[MIT License](LICENSE)
