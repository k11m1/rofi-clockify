# rofi-clockify
Access clockify via rofi prompt using clockify-cli.

This project is still under heavy development.

Project is inspired by the only similar project [clfy](https://github.com/wixe/clfy).


## usage

``` sh
Usage: ./main.pl [init|start|start-dmenu]
Commands:
  init                      Perform database initialization
  start|start-dmenu         Select and start-dmenu clockify entry
  stop                      Stop current entry with clockify-cli out
```

For better use consider having `start` and `stop` mapped to some shortcut.

### initialization

You need to first initialize the database to properly use it.
For initialization of the internal database run `init` or `start` and press `ALT+1` to get into admin menu and choose init.
