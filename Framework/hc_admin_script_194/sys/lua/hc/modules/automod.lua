-------------------------------------------------------------------------------
-- Module API
-------------------------------------------------------------------------------

hc.automod.MUTE_DURATION = 1

function hc.automod.init()
    hc.automod.banned_weapons = {}
    hc.automod.exits = {}

    hc.automod.init_entrance_kill_table()

    addhook("init_player", "hc.automod.init_player_hook")
    addhook("join", "hc.automod.join_hook")
    addhook("delete_player", "hc.automod.delete_player_hook")
    addhook("name", "hc.automod.name_hook", -99999)
    addhook("say", "hc.automod.check_spammer", -999999)
    addhook("sayteam", "hc.automod.check_spammer", -999999)
    addhook("say", "hc.automod.censor", 99999)
    addhook("sayteam", "hc.automod.censor_team", 99999)
    addhook("kill", "hc.automod.kill_hook", -999999)
    addhook("die", "hc.automod.die_hook", -99999)
    addhook("spawn", "hc.automod.spawn_hook", -99999)
    addhook("build", "hc.automod.build_hook")
    addhook("vote", "hc.automod.vote_hook")
    addhook("flagtake", "hc.automod.flagtake_hook")
    addhook("minute", "hc.automod.minute_hook")
end


-------------------------------------------------------------------------------
-- Hooks
-------------------------------------------------------------------------------

function hc.automod.init_player_hook(p, reason)
    hc.players[p].auto_mod = {}
end

function hc.automod.join_hook(p)
    local name = player(p, "name")

    if not hc.is_vip(p) then
        for _,pattern in pairs(hc.CENSORED_NAMES) do
            if name:match(pattern) then
                hc.rename_as(p, hc.ANONYMOUS)
                hc.info(p, "Your name was inappropriate and has therefore been changed.")
                return
            end
        end
    end
end

function hc.automod.kill_hook(killer, victim, weapon, x, y)
    if hc.automod.banned_weapons[weapon] then
        local xt = math.floor(x / hc.TILE_SIZE)
        local yt = math.floor(y / hc.TILE_SIZE)

        if entity(xt, yt, "exists") then
            if entity(xt, yt, "type") == hc.FUNC_TELEPORT then
            -- Kill the entrance killer
                hc.automod.punish(killer, victim)
                return
            end
        end

        local exit = hc.automod.exits[hc.automod.get_index(xt, yt)]
        if exit and exit.team ~= player(killer, "team") and
                object(exit.id, "exists") and
                object(exit.id, "type") == hc.TELEPORTER_EXIT then
            hc.automod.punish(killer, victim)
        end
    end
end

function hc.automod.die_hook(victim, killer, weapon, x, y)
    if hc.players[victim].auto_mod.aek then
    -- Don't drop anything
        return 1
    end
end

function hc.automod.spawn_hook(p)
    local aek = hc.players[p].auto_mod.aek
    if aek ~= nil then
        local weapons = hc.set_player_values(p, aek, true)
        hc.players[p].auto_mod.aek = nil
        return weapons
    end
end

function hc.automod.censor(p, t)
    -- Censor the message
    local new_string = hc.censor_text(t)

    if new_string == t then
    -- Nothing to censor
        return 0
    end
    if player(p, "team") ~= hc.SPEC and
            (player(p, "health") > 0 or
                    tonumber(game("sv_gamemode")) ~= hc.NORMAL) then
        hc.event(player(p, "name") .. ": " .. new_string)
        if hc.chat then
            hc.chat.show_emoticon(p, "cursing")
        end
    else
    -- Don't print the censored string - the message was not intended for
    -- everyone
        hc.event(p, "*CENSORED*")
    end
    if player(p, "team") ~= hc.SPEC and player(p, "health") > 0 then
        parse("slap " .. p)
    end
    return 1
end

function hc.automod.censor_team(p, t)
    -- Censor the message
    local new_string = hc.censor_text(t)

    if new_string == t then
    -- Nothing to censor
        return 0
    end
    -- Don't print the censored string - the message was not intended for
    -- everyone
    hc.event(p, "*CENSORED*")
    if player(p, "team") ~= hc.SPEC and player(p, "health") > 0 then
        parse("slap " .. p)
    end
    return 1
