# v1.5.2-darth

## Script Improvements

This _new_ small version includes a nice improvement for the `game-fixes`: can now copy files from a zip into a game's folder while the game installs. This is something that was done for scenarios where we need to pack files and configs for a specific game. In the case this will start with the game e-Racer.

## `game-fixes` structure

Now, alongside the usual `<zoom_id>.ini` files, we have **two new folders**: one contains the `/files` that will be downloaded (the final package) and the other will be the source-code for fixes, and they stay under `/src`.

## Game specific improvements

- v1.5.2-darth includes an alternative `ddraw.dll`, alongside its own _config_ file (`ddraw-darth.ini`) which serves to limit the framerate, by default, to 60 FPS with VSync on for the game **e-Racer**. You can check the current issues and solutions for this game on our [discussions topic](https://github.com/DarthSidiousPT/zoom-platform-darth.sh/discussions/3).
