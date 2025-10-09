------------------------------------------------------------------------------
-- Module API
------------------------------------------------------------------------------

local cs2d_player = player

local HUD_COLOUR = {
	default = { 150, 150, 0 }, -- Yellow by default.
	critical = { 255, 0, 0 } -- Red when below 30 HP.
}

local HUD_COLOUR_STRING = {
	default = '\169150150000', -- Same as HUD_COLOUR but as a string.
	critical = '\169255000000' -- Same as HUD_COLOUR but as a string.
}

local SPEC_HUDTXT = {
	id = 199,             -- 0-199
	colour = hc.SPEC_YELLOW, -- Refer to hc/core/constants.lua
	x = 850 / 2,          -- Do not touch.
	y = 480 - 40          -- Do not touch.
}

local HOVER_HUDTXT = {
	id = 198 -- 0-199
}

local MAX_DIGITS = 3                                            -- 3 = 999 HP MAX
local HUD_MARGIN_X = 27                                         -- Do not touch.
local HUD_START_X = 41 + (HUD_MARGIN_X * MAX_DIGITS)            -- Do not touch.

local HUD_NUM_SCALE = { 0.45, 0.45 }                            -- Do not touch.
local HUD_SYM_SCALE = { 0.42, 0.42 }                            -- Do not touch.

local MAX_HEALTH_ALLOWED = tonumber(('9'):rep(MAX_DIGITS)) or 1 -- Do not touch.

local parse_lock = true                                         -- Do not touch especially.
local kill_info                                                 -- Do not touch.

local PLAYER_CORE = 20                                          -- Do not touch.
local ZOMBIE_SPRAY_RECOVER = 20                                 -- Do not touch.
local DISPENSER_RANGE = 36                                      -- Do not touch.

local math_atan2 = math.atan2                                   -- Do not touch.
local math_cos = math.cos                                       -- Do not touch.
local math_sin = math.sin                                       -- Do not touch.
local math_sqrt = math.sqrt                                     -- Do not touch.
local math_floor = math.floor                                   -- Do not touch.

---There is one limitation about this mod:
---You cannot be "one-shot" if your custom health is set to anything higher than 250.
---
---The technical explanation is that CS2D only sends the damage taken in the
---hit hook and not the incoming damage.
---
---This means if a player has 250 HP (CS2D max), and you shoot at them with a weapon
---like a laser, that usually deals 1000 damage, the hit hook will only display the rawDmg
---as 250, because the player can't take any more than that.
---
---When calculating the damage to deduct from the custom health mod system, we deduct the 250
---because we don't know the player took so much more (again, the hit hook doesn't pass that value).
---
---This means players cannot take more than 250 HP at a time in this mod.
---
---The workaround would be to have a more robust system for calculating damage (taking weapon damage,
---player armour and other variables into account to calculate the incoming damage).
---But that is simply too much work. It would be a whole lot easier to just hard-code some weapons to
---kill on hit or extend this module with the same principle in mind.
function hc.health_mod.init()
	-- Hide the health HUD (127 - 1).
	parse(('mp_hud %d'):format(126))

	-- Hide the health hover (31 - 2).
	parse(('mp_hovertext %d'):format(29))

	-- Hide the kill info (if enabled),
	-- and replace it with a custom one.
	kill_info = game('mp_killinfo')

	parse(('mp_killinfo '):format(0))

	-- Hooks.
	addhook('init_player', 'hc.health_mod.init_player_hook', -999999)
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

local function print_error(message)
	print(('%sError: %s'):format(hc.RED, message))
end

local function get_weapon_name_and_image_path(wpnTypeId, objId)
	local wpnName = itemtype(wpnTypeId, 'name')

	-- Died to weapon.
	if wpnName then
		return ('%s,gfx/weapons/%s_k.bmp'):format(wpnName, wpnName)
	end

	-- Died to object.
	if objId > 0 then
		return object(objId, 'typename')
	end

	return ''
end

