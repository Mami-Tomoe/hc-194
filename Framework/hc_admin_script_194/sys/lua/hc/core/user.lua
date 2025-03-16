------------------------------------------------------------------------------
-- Internal constants and variables
------------------------------------------------------------------------------

hc.user.USERS_FILENAME = "users"
hc.user.USERS_EXTENSION = ".hcu"
hc.user.USERS_FILE = hc.CONFIG_DIR_PATH .. "/" .. hc.user.USERS_FILENAME .. hc.user.USERS_EXTENSION
hc.user.USERS_BACKUP_PATH = hc.CONFIG_DIR_PATH .. "/backup/"

hc.user.USER_LEVELS = {
    { title = "Unregistered", level = hc.USER },
    "",
    { title = "VIP", level = hc.VIP },
    "",
    { title = "Moderator 1", level = hc.MODERATOR1 },
    { title = "Moderator 2", level = hc.MODERATOR2 },
    "",
    { title = "Administrator", level = hc.ADMINISTRATOR }
}

hc.user.COLOURS = {
    [hc.SPEC] = "",
    [hc.T] = hc.T_RED,
    [hc.CT] = hc.CT_BLUE
}

hc.user.SHORT_NAMES = {
    [hc.USER] = "User",
    [hc.VIP] = "VIP",
    [hc.MODERATOR1] = "Mod1",
    [hc.MODERATOR2] = "Mod2",
    [hc.ADMINISTRATOR] = "Adm"
}

hc.user.NAME_TO_LEVEL = {
    VIP = hc.VIP,
    Mod1 = hc.MODERATOR1,
    Mod2 = hc.MODERATOR2,
    Adm = hc.ADMINISTRATOR
}


-------------------------------------------------------------------------------
-- Module API
-------------------------------------------------------------------------------

function hc.user.init()
    hc.users = {}

    hc.add_menu_command("Make VIP", hc.user.make_vip_command, hc.MAKE_VIP_LEVEL, hc.ADMIN_MENU_KEY, { category = "Administrate" })
    hc.add_menu_command("Remove VIP", hc.user.remove_vip_command, hc.REMOVE_VIP_LEVEL, hc.ADMIN_MENU_KEY, { category = "Administrate" })
    hc.add_menu_command("Register User", hc.user.register_user_command, hc.REGISTER_USER_LEVEL, hc.ADMIN_MENU_KEY, { category = "Administrate" })
    hc.add_menu_command("Manage Users", hc.user.manage_users_command, hc.MANAGE_USERS_LEVEL, hc.ADMIN_MENU_KEY, { category = "Administrate" })
    hc.add_menu_command("Reload Users", hc.user.reload_users_command, hc.RELOAD_USERS_LEVEL, hc.ADMIN_MENU_KEY, { category = "Administrate" })
    hc.add_menu_command("Online Users", hc.user.online_users_command, hc.ONLINE_USERS_LEVEL, hc.COMMAND_MENU_KEY)

    hc.add_say_command("editname", hc.user.edit_name_command, hc.EDIT_NAME_LEVEL, "<new name>",
        "Change the name of a registered user.")

    addhook("init_player", "hc.user.init_player_hook", -9999)
    addhook("startround", "hc.user.startround_hook", -9999)
    addhook("delete_player", "hc.user.delete_player_hook", 9999)
    addhook("mapchange", "hc.user.mapchange_hook", 99999)

    hc.init_users()
end


------------------------------------------------------------------------------
-- API
------------------------------------------------------------------------------

function hc.init_users()
    local t = {}
    local users = hc.read_file(hc.user.USERS_FILE)
    local c

    for _,row in pairs(users) do
        local login = row[1]
        local level = hc.user.NAME_TO_LEVEL[row[2]]
        local name = row[3]
        t[login] = { name = name, level = level }
    end

    hc.users = t
end

