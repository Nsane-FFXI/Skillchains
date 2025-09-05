# Skillchains Addon (Windower)

## Overview
Displays what weapon skill (WS) or ability to use next to build or close a skillchain. Shows a timer, current step, possible next actions, and elements for magic bursts.

## Prema Weapon Detection
If you equip a Prema weapon listed in the addon’s `prema_weapon` table:

- Automatically detects by matching the item ID of your main or ranged weapon.
- Flags it as Aeonic in `info.aeonic`.
- Adds Aeonic skillchain properties to your WS (extra Radiance or Umbra tier).
- Colors WS in the list by Aeonic tier:
  - **Tier 1** = yellow  
  - **Tier 2** = orange  
  - **Tier 3** = red
- Adjusts simulation/test results to include Aeonic properties if Aftermath (AM1–AM3) is active.
- Suggestion and preview output includes extra Lv.4 SC options and highlights WS differently when Aeonic effects apply.

## Installation
1. Place `Skillchains.lua` and `skills.lua` into `Windower/addons/Skillchains/`
2. In game:  
   ```
   //lua load sc
   ```

## Commands
| Command | Description |
| ------- | ----------- |
| `//sc move` | Toggle overlay and allow dragging |
| `//sc save` | Save settings for current character |
| `//sc save all` | Save settings for all characters |
| `//sc colors` | Toggle colors |
| `//sc colors on/off` | Force colors on/off |
| `//sc aeonic` | Show Aeonic boost when others act |
| `//sc burst` | Toggle magic burst element list |
| `//sc weapon` | Toggle weapon skill list |
| `//sc spell` | Toggle spell list (SCH, BLU) |
| `//sc pet` | Toggle pet abilities |
| `//sc props` | Toggle skillchain property line |
| `//sc step` | Toggle step number line |
| `//sc timer` | Toggle timer line |
| `//sc test "WS"` | Preview using WS |
| `//sc test "SC"` | Pretend an SC just happened |
| `//sc test "WS" "SC"` | See follow-up WS for that SC |
| `//sc test {WS} {SC}` | Same as above |

## Test Feature
Run simulations without combat. Examples:
```
sc test Tachi: Fudo
sc test Tachi: Fudo Fusion
sc test Fusion Tachi: Fudo
sc test Fusion
```
- Can use in-game auto-translate in tests.

## Tips
- Overlay shows only when an SC window is active or in test mode.
- Aeonic weapons are auto-detected.
- Move overlay with `move`, then save.
- Requires correct `skills.lua`.

## Credits
- **Ivaar** — Original author  
- **Nsane** — Additional features
