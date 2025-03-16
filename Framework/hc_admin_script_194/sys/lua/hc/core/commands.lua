------------------------------------------------------------------------------
-- Module API
------------------------------------------------------------------------------

function hc.commands.init()
    hc.commands.say_commands = {}
    hc.commands.pattern_say_commands = {}
    hc.commands.menu_commands = {
        [hc.COMMAND_MENU_KEY] = {},
        [hc.ADMIN_MENU_KEY] = {}
    }


    hc.add_menu_command("About", hc.commands.about_command, hc.ABOUT_LEVEL, hc.COMMAND_MENU_KEY, { category = "Help" })
    hc.add_menu_command("List Say Commands", hc.commands.help_command, hc.LIST_SAY_COMMANDS, hc.COMMAND_MENU_KEY, { category = "Help" })

    addhook("init_player", "hc.commands.init_player_hook")
    addhook("say", "hc.commands.say_hook", -9999)
    addhook("serveraction", "hc.commands.serveraction_hook", -99999)
end


------------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------------

function hc.add_menu_command(title, func, level, key, options)
    local category
    local condition

    if options ~= nil then
        if options.category ~= nil then
            if type(options.category) ~= "table" then
                category = { options.category }
            else
                category = options.category
            end
        end
        condition = options.condition
    end
    table.insert(hc.commands.menu_commands[key],
        { func = func, level = level, title = title, category = category, condition = condition })
end

function hc.add_say_command(name, func, level, usage, help, optional_args, pattern)
    local command = { name = name, func = func, level = level, usage = usage, help = help, optional_args = optional_args, pattern = pattern }
    if pattern then
        table.insert(hc.commands.pattern_say_commands, command)
    else
        hc.commands.say_commands[name] = command
    end
end

function hc.usage(p, cmd)
    msg2(p, hc.WHITE .. hc.CMD_MARKER .. cmd .. " " .. hc.commands.say_commands[cmd].usage .. " - " .. hc.commands.say_commands[cmd].help)
end


------------------------------------------------------------------------------
-- Internal functions
------------------------------------------------------------------------------

function hc.commands.is_authorized(p, level)
    local player_level = hc.get_level(p)

    if type(level) == "table" then
        for _,l in ipairs(level) do
            if l == player_level then
                return true
            end
        end
        return false
    else
        return player_level >= level
    end
end

function hc.commands.check_authorized(p, command)
    if not hc.commands.is_authorized(p, command.level) then
        hc.cmd_error(p, command.name, "You are not authorized to execute this command.")
        return false
    else
        return true
    end
end

function hc.commands.eval_commands(p, t)
    local cmd = t:match("^%s*" .. hc.CMD_MARKER .. "([^%s]+)")
    if cmd then
        local command = hc.commands.say_commands[cmd]
        if command then
        -- Check authority
            if hc.commands.check_authorized(p, command) then
                arg = t:match("^%s*" .. hc.CMD_MARKER .. "[^%s]+%s+(.+)")
                if arg or command.optional_args then
                    command.func(p, arg)
                else
                    hc.usage(p, cmd)
                end
            end
            return 1
        else
            for _,command in ipairs(hc.commands.pattern_say_commands) do
                if cmd:match(command.pattern) == cmd then
                    if hc.commands.check_authorized(p, command) then
                        arg = t:match("^%s*" .. hc.CMD_MARKER .. "[^%s]+%s+(.+)")
                        if arg or command.optional_args then
                            command.func(p, cmd, arg)
                        else
                            hc.usage(p, cmd)
                        end
                    end
                    return 1
                end
            end
            hc.cmd_error(p, cmd, "Unknown command.")
            return 1
        end
    end
    return 0
end

function hc.commands.menu_sort(c1, c2)
    if not c1.level or not c2.level or c1.level == c2.level then
        return c1.title < c2.title
    else
        return c1.level < c2.level
    end
end

function hc.commands.display_command_menu_cb(p, id, item)
    if item.sub_menu then
        hc.commands.display_command_menu_level(p, item.commands, item.category, item.menu_level)
    else
        item.func(p, nil)
    end
end

function hc.commands.display_command_menu(p, key)
    local title

    if key == hc.COMMAND_MENU_KEY then
        title = "Command"
    elseif key == hc.ADMIN_MENU_KEY then
        title = "Admin"
    end
    hc.commands.display_command_menu_level(p, hc.commands.menu_commands[key], title, 1)
end

function hc.commands.display_command_menu_level(p, menu_commands, title, menu_level)
    local commands = {}
    local sub_menus = {}

    for _,options in ipairs(menu_commands) do
        if hc.commands.is_authorized(p, options.level) and
                (options.condition == nil or options.condition(p)) then
            local category = options.category

            if category ~= nil and #category >= menu_level then
            -- This command is contained in a sub menu
                if sub_menus[category[menu_level]] == nil then
                    local sub_menu = {
                        title = category[menu_level] .. "|>",
                        sub_menu = true,
                        category = category[menu_level],
                        menu_level = menu_level + 1,
                        commands = { options }
                    }
                    table.insert(commands, sub_menu)
                    sub_menus[category[menu_level]] = sub_menu
                else
                    table.insert(sub_menus[category[menu_level]].commands, options)
                end
            else
                local level
                if type(options.level) == "table" then
                    level = options.level[1]
                else
                    level = options.level
                end
                local cmd = {
                    title = options.title .. "|" .. hc.get_level_short_name(level),
                    level = level,
                    func = options.func
                }
                table.insert(commands, cmd)
            end
        end
    end
    table.sort(commands, hc.commands.menu_sort)
    hc.show_menu(p, title, commands, hc.commands.display_command_menu_cb)
end


-------------------------------------------------------------------------------
-- Menu commands
-------------------------------------------------------------------------------

function hc.commands.about_command(p)
    hc.info(p, "HC CS2D Admin Script " .. hc.VERSION)
    hc.info(p, "- by Häppy C@mper")
end

function hc.commands.help_command(p)
    local i = 1
    local cmds = {}

    for command,options in pairs(hc.commands.say_commands) do
        if hc.commands.is_authorized(p, options.level) then
            cmds[i] = hc.CMD_MARKER .. command .. " " .. options.usage .. " - " .. options.help
            i = i + 1
        end
    end
    for _,options in pairs(hc.commands.pattern_say_commands) do
        if hc.commands.is_authorized(p, options.level) then
            cmds[i] = hc.CMD_MARKER .. options.name .. " " .. options.usage .. " - " .. options.help
            i = i + 1
        end
    end
    table.sort(cmds)
    for _,cmd in ipairs(cmds) do
        msg2(p, hc.WHITE .. cmd)
    end
end


------------------------------------------------------------------------------
-- Hooks
------------------------------------------------------------------------------

function hc.commands.init_player_hook(p, reason)
    hc.players[p].commands = {}
end

function hc.commands.serveraction_hook(p, action)
--    local now = os.time()
--    if os.difftime(now, hc.players[p].main.last_action) == 0 then
-- Prevent hackers from crashing the server by pressing the function
-- key over and over again
--	return
--    else
--	hc.players[p].main.last_action = now
--    end
    if action == hc.COMMAND_MENU_KEY then
        hc.commands.display_command_menu(p, hc.COMMAND_MENU_KEY)
        return 1
    elseif action == hc.ADMIN_MENU_KEY then
        hc.commands.display_command_menu(p, hc.ADMIN_MENU_KEY)
        return 1
    end
end

function hc.commands.say_hook(p, t)
    return hc.commands.eval_commands(p, t)
end