function hc.save_users()
    os.rename(hc.user.USERS_FILE,
        hc.user.USERS_BACKUP_PATH .. hc.user.USERS_FILENAME .. os.date("!%Y%m%d%H%M%S") .. hc.user.USERS_EXTENSION)

    local t = {}
    for id,player in pairs(hc.users) do
        table.insert(t, { id, hc.get_level_short_name(player.level), player.name })
    end
    hc.write_file(hc.user.USERS_FILE, t)
end

function hc.get_level(p)
    if game("sv_lan") == "1" and p == 1 then -- LAN mode (debug)
        return hc.ADMINISTRATOR
    end
    local user = hc.users[hc.get_login(p)]
    if user then
        return user.level
    end
    return hc.USER
end

function hc.get_level_short_name(level)
    return hc.user.SHORT_NAMES[level]
end

function hc.is_vip(p)
    return hc.get_level(p) >= hc.VIP
end

function hc.is_moderator(p)
    return hc.get_level(p) >= hc.MODERATOR1
end

function hc.is_admin(p)
    return hc.get_level(p) >= hc.ADMINISTRATOR
end

function hc.set_player_property(p, property, value)
    hc.players[p].user.config[property] = value
    hc.players[p].user.config.modified = true
end

function hc.get_player_property(p, property)
    local config = hc.players[p].user.config
    if config then
        return hc.players[p].user.config[property]
    end
end

function hc.get_users(options)
    local t = {}

    for login,admin in pairs(hc.users) do
        if not options or ((not options.min_lvl or options.min_lvl <= admin.level)
                and (not options.max_lvl or admin.level <= options.max_lvl)) then
            table.insert(t, {
                title = hc.fix_name(admin.name:gsub("|", "!")) .. " |" .. login .. "   " .. hc.get_level_short_name(admin.level),
                login = login
            })
        end
    end
    table.sort(t, function(u1, u2) return u1.title < u2.title end)
    return t
end


------------------------------------------------------------------------------
-- Internal functions
------------------------------------------------------------------------------

function hc.user.get_filename(login)
    return hc.CONFIG_DIR_PATH .. "/" .. login .. ".hcc"
end

function hc.user.read_config(p)
    local login = hc.get_login(p)
    local t = hc.read_file(hc.user.get_filename(login)) --, 2)
    local config = {}

    for _,row in ipairs(t) do
        config[row[1]] = row[2]
    end
    hc.players[p].user.config = config
end

function hc.user.write_config(p)
    local config = hc.players[p].user.config
    local t = {}
    local r = 1

    config.modified = nil
    for property,value in pairs(config) do
        t[r] = { property, value }
        r = r + 1
    end

    local login = hc.get_login(p)
    hc.write_file(hc.user.get_filename(login), t)
end

function hc.user.save_config(p)
    local config = hc.players[p].user.config

    if config and config.modified then
        hc.user.write_config(p)
    end
end


-------------------------------------------------------------------------------
-- Menu callbacks
-------------------------------------------------------------------------------

function hc.user.manage_users(p, _, item)
    local level = item.level

    hc.init_users() -- Reload the users file

    local user = hc.players[p].user.user
    local name = user.name
    local login = user.login

    if level >= hc.VIP then
        hc.users[login] = { name = name, level = level }
    else
        hc.users[login] = nil
    end
    hc.save_users()
    hc.event(p, name .. " is now " .. hc.get_level_short_name(level) .. ".")

    local id = hc.get_player_id(login)
    if id ~= nil then
        hc.event(id, "You are now " .. hc.get_level_short_name(level) .. ".")
    end
end

function hc.user.manage_users_cb(p, id, item)
    local login = item.login
    local user = hc.users[login]
    local name = user.name
    local level = user.level

    hc.players[p].user.user = { login = login, name = name, level = level }
    hc.show_menu(p, name .. " [" .. hc.get_level_short_name(level) .. "]",
        hc.user.USER_LEVELS, hc.user.manage_users)
end

