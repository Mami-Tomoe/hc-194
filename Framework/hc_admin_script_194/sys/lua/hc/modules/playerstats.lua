------------------------------------------------------------------------------
-- Module API
-------------------------------------------------------------------------------

hc.playerstats.TOP_FILE = hc.STATS_DIR_PATH .. "/top.hct"


function hc.playerstats.init()
    hc.add_menu_command("Show to Me", hc.playerstats.show_stats_to_me_command, hc.SHOW_STATS_TO_ME_LEVEL, hc.COMMAND_MENU_KEY, { category = "Statistics" })
    hc.add_menu_command("Show to All", hc.playerstats.show_stats_to_all_command, hc.SHOW_STATS_TO_ALL_LEVEL, hc.COMMAND_MENU_KEY, { category = "Statistics" })
    hc.add_menu_command("Reset", hc.playerstats.reset_command, hc.RESET_STATS_LEVEL, hc.COMMAND_MENU_KEY, { category = "Statistics" })
    hc.add_menu_command("Top " .. hc.STATS_TOP_NUMBER, hc.playerstats.top_command, hc.TOP_STATS_LEVEL, hc.COMMAND_MENU_KEY, { category = "Statistics" })
    hc.add_menu_command("Number of Buildings", hc.playerstats.nbr_of_buildings_command, hc.NUMBER_OF_BUILDINGS_LEVEL, hc.COMMAND_MENU_KEY, { category = "Statistics", condition = function(p) return tonumber(game("sv_gamemode")) == hc.CONSTRUCTION end })

    hc.playerstats.read_top()

    addhook("init_player", "hc.playerstats.init_player_hook")
    addhook("delete_player", "hc.playerstats.delete_player_hook")
    addhook("name", "hc.playerstats.name_hook", 9999)
    addhook("mapchange", "hc.playerstats.mapchange_hook")
    addhook("die", "hc.playerstats.die_hook", -99999)
    addhook("flagcapture", "hc.playerstats.flagcapture_hook")
    addhook("dominate", "hc.playerstats.dominate_hook")
    addhook("bombplant", "hc.playerstats.bombplant_hook")
    addhook("bombexplode", "hc.playerstats.bombexplode_hook")
    addhook("bombdefuse", "hc.playerstats.bombdefuse_hook")
    addhook("hostagerescue", "hc.playerstats.hostagerescue_hook")
end


-------------------------------------------------------------------------------
-- Hooks
-------------------------------------------------------------------------------

function hc.playerstats.init_player_hook(p, reason)
    hc.players[p].playerstats = hc.playerstats.get_empty_stats();
    hc.players[p].playerstats.next_lvl = 1
    hc.players[p].playerstats.saved = hc.playerstats.read_stats(p)

    hc.playerstats.update_name(p, player(p, "name"))
end

function hc.playerstats.delete_player_hook(p, reason)
    hc.playerstats.save_stats(p)
end

function hc.playerstats.name_hook(p, oldname, newname)
    hc.playerstats.update_name(p, newname)
end

function hc.playerstats.mapchange_hook(newmap)
    for i=1,hc.SLOTS do
        if hc.player_exists(i) then
            hc.playerstats.save_stats(i)
        end
    end
    hc.playerstats.save_top()
end

function hc.playerstats.die_hook(victim, killer, weapon, x, y)
    if killer > 0 and hc.player_exists(killer) and
            killer ~= victim and hc.is_real_kill(killer) then
        if player(killer, "team") == player(victim, "team") then
            local ps = hc.players[killer].playerstats
            ps.team_kills = ps.team_kills + 1
            ps.score = ps.score + hc.TEAM_KILL_SCORE
        else
            local stats = hc.players[killer].playerstats
            stats.kills = stats.kills + 1
            stats.score = stats.score + hc.KILL_SCORE

            local kpd = hc.playerstats.get_kpd(stats.kills, stats.deaths)

            if hc.players[killer] == nil then
            -- Bot
                return
            end

            local next_lvl = stats.next_lvl
            local next_kpd = hc.KPD_LEVELS[next_lvl]

            if kpd >= next_kpd then
                hc.event(player(killer, "name") .. " Reached " .. next_kpd .. " KpD!@C")
                stats.next_lvl = next_lvl + 1
            end
        end
        hc.playerstats.update_top(killer)
    end
    if hc.player_exists(victim) and hc.is_real_death(victim) then
        local ps = hc.players[victim].playerstats
        ps.deaths = ps.deaths + 1
        ps.score = ps.score + hc.DEATH_SCORE
        hc.playerstats.update_top(victim)
    end
