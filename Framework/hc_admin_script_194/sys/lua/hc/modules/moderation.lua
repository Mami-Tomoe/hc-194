-------------------------------------------------------------------------------
-- Module API
-------------------------------------------------------------------------------

hc.moderation.SPEEDS = {
    { title = "Slight|-10", value = -10 },
    { title = "Medium|-20", value = -20 },
    { title = "Immobilized|-100", value = -100 },
    "",
    { title = "Normal Speed|0", value = 0 }
}
hc.moderation.MUTE_DURATIONS = {
    { title = "1 Minute", value = 1 },
    { title = "2 Minutes", value = 2 },
    { title = "3 Minutes", value = 3 },
    { title = "4 Minutes", value = 4 },
    { title = "5 Minutes", value = 5 },
    "",
    { title = "Unmute", value = 0 }
}
hc.moderation.BUILDINGS = {
    { title = "Barricades", value = { hc.BARRICADE } },
    { title = "Barbed Wire", value = { hc.BARBED_WIRE } },
    { title = "Walls", value = { hc.WALL_I, hc.WALL_II, hc.WALL_III } },
    { title = "Turrets", value = { hc.TURRET, hc.DUAL_TURRET, hc.TRIPLE_TURRET } },
    { title = "Teleporter Entrances", value = { hc.TELEPORTER_ENTRANCE } },
    { title = "Teleporter Exits", value = { hc.TELEPORTER_EXIT } }
}

--hc.moderation.IMAGE		= "gfx/hc/admin.png"

function hc.moderation.init()
    hc.add_menu_command("Identify", hc.moderation.id_command, hc.IDENTIFY_LEVEL, hc.ADMIN_MENU_KEY, { category = "Check" })
    hc.add_menu_command("Supervise", hc.moderation.supervise_command, hc.SUPERVISE_LEVEL, hc.ADMIN_MENU_KEY, { category = "Check" })

    hc.add_menu_command("Slap", hc.moderation.slap_command, hc.SLAP_LEVEL, hc.ADMIN_MENU_KEY, { category = "Discipline" })
    hc.add_menu_command("Slow Down", hc.moderation.slow_down_command, hc.SLOW_DOWN_LEVEL, hc.ADMIN_MENU_KEY, { category = "Discipline" })
    hc.add_menu_command("Shake", hc.moderation.shake_command, hc.SHAKE_LEVEL, hc.ADMIN_MENU_KEY, { category = "Discipline" })
    hc.add_menu_command("Mute", hc.moderation.mute_command, hc.MUTE_LEVEL, hc.ADMIN_MENU_KEY, { category = "Discipline" })
    hc.add_menu_command("Censor Name", hc.moderation.rename_command, hc.RENAME_LEVEL, hc.ADMIN_MENU_KEY, { category = "Discipline" })
    hc.add_menu_command("Remove Buildings", hc.moderation.remove_buildings_command, hc.REMOVE_BUILDINGS_LEVEL, hc.ADMIN_MENU_KEY, { category = "Discipline" })
    hc.add_menu_command("Wall", hc.moderation.wall_command, hc.WALL_LEVEL, hc.ADMIN_MENU_KEY, { category = "Discipline" })

    hc.add_menu_command("Kick", hc.moderation.kick_command, hc.KICK_LEVEL, hc.ADMIN_MENU_KEY, { category = "Remove" })
    hc.add_menu_command("Ban IP/USGN/STEAM", hc.moderation.ban_command, hc.BAN_IP_USGN_STEAM_LEVEL, hc.ADMIN_MENU_KEY, { category = "Remove" })
    hc.add_menu_command("Ban Name", hc.moderation.ban_name_command, hc.BAN_NAME_LEVEL, hc.ADMIN_MENU_KEY, { category = "Remove" })

    hc.add_menu_command("Vote Kick", hc.moderation.vote_kick_command, hc.VOTE_KICK_LEVEL, hc.COMMAND_MENU_KEY)

    hc.add_say_command("rcon", hc.moderation.rcon_command, hc.RCON_LEVEL, "<command>", "Execute an rcon command.")

    addhook("say", "hc.moderation.check_muted", -999999)
    addhook("sayteam", "hc.moderation.check_muted", -999999)
    addhook("radio", "hc.moderation.check_muted", -999999)
    addhook("startround", "hc.moderation.startround_hook")
    addhook("endround", "hc.moderation.endround_hook")
    addhook("team", "hc.moderation.team_hook")
    addhook("delete_player", "hc.moderation.delete_player_hook")
    addhook("spawn", "hc.moderation.spawn_hook", -99999)
    addhook("init_player", "hc.moderation.init_player_hook")
    addhook("die", "hc.moderation.die_hook", -999999)
