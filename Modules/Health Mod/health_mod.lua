------------------------------------------------------------------------------
-- Module config
------------------------------------------------------------------------------

-- Maximum number of digits to render. Example: 3 digits = 999 HP. 3 digits looks best on all resolutions.
local MAX_DIGITS = 3

-- By default when you set a player's max health, their current health
-- gets set to the max health as well. This is the default CS2D behaviour.
-- You may change that here.
local SET_MAX_HEALTH_SHOULD_SET_CURRENT_HEALTH_TOO = true

--- The default HUD colours built into CS2D.
--- The colours can be changed via the options menu, but
--- those are local to the player. Additionally, the server
--- can't check which colour configurations the player chose
--- so we can't follow what the player chose, therefore we
--- stick to the defaults and hope the players didn't change
--- their colour settings.
local HUD_COLOUR = {
	default = { 150, 150, 0 }, -- Yellow when HP > 30HP.
	critical = { 255, 0, 0 } -- Red when HP <= 30 HP.
}

--- Same as the above, but in string format.
--- I could've used a special function to convert
--- the tables into strings, but that seems like overkill
--- considering that the colours aren't supposed to be changed.
local HUD_COLOUR_STRING = {
	default = '\169150150000', -- Same as HUD_COLOUR but as a string.
	critical = '\169255000000' -- Same as HUD_COLOUR but as a string.
}

--- The mouse hover HUD text configuration.
--- It is primarily hard coded because it runs on the frame
--- hook and needs to be as efficient as possible.
local HOVER_HUDTXT = {
	id = 198 -- 0-199
}

--- Configuration for the spectator HUD text that shows up
--- when a player is spectating another player.
--- The HUD text is necessary because you can't hide/change
--- the health value visible to spectators.
local SPEC_HUDTXT = {
	id = 199,             -- 0-199
	colour = hc.SPEC_YELLOW, -- Refer to hc/core/constants.lua
	x = 850 / 2,
	y = 480 - 40
}

-- Space between health HUD numbers.
local HUD_MARGIN_X = 27

-- Where to start drawing the HUD numbers on the X axis.
local HUD_START_X = 41 + (HUD_MARGIN_X * MAX_DIGITS)

-- Scale for the health number HUD.
local HUD_NUM_SCALE = { 0.45, 0.45 }

-- Scale for the health symbol HUD.
local HUD_SYM_SCALE = { 0.42, 0.42 }

-- Maximum health allowed (based on the number of digits).
-- You're not supposed to change this.
local MAX_HEALTH_ALLOWED = tonumber(('9'):rep(MAX_DIGITS)) or 1

-- Player core size.
local PLAYER_CORE = 20

-- Dispenser pixel range to players.
local DISPENSER_RANGE = PLAYER_CORE + 16

-- Zombie spray health recovery.
-- I think this is hard-coded into CS2D.
local ZOMBIE_SPRAY_RECOVER = 20

-- Medic armour (armour: 204, item: 82) heal per second (when worn).
local MEDIC_ARMOUR_HEAL_PER_SEC = 10

-- Default CS2D health values for players.
local CS2D_HEALTH_PRESET = {
	default = 100,
	critical = 30,
	minimum = 0,
	maximum = 250
}

------------------------------------------------------------------------------
-- Module API
------------------------------------------------------------------------------

local parse_lock = true
local kill_info
local current_game_mode

local cs2d_player = player

local math_atan2 = math.atan2
local math_cos = math.cos
local math_sin = math.sin
local math_sqrt = math.sqrt
local math_floor = math.floor

