-------------------------------------------------------------------------------
-- Module API
-------------------------------------------------------------------------------

function hc.teleport.init()
	hc.add_menu_command('Teleport', hc.teleport.teleport_menu_command, hc.TELEPORT_LEVEL, hc.ADMIN_MENU_KEY,
		{ category = 'Modify' })

	hc.add_say_command('tp', hc.teleport.teleport_say_command, hc.TELEPORT_LEVEL, '<id> [<pl>]',
		'Teleports the stated player to you or to the stated player.', true)
end

-------------------------------------------------------------------------------
-- Menu commands
-------------------------------------------------------------------------------

function hc.teleport.teleport_menu_command(p)
	local from, to
	local players = hc.get_players({ max_level = hc.VIP })
	local t = {}

	for i = 1, #players do
		local player_data = players[i]

		if player(player_data.id, 'health') > 0 then
			table.insert(t, player_data)
		end
	end

	players = t


	if #players <= 0 then
		return hc.error(p, 'No players to teleport.')
	end

	hc.show_menu(p, 'Teleport - From:', players,
		function(p, _, item)
			from = item.id

			for i = 1, #players do
				local player_data = players[i]

				if player_data.id == from then
					table.remove(players, i)

					break
				end
			end

			if #players <= 0 then
				return hc.error(p, 'No players to teleport to.')
			end

			hc.show_menu(p, 'Teleport - To:', players,
				function(p, _, item)
					to = item.id

					if hc.player_exists(from) and player(from, 'health') > 0
						and hc.player_exists(to) and player(to, 'health') > 0 then
						local x, y = player(to, 'x'), player(to, 'y')

						hc.exec(p, 'setpos ' .. from .. ' ' .. x .. ' ' .. y)

						hc.info(p, 'Teleport success.')
					else
						hc.error(p, 'Required player(s) to teleport either don\'t exist and or are no longer alive.')
					end
				end)
		end)
end

-------------------------------------------------------------------------------
-- Say commands
-------------------------------------------------------------------------------

function hc.teleport.teleport_say_command(p, arg)
	if (arg == nil or arg == '') then
		hc.error(p, 'Wrong command usage!')

		return false
	end

	local t = {}

	for player in arg:gmatch('%w+') do
		table.insert(t, player)
	end

	local id = tonumber(t[1]) or 0
	local pl = tonumber(t[2]) or 0

	if not player(id, 'exists') then
		return hc.error(p, 'Player A does not exist.')
	elseif not player(pl, 'exists') then
		return hc.error(p, 'Player B does not exist.')
	elseif id == pl then
		return hc.error(p, 'Player A and player B cannot be the same player.')
	elseif player(id, 'health') <= 0 or player(pl, 'health') <= 0 then
		return hc.error(p, 'Both players need to be alive.')
	end

	local x, y = player(pl, 'x'), player(pl, 'y')

	hc.exec(p, 'setpos ' .. id .. ' ' .. x .. ' ' .. y)

	return true
end
