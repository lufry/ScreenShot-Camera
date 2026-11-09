# ScreenShot Camera — WoW Forever

Camera framing, color overlays and clean screenshots for **WoW Forever 1.60.1.70862 only**.
Addon version **1.0.0**, interface **16001**. Retail, Classic and other client builds are not supported.

## Features

- Horizontal camera offset and dynamic pitch controls.
- Brightness, shade/haze and temperature overlays. These are visual tints, not image post-processing.
- A native Forever panel with the client's borders, buttons, stepper sliders and scrolling dropdown.
- The 22 animated emotes from the standard **Emote** submenu beside chat, with localized labels and ordering. The separate voice/speech menu is excluded.
- Clean captures that hide the UI, optionally perform an emote, and restore the UI on screenshot completion or failure.
- A draggable minimap shortcut and an entry in the native AddOns settings.

## Installation

1. Copy the repository's `ScreenShotCamera` folder into:
   `World of Warcraft/_forever_/Interface/AddOns/`
2. Check that the resulting folder directly contains `ScreenShotCamera.toc` and `ScreenShotCamera.lua`.
3. Enable **ScreenShot Camera**, log in using Forever **1.60.1.70862**, and enter `/ssc`.

The addon checks both the Camelot project and the exact client build. Enabling “Load out of date AddOns” does not bypass the check. Update the addon before using a later Forever build.

Existing saved settings are migrated automatically. Old emote selections outside the standard animated submenu are cleared.

## Commands

| Command | Action |
| --- | --- |
| `/ssc` or `/screenshotcamera` | Open or close the panel. |
| `/ssc on` | Enable camera offsets and filters. |
| `/ssc off` | Disable them and restore the captured camera preferences. |
| `/ssc reset` | Reset sliders and clear the selected emote. |
| `/ssc shot` | Take a clean screenshot with the current settings. |
| `/ssc help` | Show the command summary. |

The screenshot button also works with camera adjustments disabled. An emote adds a 1.5-second delay;
without one, capture waits 0.2 seconds for the UI to disappear. Screenshot files are written by WoW
to its normal `Screenshots` directory.

Camera changes and clean captures are paused during combat. If combat starts during the delay,
the capture is cancelled; UI restoration is retried after combat if the client blocks it.
Only one capture can be pending, and a ten-second watchdog restores the UI if no result arrives.
An already-hidden UI is left hidden.

## Verification and limitations

The implementation was reviewed against the exact Blizzard UI source snapshot for build 70862
and tested with a Lua 5.1 API harness. In-game rendering, camera CVar availability and protected-frame
behavior still need a smoke test in WoW. This release does not claim native-client validation.

The `ScreenShotCamera` folder contains only the addon files required by the game.

## Credits

Ideated by **Tumnus-Nemesis**. Developed by **Luca + Codex**.
