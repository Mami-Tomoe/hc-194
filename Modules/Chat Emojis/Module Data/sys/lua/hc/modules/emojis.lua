local emoji_list_tbl = {}
local HUD_TEXT_IDS = { 6, 7 }
local EMOJI_PROP_NAME = 'emoji_char'
local EMOJI_LIST_BUTTON_COORDS = {
	[4] = { x = { 310, 350 }, y = { 220, 250 } },
	[5] = { x = { 500, 540 }, y = { 220, 250 } },
	[6] = { x = { 530, 550 }, y = { 180, 195 } },
}


------------------------------------------------------------------------------
-- Module API
------------------------------------------------------------------------------

function hc.emojis.init()
	hc.add_menu_command('Emoji List', hc.emojis.emoji_list_command, hc.EMOJI_LIST_LEVEL, hc.COMMAND_MENU_KEY,
		{ category = 'Help' })
	hc.add_menu_command('Emoji Usage', hc.emojis.emoji_usage_command, hc.EMOJI_USAGE_LEVEL, hc.COMMAND_MENU_KEY,
		{ category = 'Config' })

	addhook('attack', 'hc.emojis.attack_hook', 999999)
	addhook('clientdata', 'hc.emojis.clientdata_hook', 999999)
	addhook('ms100', 'hc.emojis.ms100_hook')
	addhook('die', 'hc.emojis.die_hook', 999999)
	addhook('serveraction', 'hc.emojis.serveraction_hook', -999999)
	addhook('key', 'hc.emojis.key_hook')
	addhook('init', 'hc.emojis.init_hook')

	addbind('mwheelup')
	addbind('mwheeldown')
	addbind('mouse3')

	-- Override proxy hook to inject compatibility with all HC chat scripts.
	hc.main.say_proxy_hook = hc.emojis.say_hook
	hc.main.sayteam_proxy_hook = hc.emojis.sayteam_hook
end

------------------------------------------------------------------------------
-- Internal functions
------------------------------------------------------------------------------

function hc.emojis.check_for_emojis(p, message)
	local prop = hc.get_player_property(p, EMOJI_PROP_NAME) or '~'

	for k, v in pairs(hc.EMOJIS_CONFIG) do
		k, v = v.dir, v.str

		if type(v) == 'table' then
			for _, alt in pairs(v) do
				message = message:gsub(prop .. alt .. (prop == ':' and ':' or ''),
					'\174' .. hc.chat.EMOTICON_PATH .. 'chat/' .. k .. '.png')
			end
		else
			message = message:gsub(prop .. v .. (prop == ':' and ':' or ''),
				'\174' .. hc.chat.EMOTICON_PATH .. 'chat/' .. k .. '.png')
		end
	end

	return message
end

function hc.emojis.say_cb(p, text, team_chat)
	local title = player(p, 'name')
	local gamemode = tonumber(game('sv_gamemode'))
	local team = player(p, 'team')
	local dead = player(p, "health") == 0

	-- Colour based on team (unless death-match).
	-- Spectators always override this.
	if team == hc.SPEC then
		title = hc.SPEC_YELLOW .. title
	elseif gamemode == hc.DEATHMATCH then
		title = hc.LIME .. title
	else
		if team == 1 then
			title = hc.T_RED .. title
		elseif team >= 2 then
			title = hc.CT_BLUE .. title
		end
	end

	text = hc.SPEC_YELLOW .. text

	local team_chat_string = (team_chat and (hc.SPEC_YELLOW .. ' (Team)')) or ''

	-- Dead tag.
	if dead then
		text = title .. hc.SPEC_YELLOW .. team_chat_string .. ' *DEAD*: ' .. text
	else
		text = title .. team_chat_string .. ': ' .. text
	end

	-- Show to team members only.
	-- If dead on standard game mode.
	-- Or team chat.
	if (gamemode == hc.NORMAL and dead) or team_chat then
		for id = 1, hc.SLOTS do
			if hc.player_exists(id) and team == player(id, 'team') then
				msg2(id, text)
			end
		end

		return
	end

	-- Show to everyone.
	msg(text)
end

------------------------------------------------------------------------------
-- Hooks
------------------------------------------------------------------------------

function hc.emojis.serveraction_hook(p, action)
	if hc.players[p] and hc.players[p].previewpage then
		hc.emojis.emoji_list_close(p)
	end
end

function hc.emojis.attack_hook(p)
	if hc.players[p].preview and hc.players[p].preview[3] ~= 2 then
		local x, y = player(p, 'mousex'), player(p, 'mousey')

		for k, v in pairs(EMOJI_LIST_BUTTON_COORDS) do
			if x >= v.x[1] and x <= v.x[2] and y >= v.y[1] and y <= v.y[2] then
				local page, maxpage = hc.players[p].previewpage or 1, #emoji_list_tbl

				if k == 4 then
					page = page - 1
				elseif k == 5 then
					page = page + 1
				elseif k == 6 then
					hc.emojis.emoji_list_close(p)

					return
				end

				if page > maxpage then page = maxpage elseif page < 1 then page = 1 end

				hc.players[p].previewpage = page
				hc.emojis.emoji_list_select(p, page)

				return
			end
		end
	end
