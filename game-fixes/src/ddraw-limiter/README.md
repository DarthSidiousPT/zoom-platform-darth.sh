# ddraw limiter

A small `ddraw.dll` that caps e-Racer at 60 frames per second on Linux. Under Proton the game runs at the screen's refresh rate (75 FPS on a 75 Hz screen), and parts of its game logic seem to follow the frame rate: in hand tests, collision damage looked lower at lower frame rates, while the car's speed looked the same from 20 to 300 FPS.

It is a proxy: it loads Wine's own ddraw, hands every call to it, and only waits a little before each `Flip` so the game never presents more than 60 times a second.

## Status

Tried by hand on UMU-Proton with the e-Racer base game and the Track Pack DLC, on a 60 Hz and a 75 Hz screen. It holds a steady 60 FPS in both. Without it, the game runs at the screen's rate (75 FPS at 75 Hz). It is not used by the script yet: nothing installs this file for you.

On a screen that is not 60 Hz the picture can't be perfectly smooth, because 60 frames don't fit evenly into the refreshes. With vsync on (the default) it looks better than with vsync off, at the cost of slightly more input lag.

It is untested on Windows. The game's folder already has DDrawCompat there, and this DLL replaces it, so Windows users would lose its fixes.

## Build

You need mingw-w64 (on Debian/Ubuntu: `gcc-mingw-w64-i686`).

```sh
sh build.sh [OUTPUT_DIR]
```

This writes `ddraw-limiter.zip` to `OUTPUT_DIR` (`./out` by default) and prints its SHA-512. The zip holds `ddraw.dll`, `ddraw-darth.ini` and the license. The DLL is 32-bit because e-Racer is.

The build is reproducible: the same source and the same compiler give the same bytes, whatever the time, folder or time zone. Another compiler version can give a different DLL, so the zip in `game-fixes/files/` is the one the script checks.

## Settings

`ddraw-darth.ini` sits next to the DLL in the game folder. Without it, the defaults apply.

```ini
[limiter]
fps = 60
vsync = on
```

- `fps`: the highest frame rate the game may present, a whole number from 0 to 1000. `0` turns the cap off. Anything else (text, a negative number, more than 1000) means 60.
- `vsync`: `on` or `off`, in any capitals (`OFF` works the same as `off`).
  - `on`: the game waits for the screen as usual.
  - `off`: the game never waits, so frames come out at the `fps` cap and the picture can tear.
  - `no` and `false` also mean `off`. Any other text, even `0`, means `on`.

The game reads the file once, when it starts. `vsync = off` only stops the game from waiting. If Mesa or the desktop still syncs to the screen, the frame rate stays at the refresh rate (on the test machine it needed `vblank_mode=0` as well).

## Try it by hand

1. Copy the original `ddraw.dll` from the game folder somewhere safe, then put the new `ddraw.dll` (and, if you want to change the settings, `ddraw-darth.ini`) from the zip in its place.
2. Tell Wine to use the file in the game folder:

   ```sh
   umu-run reg add 'HKCU\Software\Wine\DllOverrides' /v ddraw /d native,builtin /f
   ```

To go back, copy the original `ddraw.dll` over ours and delete the override (`reg delete 'HKCU\Software\Wine\DllOverrides' /v ddraw /f`).

## License

BSD 3-Clause, see the `LICENSE` in this folder. It is a separate file from the one at the root of the repository, which
names ZOOM Platform as the copyright holder of the original project; this DLL is new code with its own copyright line.
The zip carries the same text as `LICENSE-ddraw-limiter.txt`, and the DLL has the copyright and the repository URL in its
version information and as a plain string.
