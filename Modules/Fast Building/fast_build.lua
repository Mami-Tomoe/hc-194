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

local function get_next_level(buildingType)
	if buildingType == hc.BUILDINGS.TURRET then
		return hc.BUILDINGS.DUAL_TURRET
	elseif buildingType == hc.BUILDINGS.DUAL_TURRET then
		return hc.BUILDINGS.TRIPLE_TURRET
	elseif buildingType == hc.BUILDINGS.SUPPLY then
		return hc.BUILDINGS.SUPER_SUPPLY
	elseif buildingType == hc.BUILDINGS.BARRICADE then
		return hc.BUILDINGS.WALL_I
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
	end

	local price = building_config.price

	if price then
		local money = player(p, 'money')

		if price > money then
			hc.event(p, hc.RED .. 'You have insufficient funds@C')

			return 1
		end
	end
end

function hc.fast_build.build_hook(p, buildingType, tx, ty, mode, obj)
	local building_config = hc.FAST_BUILD_CONFIG[buildingType]

	if not building_config then
		return
	end

	local limit = building_config.limit

	if limit then
		players[p][buildingType] = players[p][buildingType] + 1
	end

	local price = building_config.price

	if price then
		parse('setmoney ' .. p .. ' ' .. player(p, 'money') - price)
	end

	if building_config.instant_build then
		local rot     = player(p, 'rot')
		local team    = player(p, 'team')
		local command = 'spawnobject ' ..
			buildingType .. ' ' .. tx .. ' ' .. ty .. ' ' .. rot .. ' ' .. mode .. ' ' .. team .. ' ' .. p

		cs2d_timer(0, 'parse', command)

		return 1
	end
end

function hc.fast_build.objectkill_hook(obj, p)
	local buildingType = object(obj, 'type')

	if buildingType ~= hc.NPC then
		local id = object(obj, 'player')

		if hc.player_exists(id) then
			if players[id][buildingType] then
				players[id][buildingType] = players[id][buildingType] - 1
			end
		end
	end
end

function hc.fast_build.objectupgrade_hook(obj, p, progress, total)
	local building_type = object(obj, 'type')
	local building_config = hc.FAST_BUILD_CONFIG[building_type]
	local used = players[p][building_type]
	local limit = building_config.limit

	if limit and used >= limit then
		hc.event(p, hc.RED .. 'You can\'t build more buildings of this type@C')

		return 1
	end

	local tick_cost = building_config.upgrade_cost or 100

	if not building_config.instant_upgrade then -- Fix the cost.
		local upgrade_cost = tick_cost - 100

		if upgrade_cost > 0 then
			local money = player(p, 'money')

			if upgrade_cost > money then
				hc.event(p, hc.RED .. 'You have insufficient funds@C')

				return 1
			else
				parse('setmoney ' .. p .. ' ' .. money - upgrade_cost)

				return 0
			end
		end
	else -- Full cost calculated below.
		local prev_object_type = building_type
		local next_object_type = get_next_level(building_type)

		if not next_object_type then
			return
		end

		local upgrade_cost = ((total - progress) * tick_cost) + tick_cost

		if upgrade_cost > 0 then
			local money = player(p, 'money')

			if upgrade_cost > money then
				hc.event(p, hc.RED .. 'You have insufficient funds@C')

				return 1
			else
				parse('setmoney ' .. p .. ' ' .. money - upgrade_cost)
			end
		end

		local obj_tx, obj_ty = object(obj, 'tilex'), object(obj, 'tiley')
		local rot = object(obj, 'rot')
		local mode = object(obj, 'mode')

		parse('killobject ' .. obj)

		local cmd = 'spawnobject "' ..
			next_object_type ..
			'" "' ..
			obj_tx .. '" "' .. obj_ty .. '" "' .. rot .. '" "' .. mode .. '" "' .. player(p, 'team') .. '" "' .. p .. '"'

		cs2d_timer(0, 'parse', cmd)

		if limit then
			players[p][prev_object_type] = players[p][prev_object_type] - 1
			players[p][next_object_type] = players[p][next_object_type] + 1
		end

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

	-- Force new limits and prices
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