end

function hc.playerstats.flagcapture_hook(p, team, x, y)
    hc.info("Flag captured by " .. player(p, "name") .. "!@C")

    local ps = hc.players[p].playerstats
    ps.captures = hc.players[p].playerstats.captures + 1
    ps.score = ps.score + hc.CAPTURE_SCORE
    hc.playerstats.update_top(p)
end

function hc.playerstats.dominate_hook(p, team, x, y)
    local ps = hc.players[p].playerstats
    ps.dominations = ps.dominations + 1
    ps.score = ps.score + hc.DOMINATION_SCORE
    hc.playerstats.update_top(p)
end

function hc.playerstats.bombplant_hook(p, x, y)
    local ps = hc.players[p].playerstats
    ps.plants = ps.plants + 1
    ps.score = ps.score + hc.PLANT_SCORE
    hc.playerstats.update_top(p)
end

function hc.playerstats.bombexplode_hook(p, x, y)
    local ps = hc.players[p].playerstats
    ps.detonations = ps.detonations + 1
    ps.score = ps.score + hc.DETONATION_SCORE
    hc.playerstats.update_top(p)
end

function hc.playerstats.bombdefuse_hook(p)
    local ps = hc.players[p].playerstats
    ps.defusals = ps.defusals + 1
    ps.score = ps.score + hc.DEFUSAL_SCORE
    hc.playerstats.update_top(p)
end

function hc.playerstats.hostagerescue_hook(p, x, y)
    local ps = hc.players[p].playerstats
    ps.rescues = ps.rescues + 1
    ps.score = ps.score + hc.RESCUE_SCORE
    hc.playerstats.update_top(p)
end


-------------------------------------------------------------------------------
-- Menu commands
-------------------------------------------------------------------------------

function hc.playerstats.show_stats_to_me_command(p)
    hc.event(p, hc.playerstats.get_stats(p))
end

function hc.playerstats.show_stats_to_all_command(p)
    hc.event(hc.playerstats.get_stats(p))
end

function hc.playerstats.get_stats(p)
    local login = hc.get_login(p)
    local stats = {}

    local current = hc.players[p].playerstats
    local current_time = (os.time() - current.join) / 60

    local cs = hc.playerstats.get_stats_row(p,
        current.score, current.kills,
        current.deaths, current.team_kills,
        current.captures, current.dominations,
        current.plants, current.detonations,
        current.defusals, current.rescues,
        current_time)

    if login ~= "0" then
        if hc.playerstats.login[login] ~= nil then
            table.insert(stats, player(p, "name") .. ":  Rank: " .. hc.playerstats.login[login].position .. "  Current/Total Stats:")
        else
            table.insert(stats, player(p, "name") .. ":  Current/Total Stats:")
        end

        table.insert(stats, cs)

        local saved = hc.players[p].playerstats.saved
        local ts = hc.playerstats.get_stats_row(p,
            current.score + saved.score,
            current.kills + saved.kills,
            current.deaths + saved.deaths,
            current.team_kills + saved.team_kills,
            current.captures + saved.captures,
            current.dominations + saved.dominations,
            current.plants + saved.plants,
            current.detonations + saved.detonations,
            current.defusals + saved.defusals,
            current.rescues + saved.rescues,
            current_time + saved.time)
        table.insert(stats, ts)
    else
        table.insert(stats, player(p, "name") .. ":  Current Stats:")
        table.insert(stats, cs)
    end
    return stats
end

function hc.playerstats.get_stats_row(p, score, kills, deaths, team_kills,
captures, dominations, plants,
detonations, defusals, rescues, time)
    local kpd = math.floor(hc.playerstats.get_kpd(kills, deaths) * 100 + 0.5) / 100

    local stats = "S: " .. score ..
            ", K: " .. kills ..
            ", D: " .. deaths ..
            ", KpD: " .. kpd ..
            ", TK: " .. team_kills

    if map("mission_ctfflags") > 0 then
        stats = stats .. ", Cap: " .. captures
    end
    if map("mission_dompoints") > 0 then
        stats = stats .. ", Dom: " .. dominations
    end
    if map("mission_bombspots") > 0 then
        stats = stats .. ", Pla: " .. plants ..
                ", Det: " .. detonations ..
                ", Def: " .. defusals
    end
    if map("mission_hostages") > 0 then
        stats = stats .. ", Resc: " .. rescues
    end
    if time > (24 * 60) then
        stats = stats .. ", Time: " .. string.format("%d d %d:%02d", math.floor(time / (24 * 60)),
            math.floor((time % (24 * 60)) / 60),
            (time % 60))
    else
        stats = stats .. ", Time: " .. string.format("%d:%02d", math.floor(time / 60), (time % 60))
    end
    return stats
