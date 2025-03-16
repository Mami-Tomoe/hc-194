------------------------------------------------------------------------------
-- Module API
------------------------------------------------------------------------------

-- Global constants

-- Init player
hc.SCRIPT_INIT = 1
hc.PLAYER_JOIN = 2


function hc.main.init()

    hc.players = {}

    -- Internal constants and variables
    hc.main.hooks = {}
    hc.main.real_hooks = {}
    --    hc.main.images     = {}
    hc.main.functions = {}

    for line in io.lines(hc.DIR .. "/core/version.txt") do
        hc.VERSION = line
    end

    print("HC CS2D Admin Script " .. hc.VERSION)

    -- Replace some original CS2D functions with our own ones
    hc.main.cs2d_addhook = addhook
    hc.main.cs2d_freehook = freehook
    --[[
        hc.main.cs2d_image     = image
        hc.main.cs2d_freeimage = freeimage
    ]]

    addhook = hc.main.add_hook
    freehook = hc.main.free_hook
    --[[
        image     = hc.main.image
        freeimage = hc.main.free_image
    ]]

    -- Proxy hooks
    hc.main.add_proxy_hook("join", "hc.main.join_proxy_hook")
    hc.main.add_proxy_hook("team", "hc.main.team_proxy_hook")
    hc.main.add_proxy_hook("spawn", "hc.main.spawn_proxy_hook")
    hc.main.add_proxy_hook("die", "hc.main.die_proxy_hook")
    hc.main.add_proxy_hook("build", "hc.main.build_proxy_hook")
    hc.main.add_proxy_hook("flagcapture", "hc.main.flagcapture_proxy_hook")
    hc.main.add_proxy_hook("dominate", "hc.main.dominate_proxy_hook")
    hc.main.add_proxy_hook("bombplant", "hc.main.bombplant_proxy_hook")
    hc.main.add_proxy_hook("bombdefuse", "hc.main.bombdefuse_proxy_hook")
    hc.main.add_proxy_hook("bombexplode", "hc.main.bombexplode_proxy_hook")
    hc.main.add_proxy_hook("say", "hc.main.say_proxy_hook")
    hc.main.add_proxy_hook("sayteam", "hc.main.sayteam_proxy_hook")
    hc.main.add_proxy_hook("radio", "hc.main.radio_proxy_hook")
    hc.main.add_proxy_hook("endround", "hc.main.endround_proxy_hook")
    hc.main.add_proxy_hook("serveraction", "hc.main.serveraction_proxy_hook")
    hc.main.add_proxy_hook("name", "hc.main.name_proxy_hook")
    hc.main.add_proxy_hook("objectdamage", "hc.main.objectdamage_proxy_hook")
    hc.main.add_proxy_hook("init")
    hc.main.add_proxy_hook("init_player")
    hc.main.add_proxy_hook("delete_player")
    hc.main.add_proxy_hook("post_join")
    hc.main.add_proxy_hook("player_level")

    --    hc.main.add_proxy_hook("remove")

    -- "Real" hooks
    --    addhook("endround",	    "hc.main.endround_hook",	  99999)
    addhook("menu", "hc.main.menu_hook", -99999)
    addhook("join", "hc.main.pre_join_hook", -99999)
    addhook("join", "hc.main.post_join_hook", 99999)
    --    addhook("leave",	    "hc.main.pre_leave_hook",	 -99999)
    addhook("leave", "hc.main.post_leave_hook", 99999)
    addhook("spawn", "hc.main.spawn_hook", 99999)
    addhook("minute", "hc.main.minute_hook", -99999)
    addhook("team", "hc.main.team_hook", -99999)

    --    addhook("remove",	    "hc.main.remove_hook",	  99999)

    -- Special hooks
    addhook("init_player", "hc.main.init_player_hook", -99999)
end


------------------------------------------------------------------------------
-- API
------------------------------------------------------------------------------

function hc.set_no_real_kill(p)
    hc.players[p].main.real_kill = false
end