local function read_command(text)
	text = text or ''

	local words = {}
	local i = 1
	local len = #text

	while i <= len do
		local rest = text:sub(i)

		-- skip leading spaces
		local s_space, e_space = rest:find('^%s+')
		if s_space then
			i = i + e_space
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
---@param as_string boolean
---@return table|string
local function get_colour_based_on_health(health, as_string)
	if health <= 30 then
		return (as_string and HUD_COLOUR_STRING.critical) or HUD_COLOUR.critical
	end

	return (as_string and HUD_COLOUR_STRING.default) or HUD_COLOUR.default
end

local function clamp_max_allowed(amount)
	return math.min(MAX_HEALTH_ALLOWED, amount)
end

local function free_health_symbol(p)
	if hc.players[p].health_mod.images.symbol then
		freeimage(hc.players[p].health_mod.images.symbol)

		hc.players[p].health_mod.images.symbol = nil
	end
end

local function draw_health_symbol(p, amount)
	free_health_symbol(p)

	if amount <= 0 then
		return
	end

	local spritesheetPath = '<spritesheet:gfx/hud_symbols.bmp:64:64:b>'
	local symbolImg = image(spritesheetPath, 14, 459, 2, p)

	---@diagnostic disable-next-line: param-type-mismatch
	imagecolor(symbolImg, unpack(get_colour_based_on_health(amount, false)))
	imagescale(symbolImg, unpack(HUD_SYM_SCALE))
	imageframe(symbolImg, 1)

	hc.players[p].health_mod.images.symbol = symbolImg
end

local function free_health_images(p)
	local images = hc.players[p].health_mod.images.numbers

	for _, imageId in pairs(images) do
		freeimage(imageId)
	end

	hc.players[p].health_mod.images.numbers = {}
end

local function draw_health_images(p, amount)
	free_health_images(p)

	if amount <= 0 then
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

			images[i] = digitImg
		end
	end
end

local function get_health(p)
	return hc.players[p].health_mod.health
end

local function get_max_health(p)
	return hc.players[p].health_mod.max_health
end

local function update_spec_hudtxt(p)
	local target = hc.players[p].health_mod.spectating
	local text

	if target then
		local target_health = get_health(target)

		text = ('%sHealth: %s%d%s/%s%d'):format(
			SPEC_HUDTXT.colour,
			get_colour_based_on_health(target_health, true), target_health,
			SPEC_HUDTXT.colour,
			HUD_COLOUR_STRING.default, get_max_health(target))
	else
		text = ''
	end

	parse(('hudtxt2 "%d" "%d" "%s" "%d" "%d" "%d" "%d" "%d"'):format(
		p, SPEC_HUDTXT.id, text, SPEC_HUDTXT.x, SPEC_HUDTXT.y, 1, 1, 11))
end

local function free_spec(p)
	local old_target = hc.players[p].health_mod.spectating

	if old_target then
		-- Remove old spectating.
		local old_target_specs = hc.players[old_target].health_mod.spectators
		local index = hc.find_in_table(old_target_specs, p)

		if index ~= 0 then
			table.remove(old_target_specs, index)
		end

		hc.players[p].health_mod.spectating = nil
	end

	update_spec_hudtxt(p)
end

local function set_spec(p, target)
	free_spec(p)

	if target > 0 then
		hc.players[p].health_mod.spectating = target

		table.insert(hc.players[target].health_mod.spectators, p)
	end

	update_spec_hudtxt(p)
end

local function update_spectators(p)
	local specs = hc.players[p].health_mod.spectators

	for i = 1, #specs do
		local spectator = specs[i]

		update_spec_hudtxt(spectator)
	end
end

local function set_health(p, health)
	health = health or 1

	if not hc.player_exists(p) then
		return print_error(('Player "%s" does not exist.'):format(p))
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

local function set_max_health(p, max_health)
	max_health = max_health or 1

	if not hc.player_exists(p) then
		return print_error(('Player "%s" does not exist.'):format(p))
	end

	-- Clamp to max allowed.
	max_health = clamp_max_allowed(max_health)

	hc.players[p].health_mod.max_health = max_health

	-- Draw images.
	draw_health_images(p, max_health)
	draw_health_symbol(p, max_health)

	-- Update spectators.
	update_spectators(p)
end