--- There is one limitation about this mod:
--- You cannot be "one-shot" if your custom health is set to anything higher than 250.
---
--- The technical explanation is that CS2D only sends the damage taken in the hit hook and not the incoming damage.
---
--- This means if a player has 250 HP (CS2D max), and you shoot at them with a weapon like a laser, that usually deals 1000 damage, the hit hook will only display the raw damage as 250, because the player can't take any more than that.
---
--- When calculating the damage to deduct from the custom health mod system, we deduct the 250 because we don't know the player took so much more (again, the hit hook doesn't pass that value).
---
--- This means players cannot take more than 250 HP at a time in this mod.
---
--- The workaround would be to have a more robust system for calculating damage (taking weapon damage, player armour and other variables into account to calculate the incoming damage).
--- But that is simply too much work. It would be a whole lot easier to just hard-code some weapons to kill on hit or extend this module with the same principle in mind.
function hc.health_mod.init()
	-- Hide the health HUD (127 - 1).
	parse(('mp_hud %d'):format(126))

	-- Hide the health hover (31 - 2).
	parse(('mp_hovertext %d'):format(29))

	-- Hide the kill info (if enabled),
	-- and replace it with a custom one.
	kill_info = tonumber(game('mp_killinfo'))

	parse(('mp_killinfo '):format(0))

	-- Hooks.
	addhook('init', 'hc.health_mod.init_hook')
	addhook('init_player', 'hc.health_mod.init_player_hook', -999999)
	addhook('delete_player', 'hc.health_mod.delete_player_hook', -999999)
	addhook('spawn', 'hc.health_mod.spawn_hook', -999999)
	addhook('die', 'hc.health_mod.die_hook', -999999)
	addhook('hit', 'hc.health_mod.hit_hook', -999999)
	addhook('parse', 'hc.health_mod.parse_hook', -999999)
	addhook('post_endround', 'hc.health_mod.post_endround_hook', -999999)
	addhook('startround', 'hc.health_mod.startround_hook', -999999)
	addhook('specswitch', 'hc.health_mod.specswitch_hook', -999999)
	addhook('frame', 'hc.health_mod.frame_hook')
	addhook('second', 'hc.health_mod.second_hook')
	addhook('spray', 'hc.health_mod.spray_hook')
end

------------------------------------------------------------------------------
-- Internal functions
------------------------------------------------------------------------------

---Returns a weapon's name and its image path in a CSV format.
---@param wpnTypeId number weapon type number identifier
---@param objId number object number identifier
---@return string|'': string with weapon name separated by comma and followed by the image path or object name or empty string
local function get_weapon_name_and_image_path(wpnTypeId, objId)
	local wpnName = itemtype(wpnTypeId, 'name')

	-- Died to a weapon.
	if wpnName then
		return ('%s,gfx/weapons/%s_k.bmp'):format(wpnName, wpnName)
	end

	-- Died to an object.
	if objId > 0 then
		return object(objId, 'typename')
	end

	return ''
end

---Attempts to read a CS2D command from the input text.
---@param text string command text
---@return { command: string|'', args:table<string> }: table with "command" string and "args" table
local function read_command(text)
	text = text or ''

	local words = {}
	local i = 1
	local len = #text

	while i <= len do
		local rest = text:sub(i)

		-- skip leading spaces
		local sSpace, eSpace = rest:find('^%s+')

		if sSpace then
			i = i + eSpace

			rest = text:sub(i)
		end

		if rest == "" then break end

		-- double-quoted token
		local sd, ed, capd = rest:find('^"([^"]*)"')

		if sd then
			table.insert(words, capd)

			i = i + ed
		else
			-- single-quoted token
			local ss, es, caps = rest:find("^'([^']*)'")

			if ss then
				table.insert(words, caps)

				i = i + es
			else
				-- unquoted token (sequence of non-space chars)
				local su, eu = rest:find('^([^%s]+)')

				if su then
					table.insert(words, rest:sub(su, eu))

					i = i + eu
				else
					break
				end
			end
		end
	end

	local command = table.remove(words, 1)

	return { command = command or '', args = words }
end

---Returns a colour based on given health.
---@param health number
---@param asString boolean
---@return table|string
local function get_colour_based_on_health(health, asString)
	if health <= CS2D_HEALTH_PRESET.critical then
		return (asString and HUD_COLOUR_STRING.critical) or HUD_COLOUR.critical
	end

	return (asString and HUD_COLOUR_STRING.default) or HUD_COLOUR.default
