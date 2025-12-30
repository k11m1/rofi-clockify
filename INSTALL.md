# Installation Guide

## Using Nix Flakes

### Quick Test (Without Installation)

Run directly without installing:
```bash
nix run github:k11m1/rofi-clockify -- start
```

### Development Shell

Enter a development environment with all dependencies:
```bash
nix develop
```

### Build Locally

```bash
# Build the package
nix build

# Run the built package
./result/bin/rofi-clockify init
./result/bin/rofi-clockify start
```

## NixOS Integration (**TESTED**)

To integrate `rofi-clockify` into NixOS:

1. Add to `flake.nix`:
   ```nix
   specialArgs = {
     rofi-clockify = rofi-clockify.defaultPackage.x86_64-linux;
   };
   ```

2. Include in `pkgs`:
   ```nix
   pkgs = {
     inherit rofi-clockify;
   };
   ```


## Keyboard Shortcuts Setup

### For i3/sway

Add to your `~/.config/i3/config` or `~/.config/sway/config`:
```
bindsym $mod+Shift+s exec rofi-clockify start
bindsym $mod+Shift+x exec rofi-clockify stop
```

### For Hyprland

Add to your `~/.config/hypr/hyprland.conf`:
```
bind = SUPER SHIFT, S, exec, rofi-clockify start
bind = SUPER SHIFT, X, exec, rofi-clockify stop
```

### For bspwm (using sxhkd)

Add to your `~/.config/sxhkd/sxhkdrc`:
```
super + shift + s
    rofi-clockify start

super + shift + x
    rofi-clockify stop
```

### For KDE Plasma (**TESTED**)

1. Open **System Settings**
2. Go to **Shortcuts** → **Add New** → **Application...**
3. Select **Rofi Clockify** from the list
4. Bind shortcuts to the available actions: **Start via dmenu** and **Stop current entry**
5. Apply your changes

## Application Integration

After installation, `rofi-clockify` is available as a system application with two action targets: **Start via dmenu** and **Stop current entry**. You can bind these actions directly in KDE Plasma's shortcut settings by adding a new Application shortcut and selecting Rofi Clockify, then assigning your preferred key combinations to each action.

## First Time Setup

After installation, initialize the database:
```bash
rofi-clockify init
```