local function show_kill_info(victim, killer)
	if not kill_info then
		return
	end

	local armour_line
	local killer_armour = player(killer, 'armor')

	if killer_armour > 0 and killer_armour <= 200 then
		armour_line = (' %s& %s%d Armor'):format(hc.SPEC_YELLOW, hc.LIME, killer_armour)
	else
		armour_line = ''
	end

	hc.event(victim, {
		('%sKilled by %s'):format(
			hc.RED, player(killer, 'name')),
		('%sEnemy has %s%d HP%s%s left'):format(
			hc.SPEC_YELLOW, hc.LIME, get_health(killer), armour_line, hc.SPEC_YELLOW)
	})
end

local function is_inside_rect(x, y, x1, y1, x2, y2)
	return x >= x1 and x <= x2 and y >= y1 and y <= y2
end

local function raycast_wall(source_x, source_y, impact_x, impact_y, includes_obstacles)
	local function is_tile_wall(tx, ty)
		local tile_get = tile

		if tile_get(tx, ty, 'wall') then
			return true
		end

		if includes_obstacles and tile_get(tx, ty, 'obstacle') then
			return true
		end

		return false
	end

	local rot       = math_atan2(impact_y - source_y, impact_x - source_x)
	local cos_rot   = math_cos(rot)
	local sin_rot   = math_sin(rot)

	impact_x        = impact_x - cos_rot
	impact_y        = impact_y - sin_rot

	-- Localising.
	local tile_size = hc.TILE_SIZE

	-- Distance.
	local xd        = source_x - impact_x
	local yd        = source_y - impact_y
	local dist      = math_sqrt(xd * xd + yd * yd)

	for _ = 0, dist, 1 do
		impact_x = impact_x - cos_rot
		impact_y = impact_y - sin_rot

		local tx, ty = math_floor(impact_x / tile_size), math_floor(impact_y / tile_size)

		if is_tile_wall(tx, ty) then
			return { tx, ty }
		end
	end

	return false
end

local function can_be_seen(looker_id, looked_id)
	-- Game mode check.
	if tonumber(game('sv_gamemode')) == hc.DEATHMATCH then
		return false
	end

	-- Same team check.
	if player(looker_id, 'team') ~= player(looked_id, 'team') then
		return false
	end

	-- Raycast check.
	if tonumber(game('sv_fow')) > 0 then
		local looker_x, looker_y = player(looker_id, 'x'), player(looker_id, 'y')
		local looked_x, looked_y = player(looked_id, 'x'), player(looked_id, 'y')

		if raycast_wall(looker_x, looker_y, looked_x, looked_y, false) then
			return false
		end
	end

	return true
end

------------------------------------------------------------------------------
-- Public functions
------------------------------------------------------------------------------

function hc.health_mod.set_parse_lock(state)
	parse_lock = state
end

------------------------------------------------------------------------------
-- Overrides
------------------------------------------------------------------------------

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

function hc.health_mod.init_player_hook(p, reason)
	if reason == hc.SCRIPT_INIT then
		return
	end

	hc.players[p].health_mod = {
		health = 0,
		max_health = 100,
		images = {
			symbol = nil,
			numbers = {}
		},
		spectating = nil,
		spectators = {}
	}
end

function hc.health_mod.spawn_hook(p)
	-- This makes it so core health is set to 250 (max)
	-- to allow maximum incoming damage per hit.
	parse_lock = false

	parse(('setmaxhealth "%d" "%d"'):format(p, 250))

	timer(0, 'parse', ('lua hc.health_mod.set_parse_lock(%s)'):format('true'))

	-- This initialises the player.
	set_health(p, get_max_health(p))
	set_spec(p, 0)
end

function hc.health_mod.die_hook(victim, killer, wpnTypeId, x, y, objId)
	set_health(victim, 0)
	set_spec(victim, player(victim, 'spectating'))

	if killer > 0 then
		show_kill_info(victim, killer)
	end
end

