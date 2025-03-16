-------------------------------------------------------------------------------
-- Module API
-------------------------------------------------------------------------------

function hc.maps.init()
	if #hc.MAP_LIST < 2 then
		print("No maps to choose between - map voting disabled.")
	else
		hc.add_menu_command("Change Map", hc.maps.change_map_command, hc.CHANGE_MAP_LEVEL, hc.ADMIN_MENU_KEY)

		addhook("serveraction", "hc.maps.serveraction_hook")
		addhook("post_join", "hc.maps.post_join_hook")
		addhook("init_player", "hc.maps.init_player_hook")
		addhook("delete_player", "hc.maps.delete_player_hook")
		addhook("startround", "hc.maps.startround_hook")
		addhook("endround", "hc.maps.endround_hook")
		addhook("init", "hc.maps.init_hook")
		--    addhook("remove",	    "hc.maps.remove_hook")

		hc.maps.rounds_left = hc.MAP_ROUNDS
		hc.maps.set_map_round_timer()
		hc.maps.set_game_mode()
	end
end

-------------------------------------------------------------------------------
-- Hooks
-------------------------------------------------------------------------------

function hc.maps.post_join_hook(p)
	--    hc.maps.display_map_votes_player(p)
	hc.maps.display_map_votes_all()
end

function hc.maps.delete_player_hook(p, reason)
	hc.maps.display_map_votes()
end

function hc.maps.init_player_hook(p, reason)
	hc.players[p].map_vote = {}
end

function hc.maps.startround_hook(mode)
	local set_timer = hc.MAP_ROUND_LIMIT ~= nil and hc.MAP_ROUND_LIMIT > 0 and hc.maps.rounds_left > 1
	if hc.maps.rounds_left <= 0 then
		local map = hc.maps.next_map

		if map ~= nil and map ~= game("sv_map") then
			parse("sv_map " .. hc.maps.next_map)
		else
			-- Same map
			--set_timer = false
			hc.maps.new_round()
		end
	end

	hc.maps.display_map_votes_all()

	if set_timer then
		hc.maps.set_map_round_timer()
	end
end

function hc.maps.endround_hook(mode)
	if hc.maps.map_round_timer ~= nil then
		hc.maps.map_round_timer = nil
		freetimer("hc.maps.map_round_timeout")
	end
	hc.maps.rounds_left = hc.maps.rounds_left - 1
	if hc.maps.rounds_left <= 0 then
		hc.maps.next_map = hc.maps.get_next_map()
		timer(1000, "hc.maps.show_next_map")
	end
end

function hc.maps.serveraction_hook(p, action)
	if action == hc.MAP_VOTE_MENU_KEY then
		hc.maps.display_menu(p)
		return 1
	end
end

function hc.maps.init_hook()
	hc.maps.display_map_votes_all()
end

-------------------------------------------------------------------------------
-- Menu callbacks
-------------------------------------------------------------------------------

function hc.maps.change_map_cb(p, id)
	local map = hc.maps.get_map_name(id)

	if map ~= game("sv_map") then
		hc.exec(p, "sv_map " .. map)
	else
		if hc.maps.rounds_left == 1 then
			hc.maps.rounds_left = 2
		end
		hc.exec(p, "restart")
	end
end

-------------------------------------------------------------------------------
-- Menu commands
-------------------------------------------------------------------------------

function hc.maps.change_map_command(p, id)
	local maps = hc.maps.get_map_menu(true)
	hc.show_menu(p, "Change Map", maps, hc.maps.change_map_cb)
end

-------------------------------------------------------------------------------
-- Internal functions
-------------------------------------------------------------------------------

function hc.maps.set_game_mode()
	local map = game("sv_map")

	for id = 1, #hc.MAP_LIST do
		if map == hc.maps.get_map_name(id) then
			local mode = hc.maps.get_map_game_mode(id)

			if mode ~= nil then
				parse("sv_gamemode " .. mode)
			end
			break
		end
	end
end

function hc.maps.get_map_name(n)
	if type(hc.MAP_LIST[n]) == "table" then
		return hc.MAP_LIST[n].name
	else
		return hc.MAP_LIST[n]
	end
end

