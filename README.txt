Skillchains Addon (Windower)
----------------------------

What it does:
Shows what WS/ability to use next to build or close a skillchain. Displays a timer, current step, possible next actions, and elements for magic bursts.

If you equip a Prema weapon listed in the addon’s prema_weapon table, the addon:
Detects it automatically by matching the item ID of your main or ranged weapon.
Flags it as Aeonic in info.aeonic.
Adds Aeonic skillchain properties to your weapon skills (extra Radiance or Umbra tier).
Colors your WS in the list with the Aeonic tier color:

Tier 1 = yellow
Tier 2 = orange
Tier 3 = red

Adjusts simulation/test results to include Aeonic properties if you have Aftermath active (AM1–AM3).

This means the skill suggestions and previews will show extra Lv.4 SC options and highlight your WS differently when the weapon’s special properties apply.

Install:
1. Put "Skillchains.lua" and "skills.lua" in Windower/addons/Skillchains/
2. In game: //lua load sc

Commands:
//sc move           → Turn overlay on/off and move it by dragging.
//sc save           → Save settings for this character
//sc save all       → Save for all characters
//sc colors         → Toggle colors
//sc colors on/off  → Force colors
//sc aeonic         → Show Aeonic boost when others act
//sc burst          → Toggle magic burst element list
//sc weapon         → Toggle weapon skill list
//sc spell          → Toggle spell list (SCH, BLU)
//sc pet            → Toggle pet abilities
//sc props          → Toggle skillchain property line
//sc step           → Toggle step number line
//sc timer          → Toggle timer line
//sc test "WS"              → Preview using WS
//sc test "SC"              → Pretend a SC just happened
//sc test "WS" "SC"         → See follow-up WS for that SC
//sc test {WS} {SC}         → Same as above


Test feature:
- Can now sit in town and have a window open like you were using a weaponskill or making a skillchain
  Examples,
     sc test Tachi: Fudo
     sc test Tachi: Fudo Fusion
     sc test Fusion Tachi: Fudo
     sc test Fusion

Can use the in game auto-translate for testing.


Tips:
- Shows only if an SC window is active on your target or when using "test"
- Aeonic weapons auto-detected
- Drag overlay with "move", then save
- Requires correct "skills.lua"

Credits:
Ivaar (original), Nsane (extra features)