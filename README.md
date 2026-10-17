# BedWars (Godot 4.2+) - prototype, UNTESTED (written without a Godot install)

Import project.godot in Godot 4.2+, press F5. Check the Output panel for errors first.

## Controls (all keyboard keys can be rebound in Esc > Settings)
WASD move, Space jump, Shift sneak (slow, can't fall off edges), Ctrl sprint, LMB attack / hold to break,
RMB place block (hold = auto place when green) / eat apple / throw fireball / hold to draw bow and release to shoot,
1-9 or wheel = slot, Q drop one item, E shop, B hotbar manager (click two slots to swap), Esc pause + settings.

## Match
8 teams, 4 fighters each (you + 3 bots on your team). Each team has a half-height bed (blanket + pillow) on its island
outside the house. Break an enemy bed, then eliminate that team's fighters. Your own bed can't be broken by you.
If your bed is destroyed you can't respawn; if you die then, it's defeat. Eliminate every other team to win.
The right side of the screen lists every team with BED OK / NO BED / OUT and living members.
Respawn is at your house after 3s (while the bed lives). Dying deletes everything on your hotbar.

## Items and economy
Houses drop coins through the roof skylight (1 per 3.0s, -0.1s every 5 min). Emeralds drop on top of the middle tower.
Shop (E): wool/stone/wood/reinforced (reinforced survives TNT), Sword 10c (damage 2, max 1), Axe 6c (2.5x faster
breaking), Bow 12c + Arrows x8 4c (charge up to 1s: faster + more damage, arrows stick in blocks), Golden Apple 5c,
TNT 6c (4s fuse, flashes red/white and swells, then a big blast), Fireball 10c (4 damage direct hit; on a block it breaks
nearby blocks and hurts/knocks back anyone about a block away). Sword upgrades cost emeralds: 3 / 6 / 12 (damage 3 / 4 / 5).
Health and hunger are 10. Falling more than 3 blocks costs half a heart, +half a heart per extra block.
Unbreakable: island ground and the obsidian house corner pillars.

## Bots
Defender (1 per team): fortifies the bed with blocks and fights intruders. Raiders: raid enemy beds (TNT when they have it),
bridge gaps, mine through walls, use bow / fireballs at range, retreat when hurt, eat apples, buy gear and sword upgrades.

## Other
Procedural block textures and sounds (no asset files). Settings saved in user://settings.cfg.
Performance: 32 fighters total. If slow, lower TEAM_SIZE in scripts/main.gd.
Not implemented: armor, main menu / map select, saved progress and cosmetics, export preset.

## Update: lobby, potions, map, new tools
- Lobby: the game starts in a lobby (Start Game / Settings / Quit). Start shows a loading bar, then the world is built behind a
  second loading screen. "Main menu" buttons are in the pause menu and on the victory / defeat screen.
- Map: a minimap follows you in the top-left; the map key (M) opens a big map of the whole world with bed squares and player dots.
  (In the Godot editor, run the game and use the Remote tab in the Scene dock to inspect the generated world.)
- Sword: every left click swings (animation + sound), hitting what you aim at. Axe: hold left click near an enemy to charge
  (bar under the crosshair), release for 2 to 7 damage.
- Water bucket (8 coins): right click while falling to land in water with no fall damage (3s cooldown).
- Emeralds buy potions: Invisibility 2, High jump 2, Strength 3 (+1.5 damage), Poison 3 (poisoned weapon: hits poison for 6s).
- Bow: while drawing, a dotted line and a marker show where the arrow will land (red when it will hit an enemy).
- Bots drop all their coins, emeralds and items when they die. Raiders clear a walled-in bed with TNT / by hand, then break it.
  TNT breaks unbreakable blocks (not beds). Your 3 teammates share your team name tag and cannot be hurt unless you enable
  Friendly fire in Settings (a message tells you when you aim at a teammate).
- Hotbar keys (1-9) and the map key are rebindable in Settings. Item icons are drawn as proper 2D art.
# bedwars-game
# bedwars-game


## Update: logo, new lobby, Store build
- Logo is in assets/logo.png (used in lobby + loading screens + app icon). Lobby redesigned (animated sky, islands, tips, How to Play).
- Top-left debug text removed from the in-game HUD.
- Microsoft Store x86 APPX: see STORE_BUILD.md and build_appx.ps1.
# bedwars-game
# bedwars-game