function hc.user.make_vip(p, _, item)
    local id = item.id
    local name = player(id, "name")
    local login = hc.get_login(id)

    hc.init_users() -- Reload the users file
    hc.users[login] = { name = name, level = hc.VIP }
    hc.save_users()
    hc.event(p, name .. " is now VIP.")
    hc.event(id, "You are now VIP.")

    hc.main.call_hook("player_level", false, id, hc.USER, hc.VIP)
end

function hc.user.remove_vip(p, _, item)
    local login = item.login
    local user = hc.users[login]
    local name = user.name

    hc.init_users() -- Reload the users file
    hc.users[login] = nil
    hc.save_users()
    hc.event(p, name .. " is no longer VIP.")

    local id = hc.get_player_id(login)
    if id ~= nil then
        hc.event(id, "You are no longer VIP.")
    end
    hc.main.call_hook("player_level", false, id, hc.VIP, hc.USER)
end

function hc.user.register_user(p, _, item)
    local id = item.id
    local name = player(id, "name")
    local login = hc.get_login(id)

    hc.players[p].user.user = { login = login, name = name, level = hc.USER }
    hc.show_menu(p, name, hc.user.USER_LEVELS, hc.user.manage_users)
end

function hc.user.edit_name_cb(p, id, item)
    hc.init_users() -- Reload the users file

    if hc.users[item.login] then
        local oldname = hc.users[item.login].name

        hc.users[item.login].name = hc.players[p].user.edit_name
        hc.save_users()
        hc.event(p, oldname .. " renamed as " .. hc.players[p].user.edit_name .. ".")
    end
end


-------------------------------------------------------------------------------
-- Say commands
-------------------------------------------------------------------------------

function hc.user.edit_name_command(p, arg)
    hc.players[p].user.edit_name = arg
    local users
    if hc.is_admin(p) then
        users = hc.get_users()
    elseif hc.is_moderator(p) then
        users = hc.get_users({ max_lvl = hc.VIP })
    end
    hc.show_menu(p, "Edit Name", users, hc.user.edit_name_cb)
end


-------------------------------------------------------------------------------
-- Menu commands
-------------------------------------------------------------------------------

function hc.user.reload_users_command(p)
    hc.init_users()
    hc.event(p, "Users reloaded.")
end

function hc.user.manage_users_command(p)
    hc.show_menu(p, "Manage Users", hc.get_users(), hc.user.manage_users_cb)
end

function hc.user.make_vip_command(p)
    hc.show_menu(p, "Make VIP", hc.get_players({ max_lvl = hc.USER, only_login = true }), hc.user.make_vip)
end

function hc.user.remove_vip_command(p)
    hc.show_menu(p, "Remove VIP", hc.get_users({ min_lvl = hc.VIP, max_lvl = hc.VIP }), hc.user.remove_vip)
end

function hc.user.register_user_command(p)
    hc.show_menu(p, "Register User", hc.get_players({ max_lvl = hc.USER, only_login = true }), hc.user.register_user)
end

function hc.user.online_users_command(p)
    for i=1,hc.SLOTS do
        if hc.player_exists(i) then
            local user = hc.users[hc.get_login(i)]
            if user then
                msg2(p, hc.user.COLOURS[player(i, "team")] .. i .. ". " .. user.name ..
                        " (" .. player(i, "name") .. "), " .. hc.get_level_short_name(user.level))
            end
        end
    end
end


-------------------------------------------------------------------------------
-- Hooks
-------------------------------------------------------------------------------

function hc.user.init_player_hook(p)
    hc.players[p].user = {}
    if hc.is_vip(p) then
        hc.user.read_config(p)
    else
        hc.players[p].user.config = {}
    end
end

function hc.user.startround_hook(mode)
    hc.init_users()
end

function hc.user.mapchange_hook(newmap)
    for i=1,hc.SLOTS do
        if hc.player_exists(i) then
            hc.user.save_config(i)
        end
    end
end

function hc.user.delete_player_hook(p)
    hc.user.save_config(p)
end