function hc.set_no_real_death(p)
    hc.players[p].main.real_death = false
end

function hc.is_real_kill(p)
    return hc.players[p].main.real_kill == nil
end

function hc.is_real_death(p)
    return hc.players[p].main.real_death == nil
end

function hc.fix_name(name)
	if name:sub(0, -name:len()) == '(' then
		name = ' ' .. name
	end

	return name
end

function hc.get_name(p)

	return hc.fix_name(player(p, 'name'))
end

function hc.get_login(p)
    local usgn, steam = hc.get_usgn(p) or "0", hc.get_steam(p) or "0"

    return (usgn ~= "0" and usgn) or (steam ~= "0" and steam) or "0"
end

function hc.get_usgn(p)
    if hc.players[p] == nil or hc.players[p].main == nil then
        return tostring(player(p, "usgn"))
    else
        return hc.players[p].main.usgn
    end
end

function hc.get_steam(p)
    if hc.players[p] == nil or hc.players[p].main == nil then
        return player(p, "steamid")
    else
        return hc.players[p].main.steam
    end
end

function hc.show_menu(p, title, ids, command)
    local start

    if not ids then
        ids = hc.players[p].main.id_table
        start = hc.players[p].main.start_id
    else
    --if #ids == 0 then
    --    msg2(p, "No entries to show.")
    --end
        hc.players[p].main.id_table = ids
        start = nil
    end

    hc.players[p].main.menu_table = {}

    local hcmenu = title:gsub(",", ".")
    local menu_id = 1
    local last_id

    for id,title in next, ids, start do
        local next_menu_id, next_value = next(ids, id)
        -- and next_menu_id ~= nil
        if menu_id >= hc.NUM_MENU_ITEMS and (next_menu_id ~= nil or start ~= nil) then
            hcmenu = hcmenu .. ",Next >"
            hc.players[p].main.menu_table[menu_id] = 0
            hc.players[p].main.start_id = last_id
            menu_id = menu_id + 1
            break
        else
            if type(title) == "table" then
                title = title.title
            end
            -- Comma (',') is not allowed in menu titles
            hcmenu = hcmenu .. "," .. title:gsub(",", ".")
            hc.players[p].main.menu_table[menu_id] = id
            menu_id = menu_id + 1
            last_id = id
        end
    end
    if start ~= nil and menu_id < hc.NUM_MENU_ITEMS + 1 then
        hc.players[p].main.menu_table[hc.NUM_MENU_ITEMS] = 0
        hc.players[p].main.start_id = nil
        for i=menu_id,hc.NUM_MENU_ITEMS - 1 do
            hcmenu = hcmenu .. ","
        end
        hcmenu = hcmenu .. ",<< Start"
    end

    hc.players[p].main.menu_command = command
    menu(p, hcmenu)
end


------------------------------------------------------------------------------
-- CS2D function replacements
------------------------------------------------------------------------------

-- addhook
function hc.main.add_hook(name, func, prio)
    if prio == nil then
        prio = 0
    end

    if hc.main.hooks[name] == nil then
    -- Use CS2D's addhook
        hc.main.add_real_hook(name, func, prio)
    else
        local entry = { name = func, prio = prio }
        for i,hk in ipairs(hc.main.hooks[name]) do
            if hk.prio >= prio then
                table.insert(hc.main.hooks[name], i, entry)
                return
            end
        end
        table.insert(hc.main.hooks[name], entry)
    end
end

-- freehook
function hc.main.free_hook(name, func)
    if hc.main.hooks[name] == nil then
    -- Use CS2D's freehook
        hc.main.free_real_hook(name, func)
    else
        for i,hk in ipairs(hc.main.hooks[name]) do
            if hk.name == func then
                table.remove(i)
                return
            end
        end
        print("Error: Hook not found: " .. func)
    end
end

--[[
-- image
function hc.main.image(path, x, y, mode)
    local id = hc.main.cs2d_image(path, x, y, mode)
    hc.main.images[id] = true
    return id
end
]]