end


-------------------------------------------------------------------------------
-- Menu callbacks
-------------------------------------------------------------------------------

function hc.moderation.slow_down(p, id, speed)
    if hc.check_exists(id) then
        hc.exec(p, "speedmod " .. id .. " " .. speed)
    end
end

function hc.moderation.kill_if_flag_bearer(p)
    if player(p, "flag") then
        hc.exec(p, "killplayer " .. p)
    end
end

function hc.moderation.kick(p, _, item)
    local id = item.id

    if hc.check_exists(id) then
        hc.moderation.kill_if_flag_bearer(id)
        hc.exec(p, "kick " .. id)
    end
end

function hc.moderation.ban(p, _, item)
    local id = item.id

    if item.value and hc.check_exists(id) then
        hc.moderation.kill_if_flag_bearer(id)

        local usgn = hc.get_usgn(id)
        local steam = hc.get_steam(id)
		
        if usgn ~= "0" then
            hc.exec(p, "banusgn " .. usgn)
        elseif steam ~= "0" then
            hc.exec(p, "bansteam " .. steam)
		else
            local ip = player(id, "ip")
            hc.exec(p, "banip " .. ip)
        end
    end
end

function hc.moderation.maybe_ban(p, _, item)
    hc.moderation.really_ban(p, item.id, hc.moderation.ban)
end

function hc.moderation.ban_name(p, _, item)
    local id = item.id

    if item.value and hc.check_exists(id) then
        hc.moderation.kill_if_flag_bearer(id)

        local name = player(id, "name")
        hc.exec(p, "banname " .. name)
    end
end

function hc.moderation.maybe_ban_name(p, _, item)
    hc.moderation.really_ban(p, item.id, hc.moderation.ban_name)
end

function hc.moderation.id(p, _, item)
    local id = item.id
    local usgn = hc.get_usgn(id)
    local steam = hc.get_steam(id)
    local name = player(id, "name")
    local ip = player(id, "ip")
    local m = "#" .. id .. ": " .. name

    if p == id then
        msg2(p, m .. ", level: " .. hc.get_level_short_name(hc.get_level(id)) .. ", usgn: " .. usgn .. ", steam: " .. steam .. ", ip: " .. ip)
    elseif hc.is_vip(id) then
        local real_id = hc.users[hc.get_login(id)].name
        msg2(p, m .. ", level: " .. hc.get_level_short_name(hc.get_level(id)) .. ", id: " .. real_id)
    else
        msg2(p, m .. ", level: -, usgn: " .. usgn .. ", steam: " .. steam .. ", ip:" .. ip)
    end
end

function hc.moderation.slap(p, _, item)
    local id = item.id
    local team = player(id, "team")

    if (team == hc.T or team == hc.CT) and player(id, "health") > 0 then
    -- Can't slap spectating or dead players
        hc.exec(p, "slap " .. id)
    end
end

function hc.moderation.mute_cb(p, index)
    local id = hc.players[p].moderation.muting_id
    local name = player(id, "name")
    local duration = hc.moderation.MUTE_DURATIONS[index].value

    if duration == 0 then
        if hc.players[id].moderation.muted then
            freetimer("hc.moderation.timer_cb", tostring(id))
            hc.players[id].moderation.muted = nil
            hc.event(name .. " is no longer muted.")
        else
            hc.error(p, "Can't unmute " .. name .. " because he isn't muted.")
        end
    else
        if hc.players[id].moderation.muted then
        -- Player was already muted - remove the pending timer
            freetimer("hc.moderation.timer_cb", tostring(id))
        end

        hc.players[id].moderation.muted = duration
        hc.event(name .. " has been muted for " .. duration .. " minute(s).")
        hc.info(id, "You have been muted.")
        hc.log(p, "mute " .. id)
        timer(duration * 60000, "hc.moderation.timer_cb", tostring(id))
    end
end

function hc.moderation.rename(p, _, item)
    local id = item.id
    local names = {}

    hc.rename_as(id, hc.ANONYMOUS)
    hc.log(p, "setname " .. id .. " " .. hc.ANONYMOUS)
end

function hc.moderation.mute(p, _, item)
    local id = item.id

    hc.players[p].moderation.muting_id = id
    hc.show_menu(p, "Mute", hc.moderation.MUTE_DURATIONS, hc.moderation.mute_cb)
end

