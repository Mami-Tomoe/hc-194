--------------------------------------------------------------------------------
-- Internal functions and variables
--------------------------------------------------------------------------------

local players


local function init_player(p)
	players[p] = {}

	for building_id, _ in pairs(hc.FAST_BUILD_CONFIG) do
		players[p][building_id] = 0
	end
end

-- Get the lowest level for a building.
-- That is usually the level the building originated in.
local function get_lowest_level(buildingType)
	if buildingType == hc.BUILDINGS.DUAL_TURRET
		or buildingType == hc.BUILDINGS.TRIPLE_TURRET then
		return hc.BUILDINGS.TURRET
	elseif buildingType == hc.BUILDINGS.SUPER_SUPPLY then
		return hc.BUILDINGS.SUPPLY
	end

	return buildingType
end

local function get_next_level(buildingType)
	if buildingType == hc.BUILDINGS.TURRET then
		return hc.BUILDINGS.DUAL_TURRET
	elseif buildingType == hc.BUILDINGS.DUAL_TURRET then
		return hc.BUILDINGS.TRIPLE_TURRET
	elseif buildingType == hc.BUILDINGS.SUPPLY then
		return hc.BUILDINGS.SUPER_SUPPLY
	elseif buildingType == hc.BUILDINGS.WALL_I then
		return hc.BUILDINGS.WALL_II
	elseif buildingType == hc.BUILDINGS.WALL_II then
		return hc.BUILDINGS.WALL_III
	end
end


--------------------------------------------------------------------------------
-- Hooks
--------------------------------------------------------------------------------

function hc.fast_build.init_player_hook(p, reason)
	init_player(p)
end

function hc.fast_build.delete_player_hook(p, reason)
	players[p] = nil
end

function hc.fast_build.buildattempt_hook(p, buildingType, tx, ty, mode)
	local building_config = hc.FAST_BUILD_CONFIG[buildingType]

	if not building_config then
		return
	end

	local limit = building_config.limit

	if limit then
		local used = players[p][buildingType]

		if used >= limit then
			hc.event(p, hc.RED .. 'You can\'t build more buildings of this type@C')

			return 1
		end

		local price = hc.FAST_BUILD_CONFIG[buildingType].price

		if price then
			local money = player(p, 'money')

			if price > money then
				hc.event(p, hc.RED .. 'You have insufficient funds@C')

				return 1
			end
		end
	end
end

function hc.fast_build.build_hook(p, buildingType, tx, ty, mode, obj)
	local has_limit = players[p][buildingType]

	if has_limit then
		players[p][buildingType] = players[p][buildingType] + 1

		local price = hc.FAST_BUILD_CONFIG[buildingType].price

		if price then
			parse('setmoney ' .. p .. ' ' .. player(p, 'money') - price)
		end

		local rot = player(p, 'rot')
		local ms_time = 0

		-- Special care for laser mines (incomplete).
		if buildingType == hc.BUILDINGS.LASER_MINE then
			rot = (180 - rot) % 360 -- This needs to be fixed.
			ms_time = 3000

			local x, y = player(p, 'x'), player(p, 'y')

			cs2d_timer(ms_time, 'parse', 'sv_soundpos "weapons/mine_activate.wav" ' .. x .. ' ' .. y)
		end

		cs2d_timer(ms_time, 'parse',
			'spawnobject ' ..
			buildingType ..
			' ' .. tx .. ' ' .. ty .. ' ' .. rot .. ' ' .. mode .. ' ' .. player(p, 'team') .. ' ' .. p)

		return 1
	end
end

function hc.fast_build.objectkill_hook(obj, p)
	local buildingType = object(obj, 'type')

	if buildingType ~= hc.NPC then
		buildingType = get_lowest_level(buildingType)

		local id = object(obj, 'player')

		if hc.player_exists(id) then
			if players[id][buildingType] then
				players[id][buildingType] = players[id][buildingType] - 1
			end
		end
	end
end

function hc.fast_build.objectupgrade_hook(obj, p, progress, total)
	local buildingType = object(obj, 'type')
	local used = players[p][buildingType]
	local building_config = hc.FAST_BUILD_CONFIG[buildingType]
	local limit = building_config.limit

	if used >= limit then
		hc.event(p, hc.RED .. 'You can\'t build more buildings of this type@C')

		return 1
	end

	if building_config.instant_upgrade then
		local new_object_type = get_next_level(buildingType)

		if not new_object_type then
			return
		end

		local upgrade_cost = ((total - progress) * 100) + 100

		if upgrade_cost > 0 then
			local money = player(p, 'money')

			if upgrade_cost > money then
				hc.event(p, hc.RED .. 'You have insufficient funds@C')
			else
				parse('setmoney ' .. p .. ' ' .. money - upgrade_cost)
			end
		end

		local obj_tx, obj_ty = object(obj, 'tilex'), object(obj, 'tiley')
		local rot = object(obj, 'rot')
		local mode = object(obj, 'mode')

		parse('killobject ' .. obj)

		local cmd = 'spawnobject "' ..
			new_object_type ..
			'" "' ..
			obj_tx .. '" "' .. obj_ty .. '" "' .. rot .. '" "' .. mode .. '" "' .. player(p, 'team') .. '" "' .. p .. '"'

		cs2d_timer(0, 'parse', cmd)

		return 1
	end
end

function hc.fast_build.startround_prespawn_hook(mode)
	for p = 1, hc.SLOTS do
		if hc.player_exists(p) then
			init_player(p)
		end
	end
end

--------------------------------------------------------------------------------
-- Module API
--------------------------------------------------------------------------------

function hc.fast_build.init()
	players = {}

	-- Force new limits
	for building_id, building_config in pairs(hc.FAST_BUILD_CONFIG) do
		parse('mp_building_limit "' .. hc.BUILDING_NAMES[building_id] .. '" "' .. building_config.limit .. '"')
		parse('mp_building_price "' .. hc.BUILDING_NAMES[building_id] .. '" "' .. building_config.price .. '"')
	end

	-- Hooks
	addhook('init_player', 'hc.fast_build.init_player_hook')
	addhook('delete_player', 'hc.fast_build.delete_player_hook')
	addhook('buildattempt', 'hc.fast_build.buildattempt_hook')
	addhook('build', 'hc.fast_build.build_hook')
	addhook('objectkill', 'hc.fast_build.objectkill_hook')
	addhook('objectupgrade', 'hc.fast_build.objectupgrade_hook')
	addhook('startround_prespawn', 'hc.fast_build.startround_prespawn_hook')
end