end

function hc.automod.check_spammer(p)
    if hc.is_vip(p) then
        return 0
    end
    if hc.players[p].auto_mod.spammer then
        return 1
    end
    local now = os.time()
    if os.difftime(now, hc.players[p].auto_mod.last_say) == 0 then
        hc.players[p].auto_mod.spammer = true
        hc.event(player(p, "name") .. " is spamming and has therefore been muted for " .. hc.automod.MUTE_DURATION .. " minute(s).")
        timer(hc.automod.MUTE_DURATION * 60000, "hc.automod.timer_cb", tostring(p))
        return 1
    else
        hc.players[p].auto_mod.last_say = now
    end
    return 0
end

function hc.automod.build_hook(p, type, x, y, mode, objectid)
    if type == hc.TELEPORTER_EXIT then
        hc.automod.exits[hc.automod.get_index(x, y)] = { id = objectid, team = player(p, "team") }
    end
end

function hc.automod.delete_player_hook(p, reason)
    if hc.players[p].auto_mod.spammer then
        freetimer("hc.automod.timer_cb", tostring(p))
    end
end

function hc.automod.name_hook(p, oldname, newname)
    if not hc.is_vip(p) then
        for _,pattern in pairs(hc.CENSORED_NAMES) do
            if newname:match(pattern) then
                hc.info(p, "Your new name is inappropriate.")
                return 1
            end
        end
    end
end

function hc.automod.vote_hook(id, mode, name)
-- Kick players that vote to kick a moderator
    if mode == hc.KICK and not hc.is_moderator(id) then
        local playerid = tonumber(name)
        if playerid == nil then
            playerid = hc.get_player_id(name)
        end
        if playerid ~= nil and hc.is_moderator(playerid) then
            local name = player(id, "name")
            parse("kick " .. id)
            hc.event(name .. " has been kicked for voting to kick a moderator.")
        else
            timer(500, "hc.automod.reason")
        end
    end
end

function hc.automod.flagtake_hook(p, team, x, y)
    local flag_holders = hc.automod.get_flag_holders()

    if #flag_holders == 0 then
        hc.info(p, "Go win now!")
    end
end

function hc.automod.minute_hook()
    local flag_holders = hc.automod.get_flag_holders()

    if #flag_holders == 1 then
        hc.info(flag_holders[1], "Go win now!")
    end
end


-------------------------------------------------------------------------------
-- Timer callback
-------------------------------------------------------------------------------

function hc.automod.timer_cb(id)
    local p = tonumber(id)
    hc.players[p].auto_mod.spammer = nil
    hc.event(p, "You are no longer muted.")
end


-------------------------------------------------------------------------------
-- Internal functions
-------------------------------------------------------------------------------

function hc.automod.get_flag_holders()
    local t = {}
    for i=1,hc.SLOTS do
        if hc.player_exists(i) and player(i, "flag") then
            table.insert(t, i)
        end
    end
    return t
end

function hc.automod.get_index(x, y)
    return x + hc.MAP_MAX_WIDTH * y
end

function hc.automod.punish(killer, victim)
    hc.set_no_real_kill(killer)
    hc.set_no_real_death(victim)

    -- Kill the entrance killer.
    parse("killplayer " .. killer)

    -- Now adjust the score so that the kill doesn't count
    local score = player(killer, "score")
    parse("setscore " .. killer .. " " .. (score - 1))

    -- Finally respawn the victim right where he was killed.
    local aek = hc.get_player_values(victim)
    aek.health = 100
    aek.armor = 100
    aek.deaths = aek.deaths - 1
    hc.players[victim].auto_mod.aek = aek

    hc.event(player(killer, "name") .. " has been punished for entrance killing.")
end

function hc.automod.init_entrance_kill_table()
    local t = {}

    for _,weapon in ipairs(hc.ENTRANCE_KILL_WEAPONS) do
        t[weapon] = true
    end
    hc.automod.banned_weapons = t
end


-------------------------------------------------------------------------------
-- Timer callback
-------------------------------------------------------------------------------

function hc.automod.reason()
    hc.info("Why kick?")
end
