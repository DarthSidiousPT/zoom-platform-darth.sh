# v1.5.0-darth

**This release brings some really nice improvements to the `zoom-platform-darth.sh` script. The main highlights are**:

### Bypass outdated installers

On a very limited sample of games I've tested, a few didn't install because the game installers lack a game ID (provided by ZOOM installers) and display a _"doesn't seem to be a ZOOM Platform installer"_ message. This can only be _officially_ solved on ZOOM's side by updating each game installer. To bypass this, I've added a new database-like file inside `game-fixes/known-guids.ini` which does a translation between the installer ID (that one is always available) and the expected ZOOM GUID.

To prevent the block from installing games, where we don't even know the official GUID, the script will still install using the installer's own ID. Unfortunately, to achieve this, we need to have an internet connection, so this part can't be 100% offline (unless we store the DB on the script, which I don't want to do for now).

### Ability to remove unused GE-Proton installs

In v1.4.0-darth I included a new feature which was to use GE-Proton to fix specific games. This new version continues that work with more games added, more specifically to the videos that don't play on Valve's Proton (and umu).

This will probably create a problem in the future, as newly added games will use different GE-Proton versions, so to maintain this, a new parameter was added to manually remove unused Proton versions. The `uninstall.sh` that each game creates also takes this into account and, if no other game is using that specific Proton version, it will prompt you *if* you want to remove it or not. This functionality also takes into account if somehow you are using this GE-Proton with any Steam game.

### Full detailed changes

- `zoom-platform-darth.sh` now installs older ZOOM installers that don't have the game's ID inside, like Renoir and Postal, and probably several other games. The official script doesn't recognize them and shows "doesn't seem to be a ZOOM Platform installer".
- `zoom-platform-darth.sh` also needs an internet connection for those _broken_ installers, just to read that list, and `--guid` does the same. If the game isn't listed there (it has to be added to it manually), the install still goes ahead with the installer's own ID, and you will get a warning asking you to report the game here.
- `game-fixes/known-guids.ini` is the _database_ for games with these broken installers, with Renoir, Postal, Arctic Adventure and Pharaoh's Tomb in it (for now). To add another one, check `game-fixes/README.md` for how to do it by pull request or by opening an issue.
- `game-fixes/` has fixes for Renoir, EQI and Warm Up!, whose videos don't play properly on umu's default Proton. They run on a specific GE-Proton version instead.
- `uninstall.sh` now also offers to remove the game's specific GE-Proton version when no other game uses it, so the disk space comes back. It's a separate question after the game's own `y`, and the default is to keep it. Only versions that `zoom-platform-darth.sh` downloaded itself are removed. Ones you installed with ProtonUp-Qt or Steam are never touched, and neither are versions downloaded by older releases (those need deleting by hand). To skip its questions, use `-y` (or `--yes`), which removes the game and keeps the version, and `--remove-unused-proton`, which also removes the version without asking when no other game uses it. Together they remove everything with no questions.
- `zoom-platform-darth.sh --remove-unused-proton` lists the GE-Proton versions that no game uses any more and asks before removing them, for versions left behind when a fix moved a game to a newer one. Add `--yes` (or `-y`) to remove them without asking, which also works without a terminal, for a script or a cron job.