end

function hc.playerstats.reset_command(p)
    local entries = {
        { title = "Yes: Reset my stats!", value = true, id = p },
        { title = "No!", value = false, id = p }
    }
    hc.show_menu(p, "Reset Stats?", entries, hc.playerstats.reset_cb)
end

function hc.playerstats.reset_cb(p, _, item)
    if item.value then
        hc.players[p].playerstats = hc.playerstats.get_empty_stats();
        hc.players[p].playerstats.next_lvl = 1
        hc.players[p].playerstats.saved = hc.playerstats.get_empty_stats();

        local login = hc.get_login(p)

        if hc.playerstats.login[login] ~= nil then
        -- Move players up on the top list
            for pos=hc.playerstats.login[login].position,#hc.playerstats.top - 1 do
                hc.playerstats.top[pos] = hc.playerstats.top[pos + 1]
                hc.playerstats.top[pos].position = pos
            end
            hc.playerstats.login[login] = nil
            hc.playerstats.top[#hc.playerstats.top] = nil
        end
        hc.event(p, "Your statistics have been reset.")
    else
        hc.event(p, "Your statistics were not reset.")
    end
end

function hc.playerstats.top_command(p)
    local line = string.rep("=", 30)
    local message = {}

    for i,stats in ipairs(hc.playerstats.top) do
        if i > hc.STATS_TOP_NUMBER then
            break;
        end
        local n
        if i > 9 then
            n = i
        else
            n = "  " .. i
        end
        table.insert(message, n .. ". " .. stats.score .. "  " .. stats.name)
    end
    hc.open_editor(p, message, "Top Players",
        {
            {
                title = "Close",
                func = function(p, message, current_line)
                    hc.close_editor(p)
                end
            }
        },
        true)
end

function hc.playerstats.nbr_of_buildings_command(p)
    local objects = {}

    for _,id in ipairs(object(0, "table")) do
        if object(id, "player") == p then
            local type = object(id, "type")

            if objects[type] == nil then
                objects[type] = 1
            else
                objects[type] = objects[type] + 1
            end
        end
    end
    hc.print(objects)
    if not next(objects) then
        hc.info(p, "You have no buildings.")
    else
        hc.info(p, "Number of buildings that belong to you:")
        for type,amount in pairs(objects) do
            hc.info(p, hc.get_agreed_string(amount, hc.BUILDING_NAMES[type]))
        end
    end
end


-------------------------------------------------------------------------------
-- Internal functions
-------------------------------------------------------------------------------

function hc.playerstats.update_name(p, name)
    local login = hc.get_login(p)
    if hc.playerstats.login[login] ~= nil then
        hc.playerstats.login[login].name = name
    end
end

function hc.playerstats.update_top(p)
    local login = hc.get_login(p)

    if login ~= "0" then
        local score = hc.players[p].playerstats.score + hc.players[p].playerstats.saved.score
        local old_pos
        local stats

        if hc.playerstats.login[login] ~= nil then
            stats = hc.playerstats.login[login]
            old_pos = stats.position
            stats.score = score
        elseif #hc.playerstats.top < hc.STATS_TOP_NUMBER or score > hc.playerstats.top[#hc.playerstats.top].score then
        -- New player on the top list!
            old_pos = #hc.playerstats.top + 1
            stats = { login = login, position = old_pos, score = score, name = player(p, "name") }
            hc.playerstats.top[old_pos] = stats
            hc.playerstats.login[login] = stats
        else
        -- Not on the top list.
            return
        end
        if old_pos > 1 then
        -- Maybe move closer to the top?
            if hc.playerstats.move_top_player(stats, score, old_pos, 1, -1, function(s1, s2) return s1 < s2 end) then
                return
            end
        end
        if old_pos < #hc.playerstats.top then
        -- Maybe move closer to the bottom?
            if hc.playerstats.move_top_player(stats, score, old_pos, #hc.playerstats.top, 1, function(s1, s2) return s1 > s2 end) then
                return
            end
        end
    end
end

function hc.playerstats.move_top_player(stats, score, old_pos, last_pos, direction, comp)
    for pos=old_pos,last_pos - direction,direction do
        if comp(hc.playerstats.top[pos + direction].score, score) then
            hc.playerstats.top[pos] = hc.playerstats.top[pos + direction]
            hc.playerstats.top[pos].position = pos
        elseif pos ~= old_pos then
        -- Found the new spot
            hc.playerstats.top[pos] = stats
            hc.playerstats.top[pos].position = pos
            return true
        else
        -- No change
            return false
        end
    end
    hc.playerstats.top[last_pos] = stats
    hc.playerstats.top[last_pos].position = last_pos
    return true
end

function hc.playerstats.read_top()
    local t = hc.read_file(hc.playerstats.TOP_FILE) --, 4)

    hc.playerstats.top = {}
    hc.playerstats.login = {}

    for _,row in ipairs(t) do
        local stats = {
            login = row[1],
            position = tonumber(row[2]),
            score = tonumber(row[3]),
            name = row[4]
        }

        hc.playerstats.top[stats.position] = stats
        hc.playerstats.login[stats.login] = stats
    end
end

function hc.playerstats.save_top()
    local t = {}

    for i=1,hc.STATS_TOP_NUMBER do
        local entry = hc.playerstats.top[i]
        if entry == nil then
            break
        end
        t[i] = { entry.login, entry.position, entry.score, entry.name }
    end
    hc.write_file(hc.playerstats.TOP_FILE, t)
end

function hc.playerstats.get_kpd(kills, deaths)
    if deaths == 0 then
        deaths = 1
    end

    return kills / deaths
end

function hc.playerstats.get_filename(login)
    return hc.STATS_DIR_PATH .. "/" .. login .. ".hcs"
end

function hc.playerstats.read_stats(p)
    local login = hc.get_login(p)

    if login ~= "0" then
        local t = hc.read_file(hc.playerstats.get_filename(hc.get_login(p))) --, 9)

        if #t >= 1 then
            local row = t[1]
            local stats = {
                kills = tonumber(row[1]),
                deaths = tonumber(row[2]),
                team_kills = tonumber(row[3]),
                captures = tonumber(row[4]),
                dominations = tonumber(row[5]),
                plants = tonumber(row[6]),
                detonations = tonumber(row[7]),
                defusals = tonumber(row[8]),
                rescues = tonumber(row[9])
            }
            if #row >= 10 then
                stats.time = tonumber(row[10])
            else
                stats.time = 0
            end
            stats.score = stats.kills * hc.KILL_SCORE +
                    stats.deaths * hc.DEATH_SCORE +
                    stats.team_kills * hc.TEAM_KILL_SCORE +
                    stats.captures * hc.CAPTURE_SCORE +
                    stats.dominations * hc.DOMINATION_SCORE +
                    stats.plants * hc.PLANT_SCORE +
                    stats.detonations * hc.DETONATION_SCORE +
                    stats.defusals * hc.DEFUSAL_SCORE +
                    stats.rescues * hc.RESCUE_SCORE
            return stats
        else
            return hc.playerstats.get_empty_stats()
        end
    else
        return hc.playerstats.get_empty_stats()
    end
end

function hc.playerstats.save_stats(p)
    local login = hc.get_login(p)

    if login ~= "0" then
        local saved = hc.players[p].playerstats.saved
        local current = hc.players[p].playerstats

        local t = {
            {
                saved.kills + current.kills,
                saved.deaths + current.deaths,
                saved.team_kills + current.team_kills,
                saved.captures + current.captures,
                saved.dominations + current.dominations,
                saved.plants + current.plants,
                saved.detonations + current.detonations,
                saved.defusals + current.defusals,
                saved.rescues + current.rescues,
                saved.time + (os.time() - current.join) / 60
            }
        }

        hc.write_file(hc.playerstats.get_filename(login, t), t)
    end
end

function hc.playerstats.get_empty_stats()
    return {
        score = 0,
        kills = 0,
        deaths = 0,
        team_kills = 0,
        captures = 0,
        dominations = 0,
        plants = 0,
        detonations = 0,
        defusals = 0,
        rescues = 0,
        time = 0,
        join = os.time()
    }
end