end

---Clamps the health amount given to the maximum health allowed.
---@param amount number health amount
---@return number: clamped amount
local function clamp_max_allowed(amount)
	return math.min(MAX_HEALTH_ALLOWED, amount)
end

---Removes the health symbol HUD to a player.
---@param p number player number identifier
local function free_health_symbol(p)
	if hc.players[p].health_mod.images.symbol then
		freeimage(hc.players[p].health_mod.images.symbol)

		hc.players[p].health_mod.images.symbol = nil
	end
end

---Draws the health symbol HUD to a player.
---@param p number player number identifier
---@param amount number health amount
local function draw_health_symbol(p, amount)
	free_health_symbol(p)

	if amount <= CS2D_HEALTH_PRESET.minimum then
		return
	end

	local spritesheetPath = '<spritesheet:gfx/hud_symbols.bmp:64:64:b>'
	local symbolImg = image(spritesheetPath, 14, 459, 2, p)

	---@diagnostic disable-next-line: param-type-mismatch
	imagecolor(symbolImg, unpack(get_colour_based_on_health(amount, false)))
	imagescale(symbolImg, unpack(HUD_SYM_SCALE))
	imageframe(symbolImg, 1)
	imageblend(symbolImg, 1)

	hc.players[p].health_mod.images.symbol = symbolImg
end

---Removes the health numbers HUD to a player.
---@param p number player number identifier
local function free_health_images(p)
	local images = hc.players[p].health_mod.images.numbers

	for _, imageId in pairs(images) do
		freeimage(imageId)
	end

	hc.players[p].health_mod.images.numbers = {}
end

---Draws the health numbers HUD to a player.
---@param p number player number identifier
---@param amount number health amount
local function draw_health_images(p, amount)
	free_health_images(p)

	if amount <= CS2D_HEALTH_PRESET.minimum then
		return
	end

	local spritesheetPath = '<spritesheet:gfx/hud_nums.bmp:48:66:a>'
	local images = hc.players[p].health_mod.images.numbers

	for i = 1, MAX_DIGITS do
		local digit = tostring(amount):sub(-i, -i)
		local digitNum = tonumber(digit)

		if digitNum then
			local digitImg = image(spritesheetPath, HUD_START_X - (i * HUD_MARGIN_X), 460, 2, p)

			---@diagnostic disable-next-line: param-type-mismatch
			imagecolor(digitImg, unpack(get_colour_based_on_health(amount, false)))
			imagescale(digitImg, unpack(HUD_NUM_SCALE))
			imageframe(digitImg, digitNum + 1)
			imageblend(digitImg, 1)

			images[i] = digitImg
		end
	end
end

---Returns the amount of health the player has.
---@param p number player number identifier
---@return number: player current health value
local function get_health(p)
	return hc.players[p].health_mod.health
end

---Returns the maximum amount of health the player can have.
---@param p number player number identifier
---@return number: player max health value
local function get_max_health(p)
	return hc.players[p].health_mod.max_health
end

---Updates the spectating HUD text for a spectator.
---@param p number player number identifier
local function update_spec_hudtxt(p)
	local target = hc.players[p].health_mod.spectating
	local text

	if target then
		local targetHealth = get_health(target)

		text = ('%sHealth: %s%d%s/%s%d'):format(
			SPEC_HUDTXT.colour,
			get_colour_based_on_health(targetHealth, true), targetHealth,
			SPEC_HUDTXT.colour,
			HUD_COLOUR_STRING.default, get_max_health(target))
	else
		text = ''
	end

	parse(('hudtxt2 "%d" "%d" "%s" "%d" "%d" "%d" "%d" "%d"'):format(
		p, SPEC_HUDTXT.id, text, SPEC_HUDTXT.x, SPEC_HUDTXT.y, 1, 1, 11))
