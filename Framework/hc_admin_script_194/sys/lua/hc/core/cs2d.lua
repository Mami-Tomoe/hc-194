-- Teams
-- player(p, "team"), spawnobject
hc.NEUTRAL = 0
hc.SPEC = 0
hc.T = 1
hc.CT = 2

-- Anonymous player name
hc.ANONYMOUS = "Player"

-- Number of menu items
hc.NUM_MENU_ITEMS = 9

-- Vote hook: mode
hc.KICK = 1
hc.MAP = 2

-- Number of player slots
hc.SLOTS = 32

-- Size of a tile in pixels
hc.TILE_SIZE = 32

-- Map max width and height
hc.MAP_MAX_WIDTH = 1000
hc.MAP_MAX_HEIGHT = 1000

-- Colours
hc.SPEC_YELLOW = "©255220000"
hc.T_RED = "©255025000"
hc.CT_BLUE = "©050150255"

hc.MAX_OBJECT_HEALTH = 100

-- Building types
hc.BARRICADE = 1
hc.BARBED_WIRE = 2
hc.WALL_I = 3
hc.WALL_II = 4
hc.WALL_III = 5
hc.GATE_FIELD = 6
hc.DISPENSER = 7
hc.TURRET = 8
hc.SUPPLY = 9
hc.CONSTRUCTION_SITE = 10
hc.DUAL_TURRET = 11
hc.TRIPLE_TURRET = 12
hc.TELEPORTER_ENTRANCE = 13
hc.TELEPORTER_EXIT = 14
hc.SUPER_SUPPLY = 15
hc.MINE = 20
hc.LASER_MINE = 21
hc.ORANGE_PORTAL = 22
hc.BLUE_PORTAL = 23
hc.IMAGE = 40

hc.BUILDING_NAMES = {
    [hc.BARRICADE] = "Barricade",
    [hc.BARBED_WIRE] = "Barbed Wire",
    [hc.WALL_I] = "Wall I",
    [hc.WALL_II] = "Wall II",
    [hc.WALL_III] = "Wall III",
    [hc.GATE_FIELD] = "Gate Field",
    [hc.DISPENSER] = "Dispenser",
    [hc.TURRET] = "Turret",
    [hc.SUPPLY] = "Supply",
    [hc.CONSTRUCTION_SITE] = "Construction Site",
    [hc.DUAL_TURRET] = "Dual Turret",
    [hc.TRIPLE_TURRET] = "Triple Turret",
    [hc.TELEPORTER_ENTRANCE] = "Teleporter Entrance",
    [hc.TELEPORTER_EXIT] = "Teleporter Exit",
    [hc.SUPER_SUPPLY] = "Super Supply",
    [hc.MINE] = "Mine",
    [hc.LASER_MINE] = "Laser Mine",
    [hc.ORANGE_PORTAL] = "Orange Portal",
    [hc.BLUE_PORTAL] = "Blue Portal",
    [hc.IMAGE] = "Image"
}

-- Item types
hc.USP = 1
hc.GLOCK = 2
hc.DEAGLE = 3
hc.P228 = 4
hc.ELITE = 5
hc.FIVE_SEVEN = 6
hc.M3 = 10
hc.XM1014 = 11
hc.MP5 = 20
hc.TMP = 21
hc.P90 = 22
hc.MAC_10 = 23
hc.UMP45 = 24
hc.AK_47 = 30
hc.SG552 = 31
hc.M4A1 = 32
hc.AUG = 33
hc.SCOUT = 34
hc.AWP = 35
hc.G3SG1 = 36
hc.SG550 = 37
hc.GALIL = 38
hc.FAMAS = 39
hc.M249 = 40
hc.TACTICAL_SHIELD = 41
hc.LASER = 45
hc.FLAMETHROWER = 46
hc.RPG_LAUNCHER = 47
hc.ROCKET_LAUNCHER = 48
hc.GRENADE_LAUNCHER = 49
hc.KNIFE = 50
hc.HE = 51
hc.FLASHBANG = 52
hc.SMOKE_GRENADE = 53
hc.FLARE = 54
hc.BOMB = 55
hc.DEFUSE_KIT = 56
hc.KEVLAR = 57
hc.KEVLAR_HELM = 58
hc.NIGHT_VISION = 59
hc.PRIMARY_AMMO = 61
hc.SECONDARY_AMMO = 62
hc.PLANTED_BOMB = 63
hc.MEDIKIT = 64
hc.BANDAGE = 65
hc.COINS = 66
hc.MONEY = 67
hc.GOLD = 68
hc.MACHETE = 69
hc.RED_FLAG = 70
hc.BLUE_FLAG = 71
hc.GAS_GRENADE = 72
hc.MOLOTOV_COCKTAIL = 73
hc.WRENCH = 74
hc.SNOWBALL = 75
hc.AIR_STRIKE = 76
hc.MINE = 77
hc.CLAW = 78
hc.LIGHT_ARMOR = 79
hc.ARMOR = 80
hc.HEAVY_ARMOR = 81
hc.MEDIC_ARMOR = 82
hc.SUPER_ARMOR = 83
hc.STEALTH_SUIT = 84
hc.CHAINSAW = 85
hc.GUT_BOMB = 86
hc.LASER_MINE = 87
hc.PORTAL_GUN = 88

-- Entity types
hc.INFO_T = 0
hc.INFO_CT = 1
hc.INFO_VIP = 2
hc.INFO_HOSTAGE = 3
hc.INFO_RESCUEPOINT = 4
hc.INFO_BOMBSPOT = 5
hc.INFO_ESCAPEPOINT = 6
hc.INFO_ANIMATION = 8
hc.INFO_STORM = 9
hc.INFO_TILEFX = 10
hc.INFO_NOBUYING = 11
hc.INFO_NOWEAPONS = 12
hc.INFO_QUAKE = 14
hc.INFO_CTF_FLAG = 15
hc.INFO_OLDRENDER = 16
hc.INFO_DOM_POINT = 17
hc.INFO_NOBUILDINGS = 18
hc.INFO_BOTNODE = 19
hc.INFO_TEAMGATE = 20
hc.ENV_ITEM = 21
hc.ENV_SPRITE = 22
hc.ENV_SOUND = 23
hc.ENV_DECAL = 24
hc.ENV_BREAKABLE = 25
hc.ENV_EXPLODE = 26
hc.ENV_HURT = 27
hc.ENV_IMAGE = 28
hc.ENV_OBJECT = 29
hc.ENV_BUILDING = 30
hc.GEN_PARTICLES = 50
hc.GEN_SPRITES = 51
hc.GEN_WEATHER = 52
hc.GEN_FX = 53
hc.FUNC_TELEPORT = 70
hc.FUNC_DYNWALL = 71
hc.FUNC_MESSAGE = 72
hc.FUNC_GAMEACTION = 73
hc.TRIGGER_START = 90
hc.TRIGGER_MOVE = 91
hc.TRIGGER_HIT = 92
hc.TRIGGER_USE = 93
hc.TRIGGER_DELAY = 94
hc.TRIGGER_ONCE = 95

-- Game modes (sv_gamemode)
hc.NORMAL = 0
hc.DEATHMATCH = 1
hc.TEAM_DEATHMATCH = 2
hc.CONSTRUCTION = 3
hc.ZOMBIES = 4

-- Server action keys
hc.SERVERACTION1 = 1
hc.SERVERACTION2 = 2
hc.SERVERACTION3 = 3

hc.DEFAULT_KEYS = {
    [hc.SERVERACTION1] = "F2",
    [hc.SERVERACTION2] = "F3",
    [hc.SERVERACTION3] = "F4"
}