function hc.health_mod.hit_hook(victim, source, wpnTypeId, hpDmg, apDmg, rawDmg, objId)
	if hpDmg <= 0 then
		return 1
	end

	local new_health = get_health(victim) - hpDmg
	local x, y = player(victim, 'x'), player(victim, 'y')

	if new_health <= 0 then
		local weapon_name_and_image_path = get_weapon_name_and_image_path(wpnTypeId, objId)

		-- set_health is called on the die_hook, so no need to call it here.
		parse(('customkill "%d" "%s" "%d"'):format(source, weapon_name_and_image_path, victim))

		-- Play die sound.
		parse(('sv_soundpos "%s" "%d" "%d"'):format(('player/die%d.wav'):format(math.random(3)), x, y))
	else
		set_health(victim, new_health)

		-- Play hit sound.
		parse(('sv_soundpos "%s" "%d" "%d"'):format(('player/hit%d.wav'):format(math.random(3)), x, y))
	end

	-- Calculate armour damage for kevlar armour.
	if apDmg > 0 then
		local new_ap = player(victim, 'armor') - apDmg

		parse(('setarmor %d %d'):format(victim, new_ap))
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

		set_health(id, health)

		return 2
	elseif command.command == 'setmaxhealth' then
		local id, max_health = unpack(command.args)

		id, max_health = tonumber(id), tonumber(max_health)

		set_max_health(id, max_health)
		-- In CS2D the default behaviour when setting max health
		-- is to also set the current health.
		set_health(id, max_health)

		return 2
	elseif command.command == 'mp_hud' or command.command == 'mp_hovertext' then
		print_error(('Changing "%s" when using the Health Mod module is not supported.'):format(command.command))

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
	for id = 1, hc.SLOTS do
		if hc.player_exists(id) and player(id, 'health') > 0 then
			draw_health_images(id, get_health(id))
			draw_health_symbol(id, get_health(id))
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
		local looker_id = players[i]

		local mmx, mmy = player(looker_id, 'mousemapx'), player(looker_id, 'mousemapy')
		local caught

		for j = 1, #players do
			local looked_id = players[j]

			if looker_id ~= looked_id then
				local looked_x, looked_y = player(looked_id, 'x'), player(looked_id, 'y')

				if is_inside_rect(mmx, mmy, looked_x - PLAYER_CORE, looked_y - PLAYER_CORE, looked_x + PLAYER_CORE, looked_y + PLAYER_CORE) then
					if can_be_seen(looker_id, looked_id) then
						local mx, my = player(looker_id, 'mousex'), player(looker_id, 'mousey') + 24
						local text = ('%s%d%%'):format(hc.LIME, get_health(looked_id))

						parse(('hudtxt2 "%d" "%d" "%s" "%d" "%d" "%d" "%d" "%d"'):format(
							looker_id, HOVER_HUDTXT.id, text, mx, my, 1, 1, 7))

						caught = true

						return -- No more code to execute.
					end
				end
			end
		end

		if not caught then
			parse(('hudtxt2 "%d" "%d" "%s"'):format(looker_id, HOVER_HUDTXT.id, ''))
		end
	end
end

function hc.health_mod.second_hook()
	local players = player(0, 'tableliving')

	local isZombies = tonumber(game('sv_gamemode')) == hc.ZOMBIES
	local zombieHeal = tonumber(game('mp_zombierecover'))

	local dispenserHeal = tonumber(game('mp_dispenser_health'))

	for i = 1, #players do
		local id = players[i]
		local curHealth = get_health(id)
		local toHeal = 0

		if curHealth < get_max_health(id) then
			-- Heal 10 HP/s for medic armour wearers.
			if player(id, 'armor') == 204 then
				toHeal = toHeal + 10
			end

			-- Heal zombies.
			if isZombies and player(id, 'team') == hc.T then
				toHeal = toHeal + zombieHeal
			end

			-- Heal from dispenser.
			if dispenserHeal > 0 then
				local x, y = player(id, 'x'), player(id, 'y')
				local nearbyDispensers = closeobjects(x, y, DISPENSER_RANGE, hc.BUILDINGS.DISPENSER)
				local nearbyDispensersC = #nearbyDispensers

				if nearbyDispensersC > 0 then
					local playerTeam = player(id, 'team')

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
	if tonumber(game('sv_gamemode')) ~= hc.ZOMBIES then
		return
	elseif player(p, 'team') ~= hc.T then
		return
	end

	local curHealth = get_health(p)

	if curHealth < get_max_health(p) then
		set_health(p, curHealth + ZOMBIE_SPRAY_RECOVER)
	end
end