function hc.maps.get_map_game_mode(n)
	if type(hc.MAP_LIST[n]) == "table" then
		return hc.MAP_LIST[n].mode
	else
		return nil
	end
end

function hc.maps.new_round()
	-- Reset the map votes
	for i = 1, hc.SLOTS do
		if hc.player_exists(i) then
			hc.players[i].map_vote.vote = nil
			hc.players[i].map_vote.time = nil
		end
	end
	hc.maps.rounds_left = hc.MAP_ROUNDS + 1 -- endround_hook will decrease by one
	hc.next_map = nil
	parse("restart")
end

function hc.maps.display_map_votes_all()
	parse("hudtxt 48 \"Next map [in " .. hc.get_agreed_string(hc.maps.rounds_left, "round") .. "]:\" 425 425 1 1 11")
	hc.maps.display_map_votes()
end

function hc.maps.show_next_map()
	hc.event("Next Map: " .. hc.maps.next_map .. "@C")
end

function hc.maps.set_map_round_timer()
	if hc.maps.map_round_timer ~= nil then
		print("Error: Map round timer already set!")
	else
		timer(hc.MAP_ROUND_LIMIT * 60 * 1000, "hc.maps.map_round_timeout", nil, hc.maps.rounds_left - 1)
		hc.maps.map_round_timer = true
	end
end

function hc.maps.map_round_timeout()
	hc.maps.rounds_left = hc.maps.rounds_left - 1
	hc.maps.display_map_votes_all()
	hc.event("Map round limit reached.")
	if hc.maps.rounds_left <= 1 then
		hc.maps.map_round_timer = nil
	end
end

function hc.maps.get_map_votes()
	local votes = {}
	local max_votes = 0
	for p = 1, hc.SLOTS do
		if hc.player_exists(p) then
			local id = hc.players[p].map_vote.vote
			local time = hc.players[p].map_vote.time

			if id ~= nil then
				if votes[id] == nil then
					votes[id] = { count = 1, last_time = hc.players[p].map_vote.time }
				else
					votes[id] = {
						count = votes[id].count + 1,
						last_time = math.max(votes[id].last_time, time)
					}
				end
				if votes[id].count > max_votes then
					max_votes = votes[id].count
				end
			end
		end
	end
	return votes, max_votes
end

function hc.maps.get_next_map()
	local votes, max_votes = hc.maps.get_map_votes()

	-- If several maps get the same number of votes, the map that first reached
	-- that number of votes wins.
	local map
	local vote_time = 2 ^ 32
	for id, v in pairs(votes) do
		if v.count == max_votes and v.last_time < vote_time then
			map = id
			vote_time = v.last_time
		end
	end
	if map == nil then
		return game("sv_map"), 0
	else
		return hc.maps.get_map_name(map), max_votes
	end
end

function hc.maps.display_map_votes()
	local map, votes = hc.maps.get_next_map()
	parse("hudtxt 47 \"" .. map .. "   [" .. hc.get_agreed_string(votes, "vote") .. "]\" 425 438 1 1 11")
end

function hc.maps.display_menu(p)
	local maps = hc.maps.get_map_menu(true)
	hc.show_menu(p, "Map Vote", maps,
		function(p, id)
			local now = os.time()

			if hc.players[p].map_vote.time ~= nil and
				(now - hc.players[p].map_vote.time) < hc.MAP_VOTE_COOLDOWN_TIME then
				hc.event(p, "You must wait " .. hc.MAP_VOTE_COOLDOWN_TIME .. " seconds before voting again.")
			else
				hc.players[p].map_vote.vote = id
				hc.players[p].map_vote.time = os.time()
				hc.maps.display_map_votes()
				hc.event(player(p, "name") .. " votes for " .. hc.maps.get_map_name(id) .. ".")
			end
		end)
end

function hc.maps.get_map_menu()
	local votes, max_votes = hc.maps.get_map_votes()
	local maps = {}
	local current_map = game("sv_map")

	for id = 1, #hc.MAP_LIST do
		local map = hc.maps.get_map_name(id)

		if map == current_map then
			maps[id] = map .. " [current]"
		else
			maps[id] = map
		end
		if votes[id] then
			maps[id] = maps[id] .. "|" .. votes[id].count
		end
	end
	return maps
end