function hc.moderation.slow_down_cb2(p, index)
    local id = hc.players[p].moderation.slowing_down
    local name = player(id, "name")
    local speed = hc.moderation.SPEEDS[index].value

    if speed == 0 then
        hc.moderation.slow_down(p, id, 0)
        hc.event(name .. " is no longer slowed down.")
        hc.event(id, "You are no longer slowed down.")
        hc.players[id].moderation.slowed_down = nil
    else
        hc.moderation.slow_down(p, id, speed)
        hc.log(p, "slow_down " .. id)
        hc.event(name .. " has been slowed down (" .. speed .. ").")
        hc.info(id, "You have been slowed down.")
        hc.players[id].moderation.slowed_down = speed
    end
end

function hc.moderation.shake_cb(p, _, item)
    local id = item.id

    hc.event(player(id, "name") .. " is being shaken.")
    hc.exec(p, "shake " .. id .. " " .. (60 * 50))
end

function hc.moderation.remove_buildings_cb2(p, _, item)
    local buildings = item.value
    local id = hc.players[p].moderation.remove_building_player_id

    for _,oid in ipairs(object(0, "table")) do
        if object(oid, "player") == id then
            for _,type in pairs(buildings) do
                if type == object(oid, "type") then
                    parse("killobject " .. oid)
                    break
                end
            end
        end
    end
end

function hc.moderation.remove_buildings_cb(p, _, item)
    hc.players[p].moderation.remove_building_player_id = item.id
    hc.show_menu(p, "Remove Buildings", hc.moderation.BUILDINGS, hc.moderation.remove_buildings_cb2)
end

function hc.moderation.wall_cb(p, _, item)
    local id = item.id
    local x = player(id, "x") / hc.TILE_SIZE
    local y = player(id, "y") / hc.TILE_SIZE
    hc.exec(p, "spawnobject " .. hc.WALL_III .. " " .. x .. " " .. y .. " 0 0 0 0")
end

function hc.moderation.slow_down_cb(p, _, item)
    local id = item.id
    hc.players[p].moderation.slowing_down = id
    hc.show_menu(p, "Slow Down", hc.moderation.SPEEDS, hc.moderation.slow_down_cb2)
end

function hc.moderation.vote_kick_cb(p, _, item)
    local new_vote = item.id
    local old_vote = hc.players[p].moderation.kick_vote
    local now = os.time()

    if new_vote == old_vote then
    -- Voting for the same player again
        return
    end
    if old_vote ~= nil then
        if now - hc.players[p].moderation.kick_vote_time < hc.VOTE_KICK_COOLDOWN_TIME then
            hc.event(p, "You must wait " .. hc.VOTE_KICK_COOLDOWN_TIME .. " seconds before voting again.")
            return
        end
    end

    if hc.player_exists(new_vote) then
        local votes = hc.players[new_vote].moderation.kick_votes

        if votes == nil then
            votes = {}
        end

        hc.event(player(p, "name") .. " votes to kick " .. player(new_vote, "name") .. ".")

        if #votes + 1 >= hc.VOTE_KICK_LIMIT then
            hc.exec(p, "kick " .. new_vote)
        else
            table.insert(votes, p)
            hc.players[new_vote].moderation.kick_votes = votes
            if old_vote ~= nil then
            -- Remove the old vote
                local kick_votes = hc.players[old_vote].moderation.kick_votes

                for i,value in ipairs(kick_votes) do
                    if value == p then
                        table.remove(kick_votes, i)
                        break
                    end
                end
            end
            hc.players[p].moderation.kick_vote = new_vote
            hc.players[p].moderation.kick_vote_time = now
        end
    end
end


-------------------------------------------------------------------------------
-- Menu commands
-------------------------------------------------------------------------------

function hc.moderation.id_command(p)
    local options = { show_id = true }
    hc.show_menu(p, "Identify", hc.get_players(), hc.moderation.id)
end

function hc.moderation.kick_command(p)
    hc.show_menu(p, "Kick", hc.get_players({ max_lvl = hc.USER }), hc.moderation.kick)
end

function hc.moderation.ban_command(p)
    hc.show_menu(p, "Ban", hc.get_players({ max_lvl = hc.USER }), hc.moderation.maybe_ban)
end

function hc.moderation.ban_name_command(p)
    hc.show_menu(p, "Ban Name", hc.get_players({ max_lvl = hc.USER, no_anonymous = true }), hc.moderation.maybe_ban_name)
end

function hc.moderation.slap_command(p)
    hc.show_menu(p, "Slap", hc.get_players(), hc.moderation.slap)
end

function hc.moderation.rename_command(p)
    hc.show_menu(p, "Rename", hc.get_players({ max_lvl = hc.USER }), hc.moderation.rename)
end

function hc.moderation.mute_command(p)
    hc.show_menu(p, "Mute", hc.get_players({ max_lvl = hc.USER }), hc.moderation.mute)
end

function hc.moderation.shake_command(p)
    hc.show_menu(p, "Shake", hc.get_players({ max_lvl = hc.USER }), hc.moderation.shake_cb)
