------------------------------------------------------------------------------
-- Module API
------------------------------------------------------------------------------

local _math = require 'math'

function hc.editor.init()
	addhook('delete_player', 'hc.editor.delete_player_hook')
	addhook('say', 'hc.editor.say_hook', -9999999)
	addhook('serveraction', 'hc.editor.serveraction', -999999)
	addhook('mapchange', 'hc.editor.mapchange_hook')
	addhook('key', 'hc.editor.key_hook')
	addhook('startround', 'hc.editor.startround')
end

hc.editor.HUD_MSG_FIRST_ID = 26
hc.editor.HUD_MSG_MAX_LINES = 12

hc.editor.DELETE_ID = 1
hc.editor.FINISH_ID = 2
hc.editor.CANCEL_ID = 3

hc.editor.DRAFT = 'editor.draft'

hc.editor.COLOURS = {
	paused = {
		header = '\169198198198',
		message = '\169198198198',
		current_line = hc.WHITE
	},
	active = {
		header = '\169198198198',
		message = '\169198198198',
		current_line = hc.WHITE
	}
}


------------------------------------------------------------------------------
-- API
------------------------------------------------------------------------------

function hc.open_editor(p, message, title, menu_items, read_only)
	if hc.players[p].editor ~= nil then
		hc.error(p, 'Editor is already in use!')
		
		print('Error: Editor is already in use!')
		
		return
	end

	if message == nil then
		message = { }
	end

	local current_line = 1

	hc.players[p].editor = {
		title = title,
		message = message,
		menu_items = menu_items,
		current_line = current_line,
		read_only = read_only
	}
	hc.editor.show_header(p)
	hc.editor.display_message(p)
	hc.editor.show_background(p)
end

function hc.close_editor(p)
	for i = hc.editor.HUD_MSG_FIRST_ID,hc.editor.HUD_MSG_FIRST_ID + hc.editor.HUD_MSG_MAX_LINES + 5 do
		parse('hudtxt2 ' .. p .. ' ' .. i .. ' "" 0 0 0')
	end
	
	freeimage(hc.players[p].editor.background)
	
	hc.players[p].editor = nil
end


------------------------------------------------------------------------------
-- Internal functions
------------------------------------------------------------------------------

function hc.editor.show_header(p)
	local editor = hc.players[p].editor
	local colour = hc.editor.get_colours(p).header
	local info

	if editor.read_only then
		info = {
			colour .. hc.DEFAULT_KEYS[hc.SERVERACTION1] .. ' or MWheelUp to scroll one line up.',
			colour .. hc.DEFAULT_KEYS[hc.SERVERACTION2] .. ' or MWheelDown to scroll one line down.',
			colour .. hc.DEFAULT_KEYS[hc.SERVERACTION3] .. ' for menu.'
		}
	else
		info = {
			colour .. 'Press the "say" key to insert a new line.',
			colour .. hc.DEFAULT_KEYS[hc.SERVERACTION1] .. ' or MWheelUp to move cursor one line up.',
			colour .. hc.DEFAULT_KEYS[hc.SERVERACTION2] .. ' or MWheelDown to move cursor one line down.',
			colour .. hc.DEFAULT_KEYS[hc.SERVERACTION3] .. ' for menu.'
		}
	end

	local title = hc.WHITE .. editor.title

	if editor.paused then
		title = title .. '  *** Paused ***'
	end

	hc.editor.display_text(p,
		hc.editor.HUD_MSG_FIRST_ID + hc.editor.HUD_MSG_MAX_LINES,
		248, 80, 14, 0, { title }, nil, 10)
	hc.editor.display_text(p,
		hc.editor.HUD_MSG_FIRST_ID + 1 + hc.editor.HUD_MSG_MAX_LINES,
		252, 104, 14, 0, { unpack(info) }, nil, 10)
end

function hc.editor.display_text(p, first_id, x, first_y, vspacing, alignment, message, valignment, size)
	local y = first_y
	local id = first_id
	alignment = alignment or 0
	valignment = valignment or 0
	size = size or 13
	for _,line in ipairs(message) do
	-- Apparently strings with double quotes and semicolons don't work
	-- very well with the hudtxt* commands, so replace them with single
	-- quotes and colons.
		local str = line:gsub('"', '\''):gsub(';', ':')
		parse('hudtxt2 ' .. p .. ' ' .. id .. ' "' .. str .. '" ' .. x .. ' ' .. y .. ' ' .. alignment .. ' ' .. valignment .. ' ' .. size)
		y = y + vspacing
		id = id + 1
	end
end

function hc.editor.get_colours(p)
	if hc.players[p].editor.paused then
		return hc.editor.COLOURS.paused
	else
		return hc.editor.COLOURS.active
	end
end

function hc.editor.show_background(p)
	local img = image('gfx/hc/editor_form_updated.png', 448, 240, 2, p)
	
	imagealpha(img, 0.95)
	imagescale(img, 0.9, 0.8)
	
	hc.players[p].editor.background = img
end


--------------------------------------------------------------------------------
-- Hooks
--------------------------------------------------------------------------------

function hc.editor.startround()
	for p = 1, hc.SLOTS do
		if hc.player_exists(p) and hc.players[p].editor and hc.players[p].editor.background then
			hc.editor.show_background(p)
		end
	end
end

function hc.editor.delete_player_hook(p, reason)
	if hc.players[p].editor then
		local message = hc.players[p].editor.message

		if message ~= nil then
			hc.set_player_property(p, hc.editor.DRAFT, hc.to_csv(message))
		end
		hc.close_editor(p)
	end
end

function hc.editor.say_hook(p, msg)
	local editor = hc.players[p].editor
	if editor and not editor.read_only and not editor.paused then
	-- New line
		local m = editor.message

		table.insert(m, editor.current_line, msg)
		editor.current_line = editor.current_line + 1
		hc.editor.display_message(p)
		return 1
	else
		return 0
	end
