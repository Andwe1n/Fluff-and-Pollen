FLUFF & POLLEN v1.1 — MEADOW & MAGIC

START
Extract the ZIP first.
Windows 64-bit: open Windows/Fluff-and-Pollen.exe.
Linux 64-bit: open Linux/Fluff-and-Pollen.x86_64.
If needed on Linux: chmod +x Fluff-and-Pollen.x86_64
Godot is not required to play. Executables are unsigned.

CONTROLS
WASD / arrow keys: move
E near the shop: open the Hive Atelier
SPACE: Petal Dash, when equipped
Q: Meadow Breeze, when equipped
Escape: pause, close shop, or return from settings/help
Mouse: menus, ability cards, training, and equipment

GAMEPLAY
Collect pollen from flowers and return to the wooden depot to bank it.
One pollen gives two coins. Bees spill carried pollen on contact;
banked coins and purchased abilities are always safe.
Deliver 60, 100, and 150 pollen to finish the three meadows.
Flowers regrow after eight seconds. Dotted lines show patrol routes.

SHOP
Select one of seven ability cards to see details and prices.
Owned abilities can be equipped or unequipped for free. Three equipped
skills are allowed. Purchases with a full loadout ask which skill to replace
before spending coins. The Training tab upgrades six skills to Level II.
Shield is a single-rank skill and recharges on a nonempty delivery.
Magnet cannot pull pollen through shrubs. Lucky bonuses need bag space.
Menus pause gameplay, regrowth, active effects, and cooldowns.

SAVES
v1.0 saves are read automatically from the same game save folder.
The first conversion keeps campaign.json.v1-backup for rollback.
Continue returns to the base; unbanked pollen is not saved.
New campaign asks before replacing progress.
Windows: %APPDATA%/Godot/app_userdata/Fluff & Pollen/
Linux: ~/.local/share/godot/app_userdata/Fluff & Pollen/
To return to v1.0, close the game, preserve your current campaign.json,
then copy campaign.json.v1-backup to campaign.json before starting v1.0.

EDIT / EXPORT
Import Source/fluff-and-pollen/project.godot into Godot 4.4.1 and press F5.
Install matching Godot export templates to rebuild the executables.
No external plugins are required. Original art sheets are unchanged.
New foliage and skill icons are drawn in Godot. Bee wing/body layers are
extracted from the original sprite at runtime and animated independently.

INCLUDED
Windows/ and Linux/: standalone games
Source/: editable project and automated tests
CHANGELOG.txt: changes and ability prices
TEST-REPORT.txt: completed validation and limitations
Gameplay.png, Shop.png, Training.png: real game screenshots
Bee-flight.gif: short capture of the new animation
GODOT-LICENSE.txt: engine and third-party notices
