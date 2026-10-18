# What's new

This version was supposed to be a small bump for `v1.5.3` but I ended up with some changes to it. The biggest one, and most important is that now `zoom-platform-darth.sh` script ships with [GE-Proton](https://github.com/GloriousEggroll/proton-ge-custom) by default, compared to the _official_ version, which uses **UMU-proton**.

This version also gets some fixes for the brand new (and free) release of _The Colony_.


## GE-Proton instead of UMU

What this means, is that half of the _game-fixes_ are not needed, since they where mostly to play the videos (Media Foundation) correctly. Also, GE-Proton includes several [fixes](https://github.com/GloriousEggroll/proton-ge-custom#tested-games) for games, which might not benefit the "limited" catalogue of ZOOM, I still think it's better than relying on UMU-proton.

## Game fixes

- ZOOM [released](https://www.zoom-platform.com/news/back-in-action-with-a-cosmic-conundrum) last week, for free, [The Colony](https://www.zoom-platform.com/product/the-colony). While it's very well appreciated, the native Linux version is not as smooth to install as the Windows one, given that it requires ScummVM to be installed. So I decided to use the Windows version instead. Unfortunately, the installer creates the three shortcuts (DOS, MacOS Color and MacOS Monochrome) with the same name in the Start Menu, so each one overwrites the last and the "DOS" entry starts the Monochrome version (**Spoiler:** you want to play the _MacOS color_, trust me). ZOOM already improved this in version 1.1, where the Desktop shortcuts have their own names, but the Start Menu ones are still the same. A new fix was created for this installer, so that you have all the right shortcuts in your applications menu, on both 1.0 and 1.1.

## Script Improvements

### `zoom-platform-darth.sh`

- New installs use the latest GE-Proton. The script looks up the latest release, downloads it once (checked against its checksum), and the game starts offline after that.
- New options: `--ge-proton VERSION` to install with a specific GE-Proton version, `--umu-proton` to use UMU-Proton as before, and `--restore-proton DEST` to download again a GE-Proton version that was deleted (until then the game doesn't start, and a notification says how).
- If GE-Proton can't be downloaded, an install started with options stops, and one started without options asks if you want to go on with UMU-Proton.
- A shortcut whose icon came out empty (the installer was closed while the icon was being made) is now made again, so the menu entry doesn't end up with a blank icon.
- The main script code was optimized and the script is now smaller (about 15% fewer lines with most verbose comments removed). A better redesign is still in place for a future version.
- Added small improvement for a (rare) scenario in `uninstall.sh`: It now also removes the game's Desktop links when the Desktop folder was moved or renamed after the install.

### `game-fixes`

- The fix files for Kaan, Renoir, Warm Up! and EQI are gone. They only moved those games to GE-Proton, which is now the default.

### Documentation

- The `README.md` now includes an example of how to run an old version of the script, in case you need to do a rollback.