--[[
-- freeimage
function hc.main.free_image(id)
    if hc.main.images[id] then
	hc.main.images[id] = nil
    else
	print("Error: Image not found: "..id)
    end
    hc.main.cs2d_freeimage(id)
end
]]


------------------------------------------------------------------------------
-- Internal functions
------------------------------------------------------------------------------

function hc.main.add_proxy_hook(hook, func)
    hc.main.hooks[hook] = {}
    if func then
        hc.main.add_real_hook(hook, func)
    end
end

function hc.main.call_function(name, ...)
    local ok, result = pcall(hc.main.get_function(name), unpack(arg))

    if ok then
        return result
    else
        print("Error: " .. result)
    end
end

function hc.main.get_function(name)
    if hc.main.functions[name] == nil then
        assert(loadstring("hc.main.get_function_func = " .. name))()
        if hc.main.get_function_func == nil then
            print("Error: Undefined function '" .. name .. "'!")
            hc.main.functions[name] = function() end
        else
            hc.main.functions[name] = hc.main.get_function_func
        end
    end
    return hc.main.functions[name]
end

function hc.main.add_real_hook(name, func, prio)
    if hc.main.real_hooks[name] == nil then
        hc.main.real_hooks[name] = {}
    end
    table.insert(hc.main.real_hooks[name], func)

    if prio == nil then
        prio = 0
    end
    hc.main.cs2d_addhook(name, func, prio)
end

function hc.main.free_real_hook(name, func, prio)
    local id = hc.find_in_table(hc.main.real_hooks[name], func)
    if id > 0 then
        table.remove(hc.main.real_hooks[name], id)
    else
        print("Error: Hook not found: " .. func)
    end
end

-- Calls all hooks.
-- Aborts if a hook returns a value other than nil, "" or 0, unless returns_value is set.
-- If it is, all hooks will be called, but only the value from the first hook
-- that returned something will be returned.
function hc.main.call_hook(name, returns_value, ...)
    local result = nil

    if hc.main.hooks[name] then
        for _,entry in ipairs(hc.main.hooks[name]) do
            local ret = hc.main.call_function(entry.name, unpack(arg))

            if not (ret == nil or ret == "" or ret == 0) then
                if returns_value then
                    if result == nil then
                        result = ret
                    end
                else
                    return ret
                end
            end
        end
    end
    return result
end

function hc.main.call_acc_hook(name, acc, ...)
    if hc.main.hooks[name] then
        for _,entry in ipairs(hc.main.hooks[name]) do
            acc = hc.main.call_function(entry.name, acc, unpack(arg))
        end
    end
    return acc
end

function hc.main.init_player(p, reason)
--local old_player = hc.players[p]
    hc.players[p] = {}
    hc.main.call_hook("init_player", false, p, reason)
end

function hc.main.init_players(reason)
    for i=1,hc.SLOTS do
        if player(i, "exists") then
            hc.main.init_player(i, reason)
        else
            hc.players[i] = nil
        end
    end
end


------------------------------------------------------------------------------
-- Proxy hooks
------------------------------------------------------------------------------

function hc.main.join_proxy_hook(...)
    return hc.main.call_hook("join", false, unpack(arg))
end

function hc.main.team_proxy_hook(...)
    return hc.main.call_hook("team", false, unpack(arg))
end

function hc.main.spawn_proxy_hook(...)
    return hc.main.call_hook("spawn", true, unpack(arg))
end

function hc.main.die_proxy_hook(...)
    return hc.main.call_hook("die", true, unpack(arg))
end

function hc.main.build_proxy_hook(...)
    return hc.main.call_hook("build", false, unpack(arg))
end

function hc.main.flagcapture_proxy_hook(...)
    return hc.main.call_hook("flagcapture", false, unpack(arg))
end

function hc.main.dominate_proxy_hook(...)
    return hc.main.call_hook("dominate", false, unpack(arg))
end

function hc.main.bombplant_proxy_hook(...)
    return hc.main.call_hook("bombplant", false, unpack(arg))
