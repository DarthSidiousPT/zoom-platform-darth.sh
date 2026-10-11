## Script Improvements

- `zoom-platform-darth.sh`: a fix file can now set the Wine override for more than one DLL. The new `dll_overrides` key takes a comma separated list, like `ddraw, dinput`.

## `game-fixes` changes

- `game-fixes/files/eracer-fixes-1.0.zip` is the new package for e-Racer, now. It holds the 60 FPS limiter and a gamepad layer (Xidi) together.

## Game specific improvements

- **e-Racer** now gets Xidi 5.0.0, for Xbox (and other XInput) gamepads. To avoid stick drift, `Xidi.ini` in the game's folder sets a 10% deadzone for the left stick. You can change `DeadzonePercentStickLeft` yourself.
- If **e-Racer** freezes when you bind a gamepad button that another action already uses, open Controls in the main menu, pick Default at the bottom and bind again. The game does this on Windows too, in my tests. You can check the current issues and solutions for this game on our [discussions topic](https://github.com/DarthSidiousPT/zoom-platform-darth.sh/discussions/3).