end

function hc.moderation.remove_buildings_command(p)
    hc.show_menu(p, "Remove Buildings", hc.get_players({ max_lvl = hc.USER }), hc.moderation.remove_buildings_cb)
end

function hc.moderation.wall_command(p)
    hc.show_menu(p, "Wall", hc.get_players(), hc.moderation.wall_cb)
end

function hc.moderation.slow_down_command(p)
    hc.show_menu(p, "Slow Down", hc.get_players({ max_lvl = hc.USER }), hc.moderation.slow_down_cb)
end

function hc.moderation.supervise_command(p)
    if player(p, "health") == 0 or player(p, "team") == hc.SPEC then
        hc.error(p, "You can't enter supervisor mode because you are either dead or spectating.")
        return
    end
    local sv = hc.get_player_values(p)
    hc.players[p].moderation.supervising = sv
    hc.log(p, "supervise")
    hc.set_no_real_death(p)
    parse("killplayer " .. p)
    hc.event(p, "You are now in supervisor mode.")
    hc.event(p, "Click left mouse button to return to the game.")
end

function hc.moderation.vote_kick_command(p)
    local players = hc.get_players({
        max_lvl = hc.USER,
        title_func = function(id)
            local title = player(id, "name")
            local votes = hc.players[id].moderation.kick_votes
            if votes == nil or #votes == 0 then
                return title
            else
                return title .. "|" .. #votes
            end
        end
    })
    hc.show_menu(p, "Vote Kick", players, hc.moderation.vote_kick_cb)
end


-------------------------------------------------------------------------------
-- Say commands
-------------------------------------------------------------------------------

function hc.moderation.rcon_command(p, arg)
    hc.exec(p, arg)
end


-------------------------------------------------------------------------------
-- Misc functions
-------------------------------------------------------------------------------

function hc.moderation.timer_cb(id)
    local p = tonumber(id)
    hc.players[p].moderation.muted = nil
    msg2(p, "You are no longer muted.")
end

function hc.moderation.really_ban(p, id, func)
    if hc.check_exists(id) then
        local name = player(id, "name"):gsub("|", "!")
        local entries = {
            { title = "Yes: Ban " .. name .. "!", value = true, id = id },
            { title = "No!", value = false, id = id }
        }
        hc.show_menu(p, "Really Ban?", entries, func)
    end
end


-------------------------------------------------------------------------------
-- Hooks
-------------------------------------------------------------------------------

function hc.moderation.check_muted(p)
    if hc.players[p].moderation.muted then
        hc.info(p, "You are muted for " .. hc.players[p].moderation.muted .. " minute(s).")
        return 1
    end
    return 0
end

function hc.moderation.startround_hook(mode)
    hc.moderation.round_ended = false
end

function hc.moderation.endround_hook(mode)
    hc.moderation.round_ended = true
end

function hc.moderation.team_hook(p, team, look)
    if hc.is_moderator(p) then
        if hc.players[p].moderation.supervising then
            hc.error(p, "You can't change team - you are supervising.")
            return 1
        end
    end
    return 0
end

function hc.moderation.delete_player_hook(p, reason)
    if hc.players[p].moderation.muted then
        freetimer("hc.moderation.timer_cb", tostring(p))
    end

    local vote = hc.players[p].moderation.kick_vote

    if vote ~= nil then
    -- User who has voted to kick someone is leaving.
    -- Remove his vote.
        local kick_votes = hc.players[vote].moderation.kick_votes
        for i,value in ipairs(kick_votes) do
            if value == p then
                table.remove(kick_votes, i)
                break
            end
        end
    end

    local kick_votes = hc.players[p].moderation.kick_votes

    if kick_votes ~= nil then
    -- User who someone has voted to kick is leaving.
    -- Remove the votes.
        for _,value in ipairs(kick_votes) do
            hc.players[value].moderation.kick_vote = nil
        end
    end
end

function hc.moderation.spawn_hook(p)
-- Slow down
    if hc.players[p].moderation.slowed_down then
        parse("speedmod " .. p .. " " .. hc.players[p].moderation.slowed_down)
    end

    -- Supervise
    local sv = hc.players[p].moderation.supervising
    if sv ~= nil then
        local weapons = hc.set_player_values(p, sv, not hc.moderation.round_ended)
        hc.players[p].moderation.supervising = nil
        msg2(p, "Leaving supervisor mode.")
        return weapons
    end
end

function hc.moderation.init_player_hook(p, reason)
    hc.players[p].moderation = {}
end

function hc.moderation.die_hook(victim, killer, weapon, x, y)
    if hc.players[victim].moderation.supervising then
        return 1
    end
    return 0
end