end

function hc.emojis.clientdata_hook(p, mode, x, y)
	if hc.players[p] and hc.players[p].preview and hc.players[p].preview[3] ~= 2 then
		local got = false

		for k, v in pairs(EMOJI_LIST_BUTTON_COORDS) do
			if x >= v.x[1] and x <= v.x[2] and y >= v.y[1] and y <= v.y[2] then
				if k == 4 then
					freeimage(hc.players[p].preview[4])
					hc.players[p].preview[4] = image('gfx/hc/emoji_form_button_left_on.png', 0, 0, p + 132, p)
				elseif k == 5 then
					freeimage(hc.players[p].preview[5])
					hc.players[p].preview[5] = image('gfx/hc/emoji_form_button_right_on.png', 0, 0, p + 132, p)
				elseif k == 6 then
					freeimage(hc.players[p].preview[6])
					hc.players[p].preview[6] = image('gfx/hc/emoji_form_button_close_on.png', 0, 0, p + 132, p)
				end

				if hc.players[p].preview[7] == 4 and k ~= 4 then
					freeimage(hc.players[p].preview[4])
					hc.players[p].preview[4] = image('gfx/hc/emoji_form_button_left_off.png', 0, 0, p + 132, p)
				elseif hc.players[p].preview[7] == 5 and k ~= 5 then
					freeimage(hc.players[p].preview[5])
					hc.players[p].preview[5] = image('gfx/hc/emoji_form_button_right_off.png', 0, 0, p + 132, p)
				elseif hc.players[p].preview[7] == 6 and k ~= 6 then
					freeimage(hc.players[p].preview[6])
					hc.players[p].preview[6] = image('gfx/hc/emoji_form_button_close_off.png', 0, 0, p + 132, p)
				end

				hc.players[p].preview[7] = k
				got = true

				break
			end
		end

		if not got then
			if hc.players[p].preview[7] == 4 and k ~= 4 then
				freeimage(hc.players[p].preview[4])
				hc.players[p].preview[4] = image('gfx/hc/emoji_form_button_left_off.png', 0, 0, p + 132, p)
			elseif hc.players[p].preview[7] == 5 and k ~= 5 then
				freeimage(hc.players[p].preview[5])
				hc.players[p].preview[5] = image('gfx/hc/emoji_form_button_right_off.png', 0, 0, p + 132, p)
			elseif hc.players[p].preview[7] == 6 and k ~= 6 then
				freeimage(hc.players[p].preview[6])
				hc.players[p].preview[6] = image('gfx/hc/emoji_form_button_close_off.png', 0, 0, p + 132, p)
			end
		end
	end
end

function hc.emojis.ms100_hook()
	for p = 1, hc.SLOTS do
		if hc.player_exists(p) then
			reqcld(p, 0)
		end
	end
end

function hc.emojis.die_hook(p)
	if hc.players[p].preview then
		hc.emojis.emoji_list_delay(p)
		hc.players[p].previewpage = nil
	end
end

function hc.emojis.key_hook(p, key, state)
	if hc.players[p] and hc.players[p].previewpage then
		local page, maxpage = hc.players[p].previewpage or 1, #emoji_list_tbl

		if key == 'mwheeldown' then
			page = page - 1
		elseif key == 'mwheelup' then
			page = page + 1
		elseif key == 'mouse3' then
			hc.emojis.emoji_list_close(p)
			return
		end

		if page > maxpage then page = maxpage elseif page < 1 then page = 1 end

		hc.players[p].previewpage = page
		hc.emojis.emoji_list_select(p, page)
	end
end

function hc.emojis.init_hook()
	for k, v in pairs(hc.EMOJIS_CONFIG) do
		k, v = v.dir, v.name

		if k:sub(1, 6) == 'custom' then
			local button = ''

			if type(v) == 'table' then
				local str = ''

				for a, b in pairs(v) do
					str = str .. ' / ' .. b
				end

				button = '[' .. str:sub(4) .. ']'
			else
				button = v
			end

			table.insert(emoji_list_tbl, { title = button, dir = k })
		end
	end
end

function hc.emojis.say_hook(...)
	local p, text = unpack(arg)

	-- Inject emojis.
	text = hc.emojis.check_for_emojis(p, text)

	-- Get return value.
	local value = hc.main.call_hook("say", false, p, text)

	-- If value is not 1, then we must print a custom message.
	if value == 1 then
		return 1
	end

	hc.emojis.say_cb(p, text, false)

	return 1
end

