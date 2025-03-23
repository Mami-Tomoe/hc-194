-- ----------------------------------------------------------------------------
-- Module API
-- ----------------------------------------------------------------------------

local servers

function hc.reroute.init()
	-- Menu commands.
	hc.add_menu_command("Reroute", hc.reroute.reroute_command, hc.REROUTE_LEVEL, hc.COMMAND_MENU_KEY)

	-- Hooks.
	addhook('init', 'hc.reroute.init_hook')
end

-- ----------------------------------------------------------------------------
-- Hooks callback
-- ----------------------------------------------------------------------------

function hc.reroute.init_hook()
	local t = {}
	local _servers = hc.REROUTE_SERVERS

	for i = 1, #_servers do
		local sv = _servers[i]

		table.insert(t,
			{
				title = sv.name .. '|' .. sv.ip,
				ip = sv.ip
			})
	end

	servers = t
end

-- ----------------------------------------------------------------------------
-- Menu commands
-- ----------------------------------------------------------------------------

function hc.reroute.reroute_command(p)
	hc.show_menu(p, 'Reroute', servers,
		function(p, _, item)
			hc.event(0, player(p, 'name') .. ' was rerouted to ' .. item.title:gsub('|', ' ') .. '.')

			parse('reroute ' .. p .. ' ' .. item.ip)
		end, nil, true)
end