end

function hc.main.bombdefuse_proxy_hook(...)
    return hc.main.call_hook("bombdefuse", false, unpack(arg))
end

function hc.main.bombexplode_proxy_hook(...)
    return hc.main.call_hook("bombexplode", false, unpack(arg))
end

function hc.main.say_proxy_hook(...)
    return hc.main.call_hook("say", false, unpack(arg))
end

function hc.main.sayteam_proxy_hook(...)
    return hc.main.call_hook("sayteam", false, unpack(arg))
end

function hc.main.radio_proxy_hook(...)
    return hc.main.call_hook("radio", false, unpack(arg))
end

function hc.main.endround_proxy_hook(...)
    return hc.main.call_hook("endround", false, unpack(arg))
end

function hc.main.serveraction_proxy_hook(...)
    return hc.main.call_hook("serveraction", false, unpack(arg))
end

function hc.main.name_proxy_hook(...)
    return hc.main.call_hook("name", false, unpack(arg))
end

function hc.main.objectdamage_proxy_hook(...)
    return hc.main.call_hook("objectdamage", false, unpack(arg))
end

function hc.main.post_join_proxy_hook(p)
    hc.main.call_hook("post_join", false, tonumber(p))
end


------------------------------------------------------------------------------
-- Hooks
------------------------------------------------------------------------------

function hc.main.menu_hook(p, title, button)
    if button == 0 then
    -- Cancel button pressed
        return
    end

    if hc.players[p].main.menu_table ~= nil then
        local id = hc.players[p].main.menu_table[button]
        hc.players[p].main.menu_table = nil
        if id == 0 then
        -- Show the next menu
            hc.show_menu(p, title, nil, hc.players[p].main.menu_command)
        else
            local item = hc.players[p].main.id_table[id]
            hc.players[p].main.menu_command(p, id, item)
        end
    end
end

--[[
function hc.main.endround_hook(mode)
    -- All images are freed at round end
    hc.main.images = {}
end
]]

function hc.main.init_player_hook(p, reason)
    hc.players[p].main = {}
    hc.players[p].main.usgn = tostring(player(p, "usgn"))
    hc.players[p].main.steam = player(p, "steamid")
end

function hc.main.pre_join_hook(p)
    hc.info(p, "Welcome, " .. player(p, "name") .. "!")
    if hc.is_moderator(p) then
        if hc.MODERATOR_WELCOME_MSG then
            hc.info(p, hc.MODERATOR_WELCOME_MSG)
        end
    elseif hc.is_vip(p) then
        if hc.VIP_WELCOME_MSG then
            hc.info(p, hc.VIP_WELCOME_MSG)
        end
    else
        if hc.USER_WELCOME_MSG then
            hc.info(p, hc.USER_WELCOME_MSG)
        end
    end
    if hc.COMMON_WELCOME_MSG then
        hc.info(p, hc.COMMON_WELCOME_MSG)
    end

    hc.main.init_player(p, hc.PLAYER_JOIN)
end

function hc.main.post_join_hook(p)
    timer(500, "hc.main.post_join_proxy_hook", tostring(p))
end

function hc.main.team_hook(p)
-- Bots don't join, so need to handle them separately
    if hc.players[p] == nil and player(p, "bot") then
        hc.main.call_hook("join", false, p)
    --hc.main.call_hook("team", false, p, player(p, "team"), 0)
    end
end

--[[
function hc.main.pre_leave_hook(p, reason)
    hc.players[p].main.leaving = true
end
]]

function hc.main.post_leave_hook(p, reason)
    if hc.players[p] ~= nil then
        hc.players[p].main.leaving = true
        hc.main.call_hook("delete_player", false, p, reason)
        hc.players[p] = nil
    end
end

function hc.main.spawn_hook(p)
    hc.players[p].main.real_kill = nil
    hc.players[p].main.real_death = nil
end

function hc.main.minute_hook()
    hc.event(hc.PERIODIC_MSG)
end

--function hc.main.remove_hook(mode)
--end
