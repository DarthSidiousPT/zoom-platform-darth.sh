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

|                                                                                                                    | Feature                                   | This version                                                                                                                                     | Official script                                                                                                                                                         |
| ------------------------------------------------------------------------------------------------------------------ | ----------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| <img src="https://api.iconify.design/ph/package-duotone.svg?color=%232f81f7&height=20" height="20" alt="">         | Newer game installers (Inno Setup 6.3+)   | <img src="https://api.iconify.design/ph/check-circle-fill.svg?color=%232da44e&height=18" height="18" alt="Works"> Supported                      | <img src="https://api.iconify.design/ph/question-fill.svg?color=%238b949e&height=18" height="18" alt="Unknown"> Bundles an older innoextract                            |
| <img src="https://api.iconify.design/ph/terminal-window-duotone.svg?color=%232f81f7&height=20" height="20" alt=""> | Running the script on Ubuntu, Debian, Mint | <img src="https://api.iconify.design/ph/check-circle-fill.svg?color=%232da44e&height=18" height="18" alt="Works"> Works                          | <img src="https://api.iconify.design/ph/x-circle-fill.svg?color=%23cf222e&height=18" height="18" alt="Fails"> Stops before creating shortcuts, unless started with `bash`                           |
| <img src="https://api.iconify.design/ph/stack-duotone.svg?color=%232f81f7&height=20" height="20" alt="">           | Game + DLC in the same folder             | <img src="https://api.iconify.design/ph/check-circle-fill.svg?color=%232da44e&height=18" height="18" alt="Works"> Each keeps its own shortcuts   | <img src="https://api.iconify.design/ph/warning-circle-fill.svg?color=%23d4a72c&height=18" height="18" alt="Partial"> DLC duplicates the game's shortcuts               |
| <img src="https://api.iconify.design/ph/app-window-duotone.svg?color=%232f81f7&height=20" height="20" alt="">      | Menu and Desktop shortcuts                | <img src="https://api.iconify.design/ph/check-circle-fill.svg?color=%232da44e&height=18" height="18" alt="Works"> Always created, gaps reported  | <img src="https://api.iconify.design/ph/warning-circle-fill.svg?color=%23d4a72c&height=18" height="18" alt="Partial"> Can go missing without an error                   |
| <img src="https://api.iconify.design/ph/folder-plus-duotone.svg?color=%232f81f7&height=20" height="20" alt="">     | Installing into a new folder              | <img src="https://api.iconify.design/ph/check-circle-fill.svg?color=%232da44e&height=18" height="18" alt="Works"> Works                          | <img src="https://api.iconify.design/ph/warning-circle-fill.svg?color=%23d4a72c&height=18" height="18" alt="Partial"> Can wrongly refuse a folder that doesn't exist yet |
| <img src="https://api.iconify.design/ph/files-duotone.svg?color=%232f81f7&height=20" height="20" alt="">           | Game split into several .bin files        | <img src="https://api.iconify.design/ph/check-circle-fill.svg?color=%232da44e&height=18" height="18" alt="Works"> Checks the parts first, names a renamed one | <img src="https://api.iconify.design/ph/warning-circle-fill.svg?color=%23d4a72c&height=18" height="18" alt="Partial"> No check of its own, only Setup's prompt for a missing part |
| <img src="https://api.iconify.design/ph/wrench-duotone.svg?color=%232f81f7&height=20" height="20" alt="">          | Games whose own launcher fails            | <img src="https://api.iconify.design/ph/check-circle-fill.svg?color=%232da44e&height=18" height="18" alt="Works"> [Fixed launchers for some games](game-fixes/GAMES.md) | <img src="https://api.iconify.design/ph/x-circle-fill.svg?color=%23cf222e&height=18" height="18" alt="Fails"> No game fixes, only the game's own shortcut               |
| <img src="https://api.iconify.design/ph/gear-six-duotone.svg?color=%232f81f7&height=20" height="20" alt=""> | Games that need a different Proton | <img src="https://api.iconify.design/ph/check-circle-fill.svg?color=%232da44e&height=18" height="18" alt="Works"> [A specific GE-Proton version for some games](game-fixes/GAMES.md) | <img src="https://api.iconify.design/ph/warning-circle-fill.svg?color=%23d4a72c&height=18" height="18" alt="Partial"> Always umu's default Proton |
| <img src="https://api.iconify.design/ph/clock-counter-clockwise-duotone.svg?color=%232f81f7&height=20" height="20" alt=""> | Older installers with no game ID | <img src="https://api.iconify.design/ph/check-circle-fill.svg?color=%232da44e&height=18" height="18" alt="Works"> [Looks the game up in a short list](game-fixes/README.md#games-with-no-zoom-game-id) | <img src="https://api.iconify.design/ph/x-circle-fill.svg?color=%23cf222e&height=18" height="18" alt="Fails"> Refuses them as "not a ZOOM Platform installer" |
| <img src="https://api.iconify.design/ph/trash-duotone.svg?color=%232f81f7&height=20" height="20" alt="">           | Uninstall                                 | <img src="https://api.iconify.design/ph/check-circle-fill.svg?color=%232da44e&height=18" height="18" alt="Works"> Previews what it'll remove, reports the result | <img src="https://api.iconify.design/ph/x-circle-fill.svg?color=%23cf222e&height=18" height="18" alt="Fails"> Leaves Desktop links and launch scripts, no output           |

<sub>Official script = the [v1.0.1 release](https://github.com/ZOOM-Platform/zoom-platform.sh/releases/tag/v1.0.1) that `curl zoom-platform.sh` serves, checked September 2026. Some of these are already fixed in its unreleased development code.</sub>

### Games split into several files

Some big games (such as Necro Vision) come as one `.exe` plus `-1.bin`, `-2.bin`, ... files. Normally you'd download all of them into the same folder, keep their names, and choose the `.exe`. Before installing, the script checks that every part is there and complete. If your browser renamed one (`-1 (1).bin`), it tells you which file to rename. A part that's missing entirely, or that looks cut short, is a warning you can choose to continue past - for a missing part, Setup's own installer will ask you to browse to wherever it actually is (another folder, disc or drive) once it reaches that part, so the parts don't all have to sit together if you'd rather feed them in one at a time.

### Games that need a specific Proton

A few games only work properly on a certain GE-Proton version (Kaan's videos show as static on umu's default one, for example). For those, the game's fix file names the version. The script downloads it once while installing (about 500 MB, checked against a checksum) and uses it for that game. After that the game starts offline. If the GE-Proton folder ever gets deleted, the game falls back to the default Proton and shows a notification. Games without a fix file are untouched. See [which games have one](game-fixes/GAMES.md).

### Finding a game's ID

Fix files are named after the game's ID. `-g` (or `--guid`) prints it for an installer and installs nothing:
```
zoom-platform-darth.sh --guid "Game-English-Setup-1.33.7.exe"
```
[game-fixes/README.md](game-fixes/README.md) shows how to write a fix file.

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

For the script's help text, `-h` has to go after `-s --` since the script is piped in:
```
curl -L darthsidiouspt.github.io/zoom-platform-darth.sh/i | sh -s -- -h
```

Same for the game ID option:
```
curl -L darthsidiouspt.github.io/zoom-platform-darth.sh/i | sh -s -- --guid "Game-English-Setup-1.33.7.exe"
```

## Contributing

Please see [CONTRIBUTING.md](CONTRIBUTING.md)

## Licence

[BSD-3](LICENSE)

## AI usage

AI is used to debug, explain and write most of the code in this fork, but it's guided manually. It isn't vibe coded (the
GitHub [site page](https://darthsidiouspt.github.io/zoom-platform-darth.sh/) is the exception, since that one was): every change is reviewed and tested before it gets committed.
