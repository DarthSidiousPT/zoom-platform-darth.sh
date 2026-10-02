# Games with a custom fix

Some ZOOM Platform games have a shortcut or launcher that doesn't work correctly on Linux, or need something the default
Proton doesn't have. For these, `zoom-platform-darth.sh` fixes it automatically during install — there's nothing to turn on,
and every other game installs exactly as ZOOM built it.

| Game | What's fixed |
| --- | --- |
| EQI | Its Chopin video shows as coloured static under the default Proton. The game runs on a specific, tested GE-Proton build instead, downloaded once while installing, so starting the game works offline. |
| Kaan - Barbarian's Blade | Its intro and cutscene videos show as coloured static under the default Proton. The game runs on a specific, tested GE-Proton build instead, downloaded once (about 500 MB) while installing, so starting the game works offline. |
| Necro Vision - Hardcore Edition | Its launcher menu (the buttons for DirectX 9/10 and the base game/Lost Company) doesn't start the game correctly. It's replaced with four shortcuts that do: DirectX 9 or 10, for the base game or its Lost Company expansion. |
| Renoir | Its videos don't play under the default Proton. The game runs on a specific, tested GE-Proton build instead, downloaded once (about 500 MB) while installing, so starting the game works offline. |
| Warm Up! | The video window after you quit shows coloured static, and the "Select Rendering DLL" window in Graphics Settings comes up empty, under the default Proton. The game runs on a specific, tested GE-Proton build instead, downloaded once while installing, so starting the game works offline. |

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
