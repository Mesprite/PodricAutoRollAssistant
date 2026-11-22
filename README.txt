PODRIC AUTOROLL 0.1.1-beta | WoW Forever 1.60.1

Install: fully exit WoW. Extract the PodricAutoRoll folder into
World of Warcraft/_forever_/Interface/AddOns/ and start the game.
Open Options > AddOns > Podric AutoRoll, or type /par to open settings.
/par off and /par on toggle automation.

Click the action next to any preset to cycle Manual, Greed, Need, Pass.
Right-click reverses the cycle. Rules and checkboxes save account-wide.
Add a custom item by focusing the input field and shift-clicking a link,
pasting a link, or entering its numeric item ID. Its rule overrides a
preset for that item. X removes the override, restoring preset behavior.
Unlisted items are always manual. An unavailable action stays manual;
there is no automatic fallback. No roll is made unless the group loot
system opens a roll for the item.

Defaults: Need Righteous Orb and three Scourgestones; Greed nine ZG
coins, nine ZG bijous, five Argent Dawn turn-in materials and eight AQ
scarabs; Manual AQ idols, Dark Rune and both Black Diamonds.
Binding confirmation is enabled for the addon's own tracked Need/Greed
rolls only. Manual rolls are never deliberately confirmed by this addon.
Disable the checkbox if you want the game's binding confirmation.
Use Need only when the group agrees; disable automation for special loot
rules. Disable other automatic loot-roll addons to avoid conflicts.

Compatibility: Interface 16001, documented modern loot-roll APIs.
Item IDs use the Classic baseline; verify new/changed Forever items in
client and add custom overrides. Not yet tested in the live WoW client.
No external libraries, periodic scanning, or combat log processing.

Changes in v0.1.1-beta
---------------------
Added the full configuration panel to the game's AddOns options menu.
Existing rules and saved variables are unchanged.