end

---Frees the spectating HUD text for a spectator.
---@param p number player number identifier
local function free_spec(p)
	local oldTarget = hc.players[p].health_mod.spectating

	if oldTarget then
		-- Remove old spectating.
		local oldTargetSpecs = hc.players[oldTarget].health_mod.spectators
		local index = hc.find_in_table(oldTargetSpecs, p)

		if index ~= 0 then
			table.remove(oldTargetSpecs, index)
		end

		hc.players[p].health_mod.spectating = nil
	end

	update_spec_hudtxt(p)
end

---Sets someone as spectating someone else.
---@param p number player number identifier (spectator)
---@param target number target number identifier (spectated)
local function set_spec(p, target)
	free_spec(p)

	if target > 0 then
		hc.players[p].health_mod.spectating = target

		table.insert(hc.players[target].health_mod.spectators, p)
	end

	update_spec_hudtxt(p)
end

---Updates all spectators of this player.
---@param p number player number identifier (spectated)
local function update_spectators(p)
	local specs = hc.players[p].health_mod.spectators

	for i = 1, #specs do
		local specId = specs[i]

		update_spec_hudtxt(specId)
	end
end

---Sets a player's health.
---@param p number player number identifier
---@param health? number health amount
local function set_health(p, health)
	health = health or (CS2D_HEALTH_PRESET.minimum + 1)

	if not hc.player_exists(p) then
		return error(('Player "%s" does not exist.'):format(tostring(p)))
	end

	-- Clamp to max health.
	health = math.min(health, get_max_health(p))

	-- Clamp to max allowed.
	health = clamp_max_allowed(health)

	hc.players[p].health_mod.health = health

	-- Draw images.
	draw_health_images(p, health)
	draw_health_symbol(p, health)

	-- Update spectators.
	update_spectators(p)
end

---Sets a player's max health.
---@param p number player number identifier
---@param maxHealth? number max health amount
local function set_max_health(p, maxHealth)
	maxHealth = maxHealth or (CS2D_HEALTH_PRESET.minimum + 1)

	if not hc.player_exists(p) then
		return error(('Player "%s" does not exist.'):format(tostring(p)))
	end

	-- Clamp to max allowed.
	maxHealth = clamp_max_allowed(maxHealth)

	hc.players[p].health_mod.max_health = maxHealth

	-- Draw images.
	draw_health_images(p, maxHealth)
	draw_health_symbol(p, maxHealth)

	-- Update spectators.
	update_spectators(p)
end

---Shows kill info to a victim of their killer.
---Will not draw the background image (as that is not currently possible).
---@param victim number player number identifier
---@param killer number player number identifier
local function show_kill_info(victim, killer)
	if not kill_info then
		return
	end

	local armourText
	local killerAp = player(killer, 'armor')

	if killerAp > 0 and killerAp <= 200 then
		armourText = (' %s& %s%d Armor'):format(hc.SPEC_YELLOW, hc.LIME, killerAp)
	else
		armourText = ''
	end

	hc.event(victim, {
		('%sKilled by %s'):format(
			hc.RED, player(killer, 'name')),
		('%sEnemy has %s%d HP%s%s left'):format(
			hc.SPEC_YELLOW, hc.LIME, get_health(killer), armourText, hc.SPEC_YELLOW)
	})
end

---Checks if the given coordinate is within a rectangle.
---@param x number horizontal axis coordinate
---@param y number vertical axis coordinate
---@param x1 number top-left horizontal rectangle coordinate
---@param y1 number top-left vertical rectangle coordinate
---@param x2 number bottom-right horizontal rectangle coordinate
---@param y2 number bottom-right vertical rectangle coordinate
---@return boolean: `true` if inside or `false` if not
local function is_inside_rect(x, y, x1, y1, x2, y2)
	return x >= x1 and x <= x2 and y >= y1 and y <= y2
end

