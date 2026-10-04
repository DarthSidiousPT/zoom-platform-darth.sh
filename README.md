# [zoom-platform-darth.sh](https://darthsidiouspt.github.io/zoom-platform-darth.sh/)

> **This is [DarthSidiousPT](https://github.com/DarthSidiousPT)'s fork of
> [ZOOM-Platform/zoom-platform.sh](https://github.com/ZOOM-Platform/zoom-platform.sh)**,
> kept up to date with fixes and installer compatibility work that hasn't landed upstream
> yet (see the table below). It builds `innoextract` from
> [DarthSidiousPT/innoextract](https://github.com/DarthSidiousPT/innoextract) (itself a
> fork of doZennn's ZOOM-patched fork), and stays current instead of waiting on upstream's
> release cadence.
>
> This is an independent fork - it is not endorsed by, affiliated with, or supported by
> ZOOM Platform. Install with:
> ```
> curl -L darthsidiouspt.github.io/zoom-platform-darth.sh/i | sh
> ```

## What's different from the official script:

| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;                                                                   | Feature                                   | This version                                                                                                                                     | Official script                                                                                                                                                         |
| ------------------------------------------------------------------------------------------------------------------ | ----------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| <img src="https://api.iconify.design/ph/package-duotone.svg?color=%232f81f7&height=28" height="28" alt="">         | Newer game installers (Inno Setup 6.3+)   | <img src="https://api.iconify.design/ph/check-circle-fill.svg?color=%232da44e&height=20" height="20" align="absmiddle" alt="Works"> Supported                      | <img src="https://api.iconify.design/ph/question-fill.svg?color=%238b949e&height=20" height="20" align="absmiddle" alt="Unknown"> Bundles an older innoextract                            |
| <img src="https://api.iconify.design/ph/terminal-window-duotone.svg?color=%232f81f7&height=28" height="28" alt=""> | Running the script on Ubuntu, Debian, Mint | <img src="https://api.iconify.design/ph/check-circle-fill.svg?color=%232da44e&height=20" height="20" align="absmiddle" alt="Works"> Works                          | <img src="https://api.iconify.design/ph/x-circle-fill.svg?color=%23cf222e&height=20" height="20" align="absmiddle" alt="Fails"> Stops before creating shortcuts, unless started with `bash`                           |
| <img src="https://api.iconify.design/ph/stack-duotone.svg?color=%232f81f7&height=28" height="28" alt="">           | Game + DLC in the same folder             | <img src="https://api.iconify.design/ph/check-circle-fill.svg?color=%232da44e&height=20" height="20" align="absmiddle" alt="Works"> Each keeps its own shortcuts   | <img src="https://api.iconify.design/ph/warning-circle-fill.svg?color=%23d4a72c&height=20" height="20" align="absmiddle" alt="Partial"> DLC duplicates the game's shortcuts               |
| <img src="https://api.iconify.design/ph/app-window-duotone.svg?color=%232f81f7&height=28" height="28" alt="">      | Menu and Desktop shortcuts                | <img src="https://api.iconify.design/ph/check-circle-fill.svg?color=%232da44e&height=20" height="20" align="absmiddle" alt="Works"> Always created, gaps reported  | <img src="https://api.iconify.design/ph/warning-circle-fill.svg?color=%23d4a72c&height=20" height="20" align="absmiddle" alt="Partial"> Can go missing without an error                   |
| <img src="https://api.iconify.design/ph/folder-plus-duotone.svg?color=%232f81f7&height=28" height="28" alt="">     | Installing into a new folder              | <img src="https://api.iconify.design/ph/check-circle-fill.svg?color=%232da44e&height=20" height="20" align="absmiddle" alt="Works"> Works                          | <img src="https://api.iconify.design/ph/warning-circle-fill.svg?color=%23d4a72c&height=20" height="20" align="absmiddle" alt="Partial"> Can wrongly refuse a folder that doesn't exist yet |
| <img src="https://api.iconify.design/ph/files-duotone.svg?color=%232f81f7&height=28" height="28" alt="">           | Game split into several .bin files        | <img src="https://api.iconify.design/ph/check-circle-fill.svg?color=%232da44e&height=20" height="20" align="absmiddle" alt="Works"> Checks the parts first, names a renamed one | <img src="https://api.iconify.design/ph/warning-circle-fill.svg?color=%23d4a72c&height=20" height="20" align="absmiddle" alt="Partial"> No check of its own, only Setup's prompt for a missing part |
| <img src="https://api.iconify.design/ph/wrench-duotone.svg?color=%232f81f7&height=28" height="28" alt="">          | Games whose own launcher fails            | <img src="https://api.iconify.design/ph/check-circle-fill.svg?color=%232da44e&height=20" height="20" align="absmiddle" alt="Works"> [Fixed launchers for some games](game-fixes/GAMES.md) | <img src="https://api.iconify.design/ph/x-circle-fill.svg?color=%23cf222e&height=20" height="20" align="absmiddle" alt="Fails"> No game fixes, only the game's own shortcut               |
| <img src="https://api.iconify.design/ph/gear-six-duotone.svg?color=%232f81f7&height=28" height="28" alt=""> | Games that need a different Proton | <img src="https://api.iconify.design/ph/check-circle-fill.svg?color=%232da44e&height=20" height="20" align="absmiddle" alt="Works"> [A specific GE-Proton version for some games](game-fixes/GAMES.md) | <img src="https://api.iconify.design/ph/warning-circle-fill.svg?color=%23d4a72c&height=20" height="20" align="absmiddle" alt="Partial"> Always umu's default Proton |
| <img src="https://api.iconify.design/ph/clock-counter-clockwise-duotone.svg?color=%232f81f7&height=28" height="28" alt=""> | Older installers with no game ID | <img src="https://api.iconify.design/ph/check-circle-fill.svg?color=%232da44e&height=20" height="20" align="absmiddle" alt="Works"> [Looks the game up in a short list](game-fixes/README.md#games-with-no-zoom-game-id) | <img src="https://api.iconify.design/ph/x-circle-fill.svg?color=%23cf222e&height=20" height="20" align="absmiddle" alt="Fails"> Refuses them as "not a ZOOM Platform installer" |
| <img src="https://api.iconify.design/ph/trash-duotone.svg?color=%232f81f7&height=28" height="28" alt="">           | Uninstall                                 | <img src="https://api.iconify.design/ph/check-circle-fill.svg?color=%232da44e&height=20" height="20" align="absmiddle" alt="Works"> Previews what it'll remove, reports the result, asks about removing a GE-Proton version no other game uses | <img src="https://api.iconify.design/ph/x-circle-fill.svg?color=%23cf222e&height=20" height="20" align="absmiddle" alt="Fails"> Leaves Desktop links and launch scripts, no output           |

<sub>Official script = the [v1.0.1 release](https://github.com/ZOOM-Platform/zoom-platform.sh/releases/tag/v1.0.1) that `curl zoom-platform.sh` serves, checked September 2026. Some of these are already fixed in its unreleased development code.</sub>

### Games split into several files

Some big games (such as Necro Vision) come as one `.exe` plus `-1.bin`, `-2.bin`, ... files. Normally you'd download all of them into the same folder, keep their names, and choose the `.exe`. Before installing, the script checks that every part is there and complete. If your browser renamed one (`-1 (1).bin`), it tells you which file to rename. A part that's missing entirely, or that looks cut short, is a warning you can choose to continue past - for a missing part, Setup's own installer will ask you to browse to wherever it actually is (another folder, disc or drive) once it reaches that part, so the parts don't all have to sit together if you'd rather feed them in one at a time.

### Games that need a specific Proton

A few games only work properly on a certain GE-Proton version (Kaan's videos show colour bars on umu's default one, for example). For those, the game's fix file names the version. The script downloads it once while installing (checked against a checksum) and uses it for that game. After that the game starts offline. If the GE-Proton folder ever gets deleted, the game falls back to the default Proton and shows a notification. Games without a fix file are untouched. See [which games have one](game-fixes/GAMES.md).

### Finding a game's ID

Fix files are named after the game's ID. `-g` (or `--guid`) prints it for an installer and installs nothing:
```
zoom-platform-darth.sh --guid "Game-English-Setup-1.33.7.exe"
```
[game-fixes/README.md](game-fixes/README.md) shows how to write a fix file.

### Freeing disk space

Each specific GE-Proton version takes a lot of disk space. Uninstalling a game asks if you also want to remove its
version (a separate question, and the default is to keep it), as long as no other game uses it. A version can still get
left behind, for example when a fix file moved a game to a newer one and you reinstalled it. To clear those:
```
zoom-platform-darth.sh --remove-unused-proton
```
It lists what it found and asks before removing anything. In a script or a cron job, add `--yes` (or `-y`) and it removes
them without asking:
```
zoom-platform-darth.sh --remove-unused-proton --yes
```
Only versions this script downloaded are removed. Ones you installed yourself with ProtonUp-Qt or Steam are never touched,
and neither are versions downloaded by older releases of this script (delete those by hand from
`~/.local/share/Steam/compatibilitytools.d/`). If you installed with the curl one-liner, see [Usage](#usage) for how to run
it.

Each game's `uninstall.sh` sits in its install folder. Run with no options, it asks two things: whether to remove the game,
and then, only when no other game uses its GE-Proton version, whether to remove that version too. The second question
defaults to keeping it:
```
No other game uses GE-Proton<version>, and this script downloaded it.
Remove the remaining GE-Proton<version> (<size> MB)? [y/N]
```
Two options skip the questions:

| Command | Asks about the game | Asks about the version | Result |
| --- | --- | --- | --- |
| `sh ~/Games/MyGame/uninstall.sh` | yes | yes | what you answer |
| `sh ~/Games/MyGame/uninstall.sh -y` | no | no | game removed, version kept |
| `sh ~/Games/MyGame/uninstall.sh -y --remove-unused-proton` | no | no | game and version removed |
| `sh ~/Games/MyGame/uninstall.sh --remove-unused-proton` | yes | no | game removed if you say yes, and the version with it |

`-y` is short for `--yes`, and `-h` lists the options. An option it doesn't know stops it before anything is removed.

`--remove-unused-proton` follows the same rules as the question. If another game still uses the version, or this script
didn't download it, it does nothing for the version, the game is still uninstalled, and the result says the version was
kept. A game with no specific GE-Proton version has nothing to remove, and it says so. If you used `-y` and want the
version gone later, the main script's `--remove-unused-proton` above cleans it up.

---

A tool to streamline installation, updating, and playing Windows games from [ZOOM Platform](https://www.zoom-platform.com/) on Linux using [umu](https://github.com/Open-Wine-Components/umu-launcher) and Proton.

## Building

| Script       | Example                                             | -                                                                                                                  |
| ------------ | --------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| **build.sh** | `./build.sh "src.sh" "innoextract-upx" > output.sh` | Takes an input `src.sh`, embeds an innoextract binary, sets the version, prepends licences then prints the output. |
| **dist.sh**  |                                                     | Downloads innoextract (and copies it to `./innoextract`, which is what `src.sh` reads when run directly) then creates a `zoom-platform-darth.sh` file using `build.sh` |

## Website

The fork's own site is a static `index.html` in [site](site), deployed to GitHub Pages by
`.github/workflows/darth-build.yml` on every push to `main`. It always serves the latest
*release* asset, never an unreleased `main` build.

## Usage

```
curl -L darthsidiouspt.github.io/zoom-platform-darth.sh/i | sh
```

These are the options of `zoom-platform-darth.sh`. With the curl one-liner, add them after `sh -s --`:

| Option | What it does |
| --- | --- |
| `-i FILE`, `--installer FILE` | The ZOOM installer `.exe` to install. |
| `-d FOLDER`, `--dest FOLDER`, `-o FOLDER`, `--output FOLDER` | Where to install the game. To update a game or add a DLC, use the folder of the base game. |
| `-g FILE`, `--guid FILE` | Prints the game's ID and installs nothing. |
| `--remove-unused-proton` | Lists the GE-Proton versions this script downloaded that no game uses, and removes them after asking. |
| `-y`, `--yes` | With `--remove-unused-proton`, does not ask. Works without a terminal. |
| `-v`, `--version` | Prints the script's version. |
| `-h`, `--help` | Prints the help text. |

The installer and the folder can also be plain arguments, and without them the script opens a file picker when zenity or
kdialog is available:
```
zoom-platform-darth.sh -i "Game-English-Setup-1.33.7.exe" -d ~/Games/MyGame
zoom-platform-darth.sh "Game-English-Setup-1.33.7.exe" ~/Games/MyGame
```
With the curl one-liner:
```
curl -L darthsidiouspt.github.io/zoom-platform-darth.sh/i | sh -s -- -i "Game-English-Setup-1.33.7.exe" -d ~/Games/MyGame
```

For the script's help text, `-h` has to go after `-s --` since the script is piped in:
```
curl -L darthsidiouspt.github.io/zoom-platform-darth.sh/i | sh -s -- -h
```

Same for the game ID option:
```
curl -L darthsidiouspt.github.io/zoom-platform-darth.sh/i | sh -s -- --guid "Game-English-Setup-1.33.7.exe"
```

And for removing GE-Proton versions that no game uses (it asks on the terminal, so piped input can't answer it):
```
curl -L darthsidiouspt.github.io/zoom-platform-darth.sh/i | sh -s -- --remove-unused-proton
```
With `--yes` it doesn't ask, which also works without a terminal:
```
curl -L darthsidiouspt.github.io/zoom-platform-darth.sh/i | sh -s -- --remove-unused-proton --yes
```

## Contributing

Please see [CONTRIBUTING.md](CONTRIBUTING.md)

## Licence

[BSD-3](LICENSE)

## AI usage

AI is used to debug, explain and write most of the code in this fork, but it's guided manually. It isn't vibe coded (the
GitHub [site page](https://darthsidiouspt.github.io/zoom-platform-darth.sh/) is the exception, since that one was): every change is reviewed and tested before it gets committed.
