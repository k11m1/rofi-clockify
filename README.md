# rofi-clockify
Access clockify via rofi prompt using clockify-cli.

This project is still under heavy development.

Project is inspired by the only similar project [clfy](https://github.com/wixe/clfy).

## Installation

See [INSTALL.md](INSTALL.md) for detailed installation instructions using Nix flakes.

### Quick Start with Nix

```bash
# Run directly without installing
nix run github:k11m1/rofi-clockify -- init

# Or install to your profile
nix profile install github:k11m1/rofi-clockify

# Or enter a development shell
nix develop
```

## usage

``` sh
Usage: rofi-clockify [init|start|start-dmenu]
Commands:
  init                      Perform database initialization
  start|start-dmenu         Select and start-dmenu clockify entry
  stop                      Stop current entry with clockify-cli out
```

For better use consider having `start` and `stop` mapped to some shortcut.

### initialization

You need to first initialize the database to properly use it.
For initialization of the internal database run `init` or `start` and press `ALT+1` to get into admin menu and choose init.

## Dependencies

- [clockify-cli](https://github.com/lucassabreu/clockify-cli) - Provided via [clockify-cli-flake](https://github.com/k11m1/clockify-cli-flake)
- rofi
- libnotify (for desktop notifications)
- Perl with DBI, JSON, and SQLite support

All dependencies are automatically managed by the Nix flake.