function hc.emojis.sayteam_hook(...)
	local p, text = unpack(arg)

	-- Inject emojis.
	text = hc.emojis.check_for_emojis(p, text)

	-- Get return value.
	local value = hc.main.call_hook("say", false, p, text)

	-- If value is not 1, then we must print a custom message.
	if value == 1 then
		return 1
	end

	hc.emojis.say_cb(p, text, true)

	return 1
end

------------------------------------------------------------------------------
-- Menu commands
------------------------------------------------------------------------------

function hc.emojis.emoji_usage_command(p)
	local char = hc.get_player_property(p, EMOJI_PROP_NAME)

	if char == nil then
		hc.set_player_property(p, EMOJI_PROP_NAME, '~')

		char = hc.get_player_property(p, EMOJI_PROP_NAME)
	end

	local menu = {
		char ~= '~' and { title = 'Say:|~example', value = '~' } or nil,
		char ~= ':' and { title = 'Say:|:example:', value = ':' } or nil,
		char ~= '' and { title = 'Say:|example', value = '' } or nil,
	}

	hc.show_menu(p, 'Emoji Usage', menu,
		function(p, _, item)
			hc.set_player_property(p, EMOJI_PROP_NAME, item.value)

			hc.info(p, 'Emoji usage preferences saved.')
		end)
end

function hc.emojis.emoji_list_command(p)
	if player(p, 'health') > 0 then
		hc.players[p].previewpage = 1
		hc.emojis.emoji_list_select(p, 1)

		hc.players[p].previewwpn = player(p, 'weapon')
		parse('setweapon ' .. p .. ' 50')

		hc.info(p, '[Mouse Wheel Up] -> Next Emoji.')
		hc.info(p, '[Mouse Wheel Down] -> Previous Emoji.')
		hc.info(p, '[Mouse Button Left] -> Select Button.')
		hc.info(p, '[Mouse Button Middle] , [F2] , [F3] and [F4] -> Close Menu.')
	else
		hc.error(p, 'You must be alive to view the Emoji list.')
	end
end

function hc.emojis.emoji_list_select(p, arg)
	local name, dir = (hc.get_player_property(p, EMOJI_PROP_NAME) or '~') .. emoji_list_tbl[arg].title,
		'chat/' .. emoji_list_tbl[arg].dir .. '.png'
	if hc.get_player_property(p, EMOJI_PROP_NAME) == ':' then
		name = name .. ':'
	end

	if hc.players[p].preview then
		if hc.players[p].preview[3] == 1 then
			hc.emojis.emoji_list_delay(p)
		end
		hc.players[p].preview = nil
	end

	parse('hudtxt2 ' ..
		p .. ' ' .. HUD_TEXT_IDS[1] .. ' "' .. hc.WHITE .. 'Emoji List' .. '" 360 193 0 1 11')
	parse('hudtxt2 ' ..
		p ..
		' ' ..
		HUD_TEXT_IDS[2] .. ' "' .. hc.SPEC_YELLOW .. 'Say: ' .. hc.WHITE .. name .. '" 425 270 1 1 9')

	hc.players[p].preview = {
		[1] = image('gfx/hc/emoji_form.png', 0, 0, p + 132, p),
		[2] = image(hc.chat.EMOTICON_PATH .. dir, 0, 0, p + 132, p),
		[3] = 1,
		[4] = image('gfx/hc/emoji_form_button_left_off.png', 0, 0, p + 132, p),
		[5] = image('gfx/hc/emoji_form_button_right_off.png', 0, 0, p + 132, p),
		[6] = image('gfx/hc/emoji_form_button_close_off.png', 0, 0, p + 132, p),
		[7] = 0
	}
end

function hc.emojis.emoji_list_delay(p)
	p = tonumber(p)
	local time = 250

	parse('hudtxtalphafade ' .. p .. ' ' .. HUD_TEXT_IDS[1] .. ' ' .. time .. ' 0')
	parse('hudtxtalphafade ' .. p .. ' ' .. HUD_TEXT_IDS[2] .. ' ' .. time .. ' 0')

	tween_alpha(hc.players[p].preview[1], time, 0)
	tween_alpha(hc.players[p].preview[2], time, 0)
	tween_alpha(hc.players[p].preview[4], time, 0)
	tween_alpha(hc.players[p].preview[5], time, 0)
	tween_alpha(hc.players[p].preview[6], time, 0)
	timer(time, 'freeimage', hc.players[p].preview[1])
	timer(time, 'freeimage', hc.players[p].preview[2])
	timer(time, 'freeimage', hc.players[p].preview[4])
	timer(time, 'freeimage', hc.players[p].preview[5])
	timer(time, 'freeimage', hc.players[p].preview[6])

	hc.players[p].preview[3] = 2
end

function hc.emojis.emoji_list_close(p)
	hc.emojis.emoji_list_delay(p)
	hc.players[p].previewpage = nil

	parse('setweapon ' .. p .. ' ' .. hc.players[p].previewwpn)
	hc.players[p].previewwpn = nil
end