---Checks if two points (source and impact) have an obstacle between them.
---@param sourceX number source horizontal axis coordinate
---@param sourceY number source vertical axis coordinate
---@param impactX number impact horizontal axis coordinate
---@param impactY number impact vertical axis coordinate
---@param includesObstacles boolean `true` to consider obstacles as walls or `false` to only consider walls
---@return table<number, number>|false: if blocked a table with the coordinates to the object that blocked the ray, otherwise returns `false`
local function raycast_wall(sourceX, sourceY, impactX, impactY, includesObstacles)
	local function is_tile_wall(tx, ty)
		local tile_get = tile

		if tile_get(tx, ty, 'wall') then
			return true
		end

		if includesObstacles and tile_get(tx, ty, 'obstacle') then
			return true
		end

		return false
	end

	local rot      = math_atan2(impactY - sourceY, impactX - sourceX)
	local cosRot   = math_cos(rot)
	local sinRot   = math_sin(rot)

	impactX        = impactX - cosRot
	impactY        = impactY - sinRot

	-- Localising.
	local tileSize = hc.TILE_SIZE

	-- Distance.
	local xd       = sourceX - impactX
	local yd       = sourceY - impactY
	local dist     = math_sqrt(xd * xd + yd * yd)

	for _ = 0, dist, 1 do
		impactX = impactX - cosRot
		impactY = impactY - sinRot

		local tx, ty = math_floor(impactX / tileSize), math_floor(impactY / tileSize)

		if is_tile_wall(tx, ty) then
			return { tx, ty }
		end
	end

	return false
end

---Checks if a player can be seen by another player.
---@param lookerId number player number identifier (the one looking)
---@param lookedId number player number identifier (the one being looked at)
---@return boolean: `true` if "looked" should be visible to "looker", otherwise `false`
local function can_be_seen(lookerId, lookedId)
	-- Game mode check.
	if current_game_mode == hc.DEATHMATCH then
		return false
	end

	-- Same team check.
	if player(lookerId, 'team') ~= player(lookedId, 'team') then
		return false
	end

	-- Raycast check.
	if tonumber(game('sv_fow')) > 0 then
		local lookerX, lookerY = player(lookerId, 'x'), player(lookerId, 'y')
		local lookedX, lookedY = player(lookedId, 'x'), player(lookedId, 'y')

		if raycast_wall(lookerX, lookerY, lookedX, lookedY, false) then
			return false
		end
	end

	return true
end

------------------------------------------------------------------------------
-- Public functions
------------------------------------------------------------------------------

---For internal use only.
---Dictates whether the parse hook in this file should be active or not.
---@param state boolean when `true` the parse hook is active, and when `false` the parse hook is inactive.
function hc.health_mod.set_parse_lock(state)
	parse_lock = state
end

------------------------------------------------------------------------------
-- Overrides
------------------------------------------------------------------------------

---Override for the player function to return health/max health values from this script
---as opposed to what CS2D thinks they should be.
---@param p any
---@param value any
---@return number
player = function(p, value)
	if value == 'health' then
		return get_health(p)
	elseif value == 'maxhealth' then
		return get_max_health(p)
	end

	return cs2d_player(p, value)
end

------------------------------------------------------------------------------
-- Hooks
------------------------------------------------------------------------------

function hc.health_mod.init_hook()
	current_game_mode = tonumber(game('sv_gamemode'))
end

function hc.health_mod.init_player_hook(p, reason)
	if reason == hc.SCRIPT_INIT then
		return
	end

	hc.players[p].health_mod = {
		health = CS2D_HEALTH_PRESET.minimum,
		max_health = CS2D_HEALTH_PRESET.default,
		images = {
			symbol = nil,
			numbers = {}
		},
		spectating = nil,
		spectators = {}
	}
end

function hc.health_mod.delete_player_hook(p, reason)
	free_spec(p)
end

