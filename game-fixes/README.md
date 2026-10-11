# Game fixes

A game fix is a small text file that changes how one game is installed. It can do four things:

- Replace a ZOOM shortcut that doesn't work under Proton with launchers that do (Necro Vision's launcher menu is one).
- Run the game on one specific, tested version of GE-Proton instead of umu's default Proton (Kaan needs this for its videos).
- Set values in the game's Windows registry (e-Racer needs one, or its picture is almost black).
- Copy files from a zip into the game's folder (e-Racer gets a small `ddraw.dll` that keeps it at 60 frames per second).

Most games don't need a fix, so they have no file. For a plain list of the games that do, see [GAMES.md](GAMES.md).
This page explains how to add or change a fix, step by step. You don't need to know anything about Proton to follow it.

## Getting a SHA-512 checksum

Some fixes ask for a SHA-512, a 128-character fingerprint of a file (the GE-Proton keys and the zip in Part 4 both do).
To get one, open a terminal (Bash and ZSH both work), go to the folder that holds the file and run `sha512sum` on it:

```sh
cd game-fixes/files
sha512sum ddraw-limiter-1.0.zip
```

It prints the fingerprint, then spaces and the file's name:

```
5ef51856b052127390349a6a5a5190b1819504825599715677ed5c388aaae555188da9193b36ee037900a5ae0ac4459327fa83465c775683ca2178ed8f2927c4  ddraw-limiter-1.0.zip
```

Copy only the 128 characters before the spaces. To print just those, add `| cut -d ' ' -f1`:

```sh
sha512sum ddraw-limiter-1.0.zip | cut -d ' ' -f1
```

`sha512sum` comes with every common Linux distro. If yours doesn't have it, `openssl dgst -sha512 ddraw-limiter-1.0.zip`
prints the same fingerprint after `= `. Any change to the file changes the fingerprint, so get it again whenever the file
changes.

## How the script uses the file

While installing, `zoom-platform-darth.sh` downloads `game-fixes/<game GUID>.ini` from the `main` branch of this repository, for the game being installed **only**. A `404`, or no network, means the install goes on as usual. The script logs everything it does with the file.

The commands on this page run the script from a file. To get it:

```sh
curl -L -o zoom-platform-darth.sh https://darthsidiouspt.github.io/zoom-platform-darth.sh/i
```

To try a file that isn't on `main` yet, run the script with `ZOOM_GAME_FIXES_FILE=<path to the file>`:

```sh
ZOOM_GAME_FIXES_FILE=./my-fix.ini sh zoom-platform-darth.sh "Game-Setup.exe" ~/Games/MyGame
```

To add a fix for a new game, put one `.ini` file for it in the `game-fixes/` folder. You don't have to edit the script.
Inside the file, lines starting with `#` or `;` are comments. Keys the script doesn't know are ignored, so an older
script can read a newer file.

## Get the game's GUID and name the file

Every game on ZOOM Platform has an ID, called a GUID, that looks like `b14602fa-fe8e-48e9-a249-aca0ad164bab`. The fix
file is named after it, so you need to find it first. The script can read it from the game's installer:

