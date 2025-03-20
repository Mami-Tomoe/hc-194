-------------------------------------------------------------------------------
-- Module API
-------------------------------------------------------------------------------

function hc.undo.init()
	hc.add_say_command('undo', hc.undo.undo_command, hc.UNDO_LEVEL, '[<argument>]',
		'Allows to revert commands. Use arg "?" to list revertible commands. Use number arg to revert commands.', true)

	addhook('init_player', 'hc.undo.init_player_hook')
	addhook('delete_player', 'hc.undo.delete_player_hook')
end

-------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------

function hc.undo.init_player_hook(p, reason)
	hc.players[p].undo = { cmd_history = {} }
end

function hc.undo.delete_player_hook(p, reason)
	hc.players[p].undo = nil
end

-------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------

---Register a command to possibly revert in a player's dictionary.
---@param p number player number identifier
---@param cmd string command title
---@param description string description of what reverting will do
---@param undoFunc function the function to call when a revert is requested
function hc.undo.register_command(p, cmd, description, undoFunc)
	local t = hc.players[p].undo.cmd_history

	table.insert(t, {
		cmd = cmd,
		desc = description,
		func = undoFunc
	})

	while #t > hc.UNDO_MAX_HISTORY do
		table.remove(t, 1)
	end
end

-------------------------------------------------------------------------------
-- Say commands
-------------------------------------------------------------------------------

function hc.undo.undo_command(p, arg)
	local t = hc.players[p].undo.cmd_history

	if #t <= 0 then
		hc.error(p, 'No commands to undo.')
		hc.usage(p, 'undo')

		return
	end

	if arg == '?' then
		for i = 1, #t do
			local cmd_info = t[i]

			hc.event(p, {
				('Id: %d'):format(i),
				('Command: %s'):format(cmd_info.cmd),
				('Description: %s'):format(cmd_info.desc)
			})

			if i < #t then
				hc.event(p, ' ') -- Empty line.
			end
		end

		return
	end

	local cmd_id

	if arg then
		arg = tonumber(arg)

		if not arg then
			hc.error(p, 'Invalid command ID. Use argument "?" to view valid IDs.')
			hc.usage(p, 'undo')

			return
		end

		cmd_id = arg
	end

	if not cmd_id then
		-- cmd_id = #t
		-- There used to be the ability to not choose an argument in order to pick the last used command.
		-- This feature was scrapped because not all commands may support the feature, and thus could cause
		-- unintentional reverting of commands. So we force players to specify a command.

		hc.error(p, 'No command ID was specified.')
		hc.usage(p, 'undo')

		return
	end

	local cmd_info = t[cmd_id]

	if not cmd_id then
		hc.error(p, 'Command ID not found. Use argument "?" to view valid IDs.')
		hc.usage(p, 'undo')

		return
	end

	hc.info(p, {
		'Reverting command:',
		('Id: %d'):format(cmd_id),
		('Command: %s'):format(cmd_info.cmd),
		('Description: %s'):format(cmd_info.desc)
	})

	cmd_info.func(p)

	table.remove(t, cmd_id)

	hc.info(p, 'Revert success.')
end