function hc.health_mod.spawn_hook(p)
	-- This makes it so core health is set to 250 (max)
	-- to allow maximum incoming damage per hit.
	parse_lock = false

	parse(('setmaxhealth "%d" "%d"'):format(p, 250))

	timer(0, 'parse', ('lua hc.health_mod.set_parse_lock(%s)'):format('true'))

	-- This initialises the player.
	set_health(p, CS2D_HEALTH_PRESET.default)
	set_spec(p, 0)
end

function hc.health_mod.die_hook(victim, killer, wpnTypeId, x, y, objId)
	set_health(victim, CS2D_HEALTH_PRESET.minimum)
	set_spec(victim, player(victim, 'spectating'))

	if killer > 0 then
		show_kill_info(victim, killer)
	end
end

function hc.health_mod.hit_hook(victim, source, wpnTypeId, hpDmg, apDmg, rawDmg, objId)
	if hpDmg <= CS2D_HEALTH_PRESET.minimum then
		return 1
	end

	local newHealth = get_health(victim) - hpDmg
	local x, y = player(victim, 'x'), player(victim, 'y')

	if newHealth <= CS2D_HEALTH_PRESET.minimum then
		local weaponNameAndImagePath = get_weapon_name_and_image_path(wpnTypeId, objId)

		-- set_health is called on the die_hook, so no need to call it here.
		parse(('customkill "%d" "%s" "%d"'):format(source, weaponNameAndImagePath, victim))

		-- Play die sound.
		parse(('sv_soundpos "%s" "%d" "%d"'):format(('player/die%d.wav'):format(math.random(3)), x, y))
	else
		set_health(victim, newHealth)

		-- Play hit sound.
		parse(('sv_soundpos "%s" "%d" "%d"'):format(('player/hit%d.wav'):format(math.random(3)), x, y))
	end

	-- Calculate armour damage for kevlar armour.
	if apDmg > 0 then
		local newAp = player(victim, 'armor') - apDmg

		parse(('setarmor %d %d'):format(victim, newAp))
	end

	return 1
end

function hc.health_mod.parse_hook(text)
	if parse_lock == false then
		return
	end

	local command = read_command(text)

	if command.command == 'sethealth' then
		local id, health = unpack(command.args)

		id, health = tonumber(id), tonumber(health)

		if not id then
			return error(('Player ID "%s" is not valid.'):format(tostring(id)))
		end

		set_health(id, health)

		return 2
	elseif command.command == 'setmaxhealth' then
		local id, maxHealth = unpack(command.args)

		id, maxHealth = tonumber(id), tonumber(maxHealth)

		if not id then
			return error(('Player ID "%s" is not valid.'):format(tostring(id)))
		end

		set_max_health(id, maxHealth)
		-- In CS2D the default behaviour when setting max health
		-- is to also set the current health.
		if SET_MAX_HEALTH_SHOULD_SET_CURRENT_HEALTH_TOO then
			set_health(id, maxHealth)
		end

		return 2
	elseif command.command == 'mp_hud' or command.command == 'mp_hovertext' then
		error(('Changing "%s" when using the Health Mod module is not supported.'):format(command.command))

		return 2
	elseif command.command == 'mp_killinfo' then
		local info = command.args[1]

		kill_info = info

		return 2
	end
end

function hc.health_mod.post_endround_hook()
	for id = 1, hc.SLOTS do
		if hc.player_exists(id) then
			free_health_images(id)
			free_health_symbol(id)
		end
	end
end

function hc.health_mod.startround_hook(mode)
	current_game_mode = tonumber(game('sv_gamemode'))

	for id = 1, hc.SLOTS do
		if hc.player_exists(id) and player(id, 'health') > 0 then
			local health = get_health(id)

			draw_health_images(id, health)
			draw_health_symbol(id, health)
		end
	end
end

function hc.health_mod.specswitch_hook(p, target)
	if tonumber(game('sv_specmode')) == 2 then
		return
	end

	set_spec(p, target)
end