end

function hc.editor.display_message(p)
	local editor = hc.players[p].editor
	local current_line = editor.current_line
	local m = editor.message
	local first_line

	if editor.read_only then
		first_line = current_line
	else
	-- Center the text vertically around the current line.
		first_line = _math.max(1, _math.min(current_line - hc.editor.HUD_MSG_MAX_LINES / 2,
			#m + 2 - hc.editor.HUD_MSG_MAX_LINES))
	end

	local last_line = first_line + hc.editor.HUD_MSG_MAX_LINES - 1
	local msg = { }

	for i=0,hc.editor.HUD_MSG_MAX_LINES - 1 do
		local line_num = i + first_line
		local line = m[line_num]

		if line == nil then
			line = ''
		end

		local colours = hc.editor.get_colours(p)

		if current_line ~= nil and current_line == line_num and not editor.read_only then
			line = colours.current_line .. '  [' .. line .. ']'
		elseif i == 0 and first_line > 1 then
			line = colours.message .. '^ ' .. line
		elseif i == hc.editor.HUD_MSG_MAX_LINES - 1 and (editor.read_only and last_line < #m or
				not editor.read_only and last_line < #m + 1) then
			line = colours.message .. 'v ' .. line
		else
			line = colours.message .. '   ' .. line
		end
		table.insert(msg, line)
	end
	hc.editor.display_text(p, hc.editor.HUD_MSG_FIRST_ID, 252, 194, 16, 0, msg, nil, 10)
end

function hc.editor.serveraction(p, action)
	local editor = hc.players[p].editor

	if editor then
		if action == hc.SERVERACTION1 then
			local current_line = _math.max(1, editor.current_line - 1)
			if current_line ~= editor.current_line then
				editor.current_line = current_line
				hc.editor.display_message(p)
			end
		elseif action == hc.SERVERACTION2 then
			local current_line
			if editor.read_only then
				current_line = _math.min(_math.max(1, #editor.message - hc.editor.HUD_MSG_MAX_LINES + 1),
					editor.current_line + 1)
			else
				current_line = _math.min(#editor.message + 1, editor.current_line + 1)
			end
			if current_line ~= editor.current_line then
				editor.current_line = current_line
				hc.editor.display_message(p)
			end
		else -- action == hc.SERVERACTION3
			local menu = { }

			if not editor.read_only then
				menu = {
					{ title = 'Load Draft', func = hc.editor.load_draft },
					{ title = 'Save Draft', func = hc.editor.save_draft },
					{ title = 'Delete Current Line', func = hc.editor.delete_line }
				}

				if editor.paused then
					table.insert(menu, 3, { title = 'Resume Editing', func = hc.editor.resume_editing })
				else
					table.insert(menu, 3, { title = 'Pause Editing', func = hc.editor.pause_editing })
				end
			end
			if editor.menu_items ~= nil then
				for _,item in ipairs(editor.menu_items) do
					table.insert(menu, item)
				end
			end
			hc.show_menu(p, editor.title, menu,
				hc.editor.menu_cb)
		end
		return 1
	end
end

function hc.editor.menu_cb(p, id, item)
	local editor = hc.players[p].editor
	local message, current_line = item.func(p, editor.message, editor.current_line)

	editor = hc.players[p].editor

	if editor ~= nil then
		if message ~= nil then
			editor.message = message
		end
		if current_line == nil then
			current_line = editor.current_line
		end
		editor.current_line = _math.min(current_line, #editor.message + 1)
		hc.editor.display_message(p)
	end
end

function hc.editor.delete_line(p, message, current_line)
	if #message > 0 then
		if current_line > #message then
			table.remove(message, #message)
		else
			table.remove(message, current_line)
		end
		return message
	end
end

function hc.editor.load_draft(p, message, current_line)
	local draft = hc.get_player_property(p, hc.editor.DRAFT)

	if draft ~= nil then
		return hc.from_csv(draft), 1
	end
	hc.event(p, 'Draft not found.')
end

function hc.editor.save_draft(p, message, current_line)
	hc.set_player_property(p, hc.editor.DRAFT, hc.to_csv(message))
	hc.event(p, 'Draft saved.')
end

function hc.editor.resume_editing(p, message, current_line)
	hc.players[p].editor.paused = false
	hc.editor.show_header(p)
	hc.editor.display_message(p)
end

function hc.editor.pause_editing(p, message, current_line)
	hc.players[p].editor.paused = true
	hc.editor.show_header(p)
	hc.editor.display_message(p)
end

function hc.editor.mapchange_hook(newmap)
	for i=1,hc.SLOTS do
		if hc.player_exists(i) and hc.players[i].editor ~= nil then
			local message = hc.players[i].editor.message

			if message ~= nil then
				hc.set_player_property(i, hc.editor.DRAFT, hc.to_csv(message))
			end
		end
	end
end

function hc.editor.key_hook(p, key, state)
	local editor = hc.players[p].editor
	
	if editor ~= nil and state == 1 then
		if key == 'mwheelup' then
			local current_line = _math.max(1, editor.current_line - 1)
			
			if current_line ~= editor.current_line then
				editor.current_line = current_line
				hc.editor.display_message(p)
			end
		elseif key == 'mwheeldown' then
			local current_line
			
			if editor.read_only then
				current_line = _math.min(_math.max(1, #editor.message - hc.editor.HUD_MSG_MAX_LINES + 1), editor.current_line + 1)
			else
				current_line = _math.min(#editor.message + 1, editor.current_line + 1)
			end
			
			if current_line ~= editor.current_line then
				editor.current_line = current_line
				hc.editor.display_message(p)
			end
		end
	end
end