1. Download the game's installer from ZOOM Platform. It is the `.exe` you would normally run.
2. In a terminal, run the script with `--guid` and the path to the installer:

   ```sh
   sh zoom-platform-darth.sh --guid "Kaan-Barbarian's-Blade-English-Setup-1.1.1.exe"
   ```

   It prints the GUID and nothing else. It installs nothing, and for almost every game it doesn't need a network connection:

   ```
   b14602fa-fe8e-48e9-a249-aca0ad164bab
   ```

   If it says the file doesn't seem to be a ZOOM Platform installer, the file you gave it isn't a game installer.
   If it prints a warning about a missing game ID instead, see [Games with no ZOOM game ID](#games-with-no-zoom-game-id).
   `-g` does the same as `--guid`. The option was added after `v1.3.3-darth`, so an older script doesn't have it.
3. Add `.ini` at the end. That is the name of your file, and it goes in the `game-fixes/` folder:
   `game-fixes/b14602fa-fe8e-48e9-a249-aca0ad164bab.ini`. The GUID is already printed in lowercase, which is what the
   name needs.

The script also prints the GUID at the start of every install, on the line that says `ZOOM Platform UUID`.

## Games with no ZOOM game ID

A few older installers, like Renoir and POSTAL 1, don't have the game's ID inside them, so the script can't read it.
For those it looks the game up in [known-guids.ini](known-guids.ini), a short list in this folder. Each line says which
ZOOM GUID belongs to which installer. The list is only read for these installers, and it is downloaded when needed, so
these games need a network connection to install. `--guid` needs one too.

### What you will see

- **The game is on the list.** The install says `using the one listed for it` and carries on. There is nothing to do.
  A fix file for the game is named after that listed GUID, like any other.
- **The game isn't on the list yet.** The script warns you and uses the installer's own ID instead (the Inno Setup
  AppId, a code like `54f346df-1f81-49bd-8755-6b09d8f3f012`). The game still installs and plays. The only loss is that
  umu can't tell which game it is, so it can't give it its own settings. `--guid` prints the AppId, and a fix file
  for the game has to be named after it until the game is added to the list.
- **No network.** The script stops and says it couldn't download the list. Connect and run it again.

### Adding a game to the list

1. Run `sh zoom-platform-darth.sh --guid "Game-Setup.exe"`. For a game that isn't listed, it prints a warning and
   then the AppId.
2. Find the game's real ZOOM GUID in the
   [umu-database](https://github.com/Open-Wine-Components/umu-database/blob/main/umu-database.csv). Look for the game's
   title in the file. In the row for it, the second column says `zoomplatform` and the third is the GUID.
3. Add one line to `known-guids.ini`, with the AppId first, then the GUID, then a note after the `#`:

   ```ini
   54f346df-1f81-49bd-8755-6b09d8f3f012 = 2bba4b65-cd80-4b06-95db-8c87009f4bff  # Renoir, installer 1.0, umu-database
   ```

4. Check it. Run `--guid` again with `ZOOM_KNOWN_GUIDS_FILE` pointing at your edited file. It should print the real GUID
   now and no warning:

   ```sh
   ZOOM_KNOWN_GUIDS_FILE=./known-guids.ini sh zoom-platform-darth.sh --guid "Game-Setup.exe"
   ```

Then send it to us in one of two ways:

- **Open a pull request** with your new line in `known-guids.ini`. This is the quickest way.
- **Or open a [GitHub issue](https://github.com/DarthSidiousPT/zoom-platform-darth.sh/issues)** if you'd rather not edit the
  file. Write the game's name, the installer's file name, and the AppId that `--guid` printed. If the game isn't in the
  umu-database either, say so. We'll look for the GUID and add it.

## Part 1: replacing a shortcut

### When you need it

Sometimes a game installs fine, but its menu entry won't start it under Proton. It closes right away, or you get an
error about missing files. Necro Vision does this: its launcher starts the game from the wrong folder, so the game can't
find its own files.

If that's what's happening to yours, a fix file can swap the broken entry for launchers that do it right: the correct
`.exe`, the correct folder and the correct options.

### Find what to write

1. Install the game normally, with no fix file.
2. Open `<install folder>/drive_c/zoom_shortcuts/`. There is one `.sh` file for each launcher the script made. Open the one that doesn't work. Its last line looks like this:

   ```sh
   umu-run start /b /d "C:\\ZOOM PLATFORM\\Example Studio\\Example Quest" "C:\\ZOOM PLATFORM\\Example Studio\\Example Quest\\Launcher.exe"
   ```

   The folder after `/d` is where the shortcut starts from. Every path you write in the fix file is relative to that
   folder. (The file shows each backslash twice. In the fix file you write one.)
3. The shortcut's name is the file's name without `.sh` (here `Example Quest`). It is also the name of the entry in
   `~/.local/share/applications/zoom-platform/<game name>/`. That name goes into `replaces`.
4. Look inside the game's folder for the `.exe` that really starts the game, and for the folder it has to start in. Write
   both relative to the folder from step 2.

### Custom launchers

Each custom launcher gets its own `[launcher name]` section. The name you pick is what shows up in the menu, and it is
also the launcher's file name.

| Key        | What to put                                                                                                                                                     |
| ---------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `replaces` | The name of the shortcut this launcher stands in for (step 3). Several sections can replace the same shortcut, and then the installer's own launcher isn't made. |
| `exe`      | What to start, as a Windows path with `\` between the parts, relative to the folder from step 2.                                                                |
| `workdir`  | The folder to start it in, relative to the same folder. Optional. Left out, it is the folder itself.                                                            |
| `args`     | Command line arguments for the game. Optional.                                                                                                                  |

```ini
[Example Quest (windowed)]
replaces = Example Quest
exe      = Bin\ExampleQuest.exe
workdir  = Bin
args     = -windowed
```

If the script can't make any of your launchers (say you got a path wrong), it keeps the installer's own one, so the game
still has a menu entry. Necro Vision's file,
[cdd12f52-c7f4-4775-8fce-3bf3251353e7.ini](cdd12f52-c7f4-4775-8fce-3bf3251353e7.ini), is a real one to copy from.

### Try it

Install the game again with `ZOOM_GAME_FIXES_FILE` set, and look in the output for lines like
`Game fix: making "Example Quest (windowed)" in place of "Example Quest"`. A path that isn't there is reported as
`Game fix "<name>": "<path>" isn't there, skipping it`. Then start the new launchers from the menu.

## Part 2: Specific GE-Proton versions

### When you need it

The game installs and starts, but something is wrong that umu's default Proton doesn't handle. Kaan's intro and
cutscenes show colour bars, for example. If the same game works on GE-Proton, a fix file can tell the script to use that exact GE-Proton version, and that fixes
it for everyone.

The three values you will need:

- The **release tag** is the name *GloriousEggroll* gives a version, like `GE-Proton11-7`.
- The **asset** is the file to download for that version. A release lists several files under "Assets".
- The **checksum** is a 128-character fingerprint of that file. The script compares it with what it downloads, so it only
  ever installs the exact file you tested.

### Steps

1. Install the game into a new, test folder. Each install folder holds its own Wine prefix, and switching Proton builds on a prefix you care about can upset it.
2. Go to the [releases page](https://github.com/GloriousEggroll/proton-ge-custom/releases) and download the `.tar.gz` of the version you want to try. If you don't know which one, start with the latest release. If a release has both an `x86_64` and an `aarch64` file, take `x86_64`, which is the one for normal PCs. Unpack it where `umu` looks for Proton builds:

   ```sh
   mkdir -p ~/.local/share/Steam/compatibilitytools.d
   tar -xzf GE-Proton11-7-x86_64.tar.gz -C ~/.local/share/Steam/compatibilitytools.d
   ```

   This folder is the only place the script looks. A copy installed by a tool into Steam's own folder, or anywhere
   else, doesn't count.
3. Start the game on that build. Use the launch script the install made, with `PROTONPATH` set for this one run:

   ```sh
   PROTONPATH="$HOME/.local/share/Steam/compatibilitytools.d/GE-Proton11-7-x86_64" \
       sh "<install folder>/drive_c/zoom_shortcuts/<launcher name>.sh"
   ```

   Check the thing that was broken, and play for a while. Only a build you have tried should go into a fix file.
4. Get the three values from that release's page:
   - `proton` is the tag in the release's title and address, like `GE-Proton11-7`.
   - `proton_asset` is the file you downloaded, with its name copied exactly, like `GE-Proton11-7-x86_64.tar.gz`.
   - `proton_sha512` is in the small file next to it under "Assets" whose name ends in `.sha512sum`. Open it. It holds
     one line, the 128-character checksum followed by the file name. Copy only the 128 characters. You can also make
     it yourself from the file you tested with `sha512sum GE-Proton11-7-x86_64.tar.gz`. The two must match.
5. Put the three keys at the top of the fix file:

   ```ini
   proton        = GE-Proton11-7
   proton_asset  = GE-Proton11-7-x86_64.tar.gz
   proton_sha512 = 7db87e9787e20c35cbdac26018431d5794626b626e4067b050684e45a88cc2ca229d7d263519eafb2e168cde5bef57611065d159d3685aaec152ccb9abe3073f
   ```

   > [!WARNING]
   > Put the three `proton` lines at the very top of the file, above the first `[launcher name]` line. If they end up
   > below one, the script ignores them without saying anything, and the game keeps using the default Proton.

   Right, with the `proton` lines first:

   ```ini
   proton        = GE-Proton11-7
   proton_asset  = GE-Proton11-7-x86_64.tar.gz
   proton_sha512 = 7db87e97...

   [Example Quest (windowed)]
   replaces = Example Quest
   exe      = Bin\ExampleQuest.exe
   ```

   Wrong, with the `proton` lines below a launcher. The script ignores them:

   ```ini
   [Example Quest (windowed)]
   replaces = Example Quest
   exe      = Bin\ExampleQuest.exe

   proton        = GE-Proton11-7
   proton_asset  = GE-Proton11-7-x86_64.tar.gz
   proton_sha512 = 7db87e97...
   ```

6. Test the whole thing. Delete the build you unpacked in step 2, so the script has to download it, then install the
   game once more, into another new folder, with `ZOOM_GAME_FIXES_FILE` set. The output should include:

   ```
   Game fixes: this game is pinned to GE-Proton11-7
   Pinned Proton: downloading GE-Proton11-7-x86_64.tar.gz (only needed the first time)...
   Pinned Proton: checksum OK, unpacking...
   Pinned Proton: this game runs on GE-Proton11-7-x86_64
   ```

   Then start the game from the menu.

All three keys are needed. If one is missing, or a value has the wrong shape, the keys are ignored with a warning. The
asset name isn't worked out from the tag because GloriousEggroll's naming changed between releases (older ones are
`GE-Proton10-34.tar.gz`, newer ones `GE-Proton11-7-x86_64.tar.gz`).

### What happens at install time

- The build is downloaded once into `~/.local/share/Steam/compatibilitytools.d/<asset name without .tar.gz>`, after its
  checksum matched. If that folder is already there, the script uses it as it is and skips the download.
- The install and every launcher of the game use that build. The prefix remembers which one in `drive_c/zoom_proton`, so a
  DLC or a reinstall stays on the same build even when the DLC has no file of its own.
- When the script downloads the build, it leaves a small file called `.zoom-platform-downloaded` inside the folder. A folder that was
  already there (from ProtonUp-Qt, for example) gets none.
- If the build can't be had (offline, wrong checksum), the install goes on with umu's own Proton and says so.

### What happens when you start the game

Starting the game works without internet. The launch script only checks that the GE-Proton folder is still there. Tools
like ProtonUp-Qt and ProtonPlus can delete that folder without knowing a game uses it. If it's gone, the game starts on
umu's own Proton instead, and the script tells you, in the terminal and in a desktop notification ("GE-Proton11-7
removed. Reinstall the game."). Reinstalling the game brings the folder back, and that one does need internet. Which
tool shows the notification depends on the distro: `notify-send`, `gdbus`, `dbus-send`, `kdialog` or `zenity`, the first
one that works. Uninstalling can remove the build, see below.

### Getting the disk space back

Games can end up on different GE-Proton versions, and each one stays on disk after its game is gone. Only builds that have
the `.zoom-platform-downloaded` file are ever removed, and only when no installed game uses them:

- `uninstall.sh` asks if you want to remove the build too, after you confirmed removing the game. It's a separate question and
  the default is no, so you can remove the game and keep the build.
- `zoom-platform-darth.sh --remove-unused-proton` lists every unused build (for example the old one after a fix file moved
  a game to a newer version and you reinstalled it) and asks before removing anything. Add `--yes` (or `-y`) to skip the
  question, for a script or a cron job. It reads the answer from the terminal, so piped input can't answer it.

To skip `uninstall.sh`'s questions, pass `-y` (or `--yes`) to remove the game and keep its build, and
`--remove-unused-proton` to also remove the build. `sh uninstall.sh -y --remove-unused-proton` removes everything with no
questions, and `--remove-unused-proton` on its own still asks about the game. If another game uses the build, or this
script didn't download it, the option does nothing for it and the result says it was kept.

A build is kept if another game uses it, if Steam's `config.vdf` mentions it, or if it has no note file. A game whose
launcher points to a drive that isn't mounted stops all removals, because that game might need any of them. Versions
downloaded by older releases have no note file, so delete those by hand from `~/.local/share/Steam/compatibilitytools.d/`
or with ProtonUp-Qt.

### Warnings and what they mean

| In the output                                                                   | What it means                                                                                |
| ------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------- |
| `Game fixes: none for this game`                                                | There is no file for this GUID. Check the file name.                                         |
| `Game fixes: couldn't get the file (curl exit ..., HTTP ...)`                   | The file couldn't be fetched (no network, or GitHub had a problem). The install goes on without it. |
| `ignoring "proton": proton, proton_asset and proton_sha512 must all be given`   | One of the three keys is missing, misspelled, or below a `[section]`.                        |
| `ignoring "proton": proton must look like GE-Proton11-7`                        | The tag has the wrong shape.                                                                 |
| `ignoring "proton": proton_asset must be the proton value followed by ...`      | The asset name doesn't match the tag.                                                        |
| `ignoring "proton": proton_sha512 must be 128 lowercase hex characters`         | The checksum was cut short, has a typo, or is in capitals.                                   |
| `Pinned Proton: couldn't download ...`                                          | No network, or the tag or asset name doesn't exist on GitHub.                                |
| `Pinned Proton: ... doesn't match the checksum in the game fixes file`          | The file on GitHub isn't the one the checksum was made from.                                 |
| `ignoring "<registry path>": the key ... is not allowed`                        | The path goes through a key that a fix file can't write. See [Part 3](#part-3-registry-values). |
| `ignoring "<registry path>": the path must start with HKCU\ or HKLM\`           | The path has the wrong shape. It must be `<root>\Software\<key>\<value name>`.               |
| `ignoring "<registry path>": a dword must be a number ...`                      | The part after `=` is wrong: a `dword` takes digits only, and the type is `dword` or `sz`.   |

## Part 3: Registry values

### When you need it

Some games read a setting from the Windows registry that their installer doesn't write. e-Racer is one: it sets a very
dark gamma curve at startup, and Wine applies it as it is, so the 3D scene is almost black. The game has a switch
called `NoGamma` that skips that step, but it only works when a registry value of that name exists. A fix file can set
values like that while the game installs.

### Write the values

Put them in a section called `[wine registry]`. Each line is the full path of one value, then `=`, then its type and
its data:

```ini
[wine registry]
HKCU\Software\Rage Games Ltd\eRacer\NoGamma = dword:1
```

The last part of the path is the value's name, and everything before it is the key. There are two types:

- `dword:<number>` is a number from 0 to 4294967295, written in plain decimal.
- `sz:<text>` is text. It can't end with a backslash.

Only `HKCU\Software\...` and `HKLM\Software\...` are accepted, with at least one key below `Software`. A 32-bit game
reads its `HKLM` values from `HKLM\Software\WOW6432Node\...`, so write that path for those.

A few keys are refused because they can start programs or register code: `Run`, `RunOnce`, `Winlogon`, `Classes`,
`Policies`, `Explorer`, `App Paths`, `AeDebug`, `Command Processor` and `Image File Execution Options`. Under `Wine`,
only `DllOverrides` is accepted. This is a best-effort list, since Wine isn't a sandbox. A refused line is skipped with
a warning and the others still apply.

`wine registry` is the one section name that isn't a launcher, so don't give a launcher that name.

### What happens at install time

The values are set after the installer finishes, because the installer writes the game's own key and you want yours to
come after it. Installing a DLC or reinstalling the game sets them again, which changes nothing. Nothing touches the
registry when the game starts.

### Try it

Install the game again with `ZOOM_GAME_FIXES_FILE` set. The output should include:

```
Game fixes: 1 registry value(s) for this game
Game fixes: setting 1 registry value(s)...
```

Then look for the value in `<install folder>/user.reg` (`HKCU` values), or in `system.reg` for `HKLM` ones. e-Racer's
file, [94c96dc7-8c5a-4c5f-ab44-a5dcf879d539.ini](94c96dc7-8c5a-4c5f-ab44-a5dcf879d539.ini), is a real one to copy from.

## Part 4: Files

### When you need it

Some fixes need a file in the game's folder. e-Racer is the example: under Proton it runs at the screen's refresh rate
(75 frames per second on a 75 Hz screen), and parts of its game logic seem to follow the frame rate. A small replacement
`ddraw.dll` caps it at 60. A fix file can copy files like that out of a zip while the game installs.

### Get the zip ready

Put the zip in `game-fixes/files/`. The fix file needs its SHA-512, see
[Getting a SHA-512 checksum](#getting-a-sha-512-checksum) at the top of this page.

The source of the e-Racer one, and a script that rebuilds it, are in `game-fixes/src/ddraw-limiter/`. Rebuilding gives the
same zip, byte for byte, as long as the compiler version is the same.

### Write the section

```ini
[files]
zip          = ddraw-limiter-1.0.zip
zip_sha512   = <128 lowercase hex characters>
files        = ddraw.dll, LICENSE-ddraw-limiter.txt
config       = ddraw-darth.ini
backup       = ddraw.dll
dll_override = ddraw
```

- `zip`, `zip_sha512` and `files` are required. The others are optional.
- `zip` is the name of a file in `game-fixes/files/`. It must end in `.zip`.
- `files` are the names to copy out of the zip, separated by commas. They are always overwritten.
- `config` names files that are copied only when they aren't in the game's folder yet, so a reinstall keeps what the
  player changed.
- `backup` names files from `files` to keep first. The original is saved as `<name>.orig`, only if there is no `.orig`
  yet, so the backup is always the file ZOOM shipped.
- `dll_override` is a DLL name, like `ddraw`. After the files are copied, Wine is told to use the DLL from the game's
  folder instead of its own. Don't write this as a `[wine registry]` line: older versions of the script would set it
  without copying the DLL, and the game wouldn't start.

Names take letters, digits and `. _ -` only, and can't include a folder. The zip's own paths are never used.
`files` is a reserved section name, like `wine registry`, so don't give a launcher that name.

### What happens at install time

The zip is downloaded when the install starts and checked against its SHA-512, so a bad one shows up before the
installer runs. After the installer finishes, the script looks up the game's folder, unpacks the zip into a temporary
folder (with `unzip`, `bsdtar` or `python3`, whichever the system has) and copies the named files. Installing a DLC or
reinstalling the game does it again, because ZOOM's installer puts its own files back each time.

If anything goes wrong, the game keeps ZOOM's files and the install carries on. That includes a download that fails, a
wrong checksum, a zip that won't unpack, a name the zip doesn't have, and a system with none of the three tools. When the
fix file asks for a `dll_override`, a failure also removes any override that an earlier install left behind. Otherwise
Wine would load the DLL that ZOOM just put back, and the game would crash.

Nothing happens when the game starts, and nothing is downloaded then.

### Going back by hand

Copy `ddraw.dll.orig` over `ddraw.dll` in the game's folder, then remove the override:

```sh
umu-run reg delete 'HKCU\Software\Wine\DllOverrides' /v ddraw /f
```

### Try it

Run the script with `ZOOM_GAME_FIXES_FILE` set to your file, and `ZOOM_GAME_FIXES_FILES_DIR` set to the folder that holds
the zip (without it, the script downloads the zip from the `main` branch, which has a 404 until your change is merged).
The output should include:

```
Game fixes: files from ddraw-limiter-1.0.zip: ddraw.dll,LICENSE-ddraw-limiter.txt (and, if missing, ddraw-darth.ini)
Game fixes: reading ddraw-limiter-1.0.zip from <folder> (from ZOOM_GAME_FIXES_FILES_DIR)
Game fixes: kept the original ddraw.dll as ddraw.dll.orig
Game fixes: copied ddraw.dll
```

Then look in the game's folder for the files and the `.orig`, and in `<install folder>/user.reg` for the override.
e-Racer's file, [94c96dc7-8c5a-4c5f-ab44-a5dcf879d539.ini](94c96dc7-8c5a-4c5f-ab44-a5dcf879d539.ini), is a real one to copy from.

## Example: a game that needs both

A made-up game, Example Quest. Its ZOOM shortcut starts `Launcher.exe`, which fails under Proton, and its cutscenes only
work on GE-Proton. Its file is named after its GUID (here a dummy one), `game-fixes/00000000-0000-4000-8000-000000000000.ini`:

```ini
# Example Quest
#
# Launcher.exe starts the game from the wrong folder, so two launchers start it from
# its own Bin folder instead. The cutscenes only play on GE-Proton, so the game uses
# the GE-Proton version that was tested.

proton        = GE-Proton11-7
proton_asset  = GE-Proton11-7-x86_64.tar.gz
proton_sha512 = 00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

[Example Quest (windowed)]
replaces = Example Quest
exe      = Bin\ExampleQuest.exe
workdir  = Bin
args     = -windowed

[Example Quest (fullscreen)]
replaces = Example Quest
exe      = Bin\ExampleQuest.exe
workdir  = Bin
```

The checksum above is a dummy, so this file would be refused with "doesn't match the checksum". A real file has the
128 characters from the release's `.sha512sum`.

- The `proton*` keys sit above any section, so they apply to the whole game.
- `[Example Quest (windowed)]` and `[Example Quest (fullscreen)]` are two launchers. Both replace the shortcut called
  `Example Quest`, so the installer's own launcher isn't made and the menu gets these two instead.
- `exe` and `workdir` are relative to the folder `Launcher.exe` lives in, which is where the shortcut starts from.
  `Bin\ExampleQuest.exe` is `<that folder>\Bin\ExampleQuest.exe`.
- Both launchers run on that GE-Proton version, because it applies to the whole game.

## What the script checks

The file comes off the network and ends up in a generated shell script, so every value is checked before use. Paths
take letters, digits, space and `. _ ( ) + , -` only, must be relative, and can't contain `..`. Arguments take letters,
digits, space and `+ . _ , = : / -` only. A launcher that fails a check is skipped with a warning. The Proton keys are
held to the shapes above: the tag is `GE-Proton<N>-<N>`, the asset is the tag plus `.tar.gz` or `-x86_64.tar.gz`, and
the checksum is 128 lowercase hex characters. A value that fails is ignored with a warning. Registry paths take the
same characters as launcher paths, and `sz` text also takes `: = \`. Quotes, `%`, `&` and `|` are refused. In `[files]`,
the zip name and the file names take letters, digits and `. _ -` only, with no folders, and the checksum is 128 lowercase
hex characters. The zip is copied from by name only, after its SHA-512 matched.
