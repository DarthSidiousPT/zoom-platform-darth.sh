# Games with a custom fix

Some ZOOM Platform games have a shortcut or launcher that doesn't work correctly on Linux, or need something the default
Proton doesn't have. For these, `zoom-platform-darth.sh` fixes it automatically during install — there's nothing to turn on,
and every other game installs exactly as ZOOM built it.

| Game | What's fixed |
| --- | --- |
| e-Racer | The gameplay overall is very black under Proton (and in some cases in Windows). A registry setting that the game reads itself is added automatically. It also runs at the screen's refresh rate (75 frames per second on a 75 Hz screen), and since the game logic seem to follow the frame rate, it's now capped. A small replacement `ddraw.dll` caps it at 60 (by default), and a `ddraw-darth.ini` file in the game's folder allows you to customize that. Gamepads are now properly supported thanks to Xidi (a gamepad layer).</br>**You can follow the issues with this game on the [discussions topic](https://github.com/DarthSidiousPT/zoom-platform-darth.sh/discussions/3)**. |
| EQI | The game runs on a specific, tested GE-Proton build to avoid the typical issues of videos not played well. |
| Kaan - Barbarian's Blade | The game runs on a specific, tested GE-Proton build to avoid the typical issues of videos not played well. |
| Necro Vision - Hardcore Edition | The main launcher (where there are the buttons for DirectX 9/10 and the base game/Lost Company) doesn't start the game correctly. It's replaced with four shortcuts that do: DirectX 9 or 10, for the base game or its Lost Company expansion.</br>**You can follow the issues with this game on the [discussions topic](https://github.com/DarthSidiousPT/zoom-platform-darth.sh/discussions/4)**. |
| Renoir | Videos don't play under the default Proton. The game runs on a specific, tested GE-Proton build instead, downloaded once while installing, so starting the game works offline. |
| The Colony | While ZOOM has a native version for Linux, it required you to manually install [ScummVM](https://www.scummvm.org/downloads), so if you prefer to use the full Windows installer, you'll see that there is an issue:</br>The ZOOM's installer creates three shortcuts (DOS, MacOS Color and MacOS Monochrome) with the same name in the Start Menu, so each one overwrites the last, and the menu entry created started the MacOS Monochrome version. Now they're replaced with **three new launchers** (one for each version). |
| Warm Up! | The video window after you quit the game shows the typical colour bars, and the "Select Rendering DLL" window in Graphics Settings comes up empty, under the default Proton. The game runs on a specific, tested GE-Proton build instead, downloaded once while installing, so starting the game works offline. |

## Possible issues

### Kaan - Barbarian's Blade

The game closes right after it starts. It seems to happen because its default resolution is 640x480. Before you play,
open **Configure Kann** from the menu, pick your screen's resolution (the highest one is fine) and close it. After that
the game starts normally. You only need to do this once for each install.

### Necro Vision - Hardcore Edition

The installer comes in parts, named like the installer with `-1.bin` and `-2.bin` at the end. They have to sit next to
the `.exe` under their exact names. If your browser renamed one (to `...-1 (1).bin`, say), rename it back. The script
stops and tells you which file, and it never touches your files itself.

# Missing a game fix?

If a game you play isn't on this list, it may work fine as it is, or nobody has written a fix for it yet. If it doesn't
work right, [open an issue](https://github.com/DarthSidiousPT/zoom-platform-darth.sh/issues) and tell us what happens.
If you'd like to write the fix yourself, [README.md](README.md) shows how, step by step.
