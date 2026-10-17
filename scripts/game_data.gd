extends RefCounted
# Shared constants. Use: const GD = preload("res://scripts/game_data.gd")
const AXE_DAMAGE := 4
const BED_BASE := 7          # block ids 7..14 = team beds / team colors
const OBSIDIAN := 15         # unbreakable
const PILLOW := 16           # white pillow half of every bed
const NAMES := {1: "Wool", 2: "Stone", 3: "Wood", 4: "Reinforced", 20: "Sword", 21: "Axe", 22: "Golden Apple",
	23: "TNT", 24: "Bow", 25: "Arrow", 26: "Fireball", 27: "Water Bucket", 28: "Invisibility Potion",
	29: "Jump Potion", 30: "Strength Potion", 31: "Poison Potion"}
const STACK := {1: 64, 2: 64, 3: 64, 4: 64, 20: 1, 21: 1, 22: 16, 23: 16, 24: 1, 25: 64, 26: 16, 27: 1,
	28: 4, 29: 4, 30: 4, 31: 4}
const ITEM_COLORS := {20: Color(0.80, 0.85, 0.92), 21: Color(0.6, 0.4, 0.2), 22: Color(1.0, 0.85, 0.1),
	23: Color(0.85, 0.12, 0.12), 24: Color(0.55, 0.36, 0.16), 25: Color(0.75, 0.75, 0.78), 26: Color(1.0, 0.5, 0.1),
	27: Color(0.65, 0.68, 0.75), 28: Color(0.70, 0.85, 1.0), 29: Color(0.30, 0.90, 0.40), 30: Color(0.95, 0.25, 0.25),
	31: Color(0.45, 0.75, 0.20)}
const DESC := {
	1: "Cheap block. Breaks very fast. Great for bridges.",
	2: "Sturdy block. Takes a while to break.",
	3: "Wood block. Medium strength, good for defenses.",
	4: "Reinforced block. Very tough and survives fireballs (TNT still destroys it).",
	20: "Damage 2. Click to swing. Upgrade it with emeralds. You can only own one.",
	21: "Hold left click near an enemy to charge, release for a heavy chop (2 to 7 damage). Breaks blocks 2.5x faster.",
	22: "Restores 6 health and 6 hunger.",
	23: "Place it: 4 second fuse, then a huge blast. Breaks even unbreakable blocks, but never beds.",
	24: "Hold right click to draw, release to shoot. A dotted line shows where the arrow will land.",
	25: "Ammo for the bow.",
	26: "Right click to throw. 4 damage on a direct hit. On blocks it breaks nearby blocks and knocks back players close to the impact.",
	27: "Right click while falling to land in water and take no fall damage. Reusable (3s cooldown).",
	28: "30 seconds: bots only notice you when you are very close.",
	29: "45 seconds: you jump much higher.",
	30: "40 seconds: +1.5 melee damage.",
	31: "30 seconds: every hit poisons the enemy (0.5 damage per second for 6 seconds).",
}
const SWORD_BASE := 2.0
const SWORD_UPGRADE_COST := [3, 6, 12]   # emeralds for sword level 1, 2, 3 (+1 damage each)
const AXE_MIN := 2.0         # axe damage with no charge
const AXE_MAX := 7.0         # axe damage fully charged
const AXE_CHARGE_TIME := 1.0
const FIST_DAMAGE := 1.0
const AXE_SPEED := 2.5
const APPLE_HEAL := 6.0
const APPLE_FOOD := 6.0
const KILL_COINS := 3
const KNOCK := 7.0
const FALL_FREE := 3.0       # blocks you can fall without damage; then half a heart per extra block
const TNT_FUSE := 4.0
const INVIS_TIME := 30.0
const JUMP_TIME := 45.0
const STRENGTH_TIME := 40.0
const POISON_WEAPON_TIME := 30.0
const STRENGTH_BONUS := 1.5
const JUMP_SPEED := 12.5
const POISON_SECONDS := 6.0
const POISON_DAMAGE := 0.5

static func is_block(t: int) -> bool:
	return t >= 1 and t <= 4