function hc.health_mod.frame_hook(delta)
	local players = player(0, 'tableliving')

	for i = 1, #players do
		local lookerId = players[i]

		local mmx, mmy = player(lookerId, 'mousemapx'), player(lookerId, 'mousemapy')

		for j = 1, #players do
			local lookedId = players[j]

			if lookerId ~= lookedId then
				local lookedX, lookedY = player(lookedId, 'x'), player(lookedId, 'y')

				if is_inside_rect(mmx, mmy, lookedX - PLAYER_CORE, lookedY - PLAYER_CORE, lookedX + PLAYER_CORE, lookedY + PLAYER_CORE) then
					if can_be_seen(lookerId, lookedId) then
						local mx, my = player(lookerId, 'mousex'), player(lookerId, 'mousey') + 24
						local text = ('%s%d%%'):format(hc.LIME, get_health(lookedId))

						parse(('hudtxt2 "%d" "%d" "%s" "%d" "%d" "%d" "%d" "%d"'):format(
							lookerId, HOVER_HUDTXT.id, text, mx, my, 1, 1, 7))

						return -- No more code to execute.
					end
				end
			end
		end

		parse(('hudtxt2 "%d" "%d" "%s"'):format(lookerId, HOVER_HUDTXT.id, ''))
	end
end

function hc.health_mod.second_hook()
	local players = player(0, 'tableliving')

	local isZombies = current_game_mode == hc.ZOMBIES
	local zombieHeal = tonumber(game('mp_zombierecover'))

	local dispenserHeal = tonumber(game('mp_dispenser_health'))

	for i = 1, #players do
		local id = players[i]
		local curHealth = get_health(id)
		local toHeal = 0

		if curHealth < get_max_health(id) then
			-- Heal 10 HP/s for medic armour wearers.
			if player(id, 'armor') == 204 then
				toHeal = toHeal + MEDIC_ARMOUR_HEAL_PER_SEC
			end

			local playerTeam = player(id, 'team')

			-- Heal zombies.
			if isZombies and playerTeam == hc.T then
				toHeal = toHeal + zombieHeal
			end

			-- Heal from dispenser.
			if dispenserHeal > 0 then
				local x, y = player(id, 'x'), player(id, 'y')
				local nearbyDispensers = closeobjects(x, y, DISPENSER_RANGE, hc.BUILDINGS.DISPENSER)
				local nearbyDispensersC = #nearbyDispensers

				if nearbyDispensersC > 0 then
					for j = 1, nearbyDispensersC do
						local dispenser = nearbyDispensers[j]

						if object(dispenser, 'team') == playerTeam then
							toHeal = toHeal + dispenserHeal

							-- We don't break here because more dispensers = more heal.
						end
					end
				end
			end

			-- Heal from entities.
			local entities = entitylist(hc.ENV_HURT)
			local tx, ty = player(id, 'tilex'), player(id, 'tiley')

			for _, e in pairs(entities) do
				local entityTx, entityTy = e.x, e.y
				local entityWidth, entityHeight = entity(entityTx, entityTy, 'int2'), entity(entityTx, entityTy, 'int3')

				if is_inside_rect(tx, ty, entityTx, entityTy, entityTx + entityWidth, entityTy + entityHeight) then
					local amount = -entity(entityTx, entityTy, 'int0') -- Negative health is heal in a hurt entity.

					-- Only care if the amount is more than 0.
					-- Hurt is processed individually by the game calling the hit hook.
					if amount > 0 then
						toHeal = toHeal - entity(entityTx, entityTy, 'int0')
					end
				end
			end

			if toHeal > 0 then
				set_health(id, curHealth + toHeal)
			end
		end
	end
end

function hc.health_mod.spray_hook(p)
	if current_game_mode ~= hc.ZOMBIES then
		return
	elseif player(p, 'team') ~= hc.T then
		return
	end

	local curHealth = get_health(p)

	if curHealth < get_max_health(p) then
		set_health(p, curHealth + ZOMBIE_SPRAY_RECOVER)
	end
end
