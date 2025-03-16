-------------------------------------------------------------------------------
-- Module API
-------------------------------------------------------------------------------

function hc.util.init()
    hc.util.init_censored_words_table()
end


------------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------------

function hc.table_slice(t, start_index, end_index)
    local slice = {}
    for i=start_index,end_index do
        slice[i - start_index + 1] = t[i]
    end
    return slice
end

function hc.shallow_copy(object)
    if type(object) == "table" then
        local copy = {}

        for id,obj in pairs(object) do
            copy[id] = obj
        end
        return copy
    else
        return object
    end
end

function hc.deep_copy(object)
    if type(object) == "table" then
        local copy = {}

        for id,obj in pairs(object) do
            copy[id] = hc.deep_copy(obj)
        end
        return copy
    else
        return object
    end
end

function hc.strip_end(text, pattern, len)
    while text:match(pattern) do
        text = text:sub(1, text:len() - len)
    end
    return text
end

function hc.msgs(msgs, prefix, postfix)
    if type(msgs) ~= "table" then
        msgs = { msgs }
    end
    for _,m in ipairs(msgs) do
        if prefix then
            m = prefix .. m
        end
        if postfix then
            m = m .. postfix
        end
        msg(m)
    end
end

function hc.msgs2(p, msgs, prefix, postfix)
    if type(msgs) ~= "table" then
        msgs = { msgs }
    end
    for _,m in ipairs(msgs) do
        if prefix then
            m = prefix .. m
        end
        if postfix then
            m = m .. postfix
        end
        msg2(p, m)
    end
end

function hc.cmd_error(p, cmd, msg)
    hc.error(p, hc.CMD_MARKER .. cmd .. ": " .. msg)
end

function hc.error(p_or_msg, msg)
    if msg == nil then
        hc.msgs(p_or_msg, hc.RED .. "Error: ")
    else
        hc.msgs2(p_or_msg, msg, hc.RED .. "Error: ")
    end
end

function hc.info(p_or_msg, msg)
    if msg == nil then
        hc.msgs(p_or_msg, hc.WHITE)
    else
        hc.msgs2(p_or_msg, msg, hc.WHITE)
    end
end

function hc.event(p_or_msg, msg)
    if msg == nil then
        hc.msgs(p_or_msg)
    else
        hc.msgs2(p_or_msg, msg)
    end
end

function hc.get_player_id(name_or_login)
    if type(name_or_login) == "string" then
        return hc.util.get_player_id(name_or_login, "name")
    elseif tonumber(name_or_login) ~= nil then
        local usgn, steam = hc.util.get_player_id(name_or_login, "usgn"), hc.util.get_player_id(name_or_login, "steam")

		return (usgn == "0" and steam) or usgn
    end
    return nil
end

function hc.player_exists(p)
    return hc.players[p] ~= nil and not hc.players[p].main.leaving
end

function hc.check_exists(id)
    if hc.player_exists(id) then
        return true
    end
    print("Error: Player " .. id .. " does not exist.")
    return false
end

function hc.exec(p, command)
    parse(command)
    hc.log(p, command)
end

function hc.log(p, command)
    print(hc.get_usgn(p) .. ": " .. command)
end

------------------------------------------------------------------------------
-- Returns a table of {id, player name}.
--
-- options:
-- min_lvl	= user miniumum level
-- max_lvl	= user maximum level
-- no_id	- don't show the player's id (slot)
-- only_login	- only add players that have a login
-- no_team	- don't show the player's team
-- no_anonymous	- omit players with nick "Player [0-9]*"
-- title_func   - function for composing the title
------------------------------------------------------------------------------
function hc.get_players(options)
    if options == nil then
        options = {}
    end

    local t = {}

    for j=1,hc.SLOTS do
        if hc.player_exists(j) then
            local name = hc.get_name(j)

            if (not options.min_lvl or hc.get_level(j) >= options.min_lvl) and
                    (not options.max_lvl or hc.get_level(j) <= options.max_lvl) and
                    (not options.only_login or hc.get_login(j) ~= "0") and
                    (not options.no_anonymous or not (name:match("^" .. hc.ANONYMOUS .. "$")
                            or name:match("^" .. hc.ANONYMOUS .. " %d+$"))) then
                local title
                if options.title_func ~= nil then
                    title = options.title_func(j)
                else
                    title = name:gsub("|", "!")

                    if not (options.no_id and options.no_team) then
                        title = title .. "|"
                        if not options.no_team then
                            local team = player(j, "team")
                            if team == hc.T then
                                title = title .. "T"
                            elseif team == hc.CT then
                                title = title .. "CT"
                            else -- Spectator
                                title = title .. "S"
                            end
                        end
                        if not options.no_id then
                            title = title .. " " .. j
                        end
                    end
                end
                table.insert(t, { title = title, id = j })
            end
        end
    end
    return t
end

function hc.get_player_values(p)
    local pv = {
        weapons = playerweapons(p),
        money = player(p, "money"),
        x = player(p, "x"),
        y = player(p, "y"),
        deaths = player(p, "deaths"),
        health = player(p, "health"),
        nightvision = player(p, "nightvision"),
        armor = player(p, "armor"),
        weapon = player(p, "weapontype")
    }
    return pv
end

function hc.set_player_values(p, values, set_health_and_pos)
    local weapons = ""
    for _,weapon in pairs(values.weapons) do
        weapons = weapons .. weapon .. ","
    end
    if values.nightvision then
        weapons = weapons .. " " .. hc.NIGHT_VISION
    end
    parse("setmoney " .. p .. " " .. values.money)
    parse("setarmor " .. p .. " " .. values.armor)
    parse("setdeaths " .. p .. " " .. values.deaths)
    parse("setweapon " .. p .. " " .. values.weapon)
    if set_health_and_pos then
        parse("sethealth " .. p .. " " .. values.health)
        parse("setpos " .. p .. " " .. values.x .. " " .. values.y)
    end
    return weapons
end

function hc.find_in_table(t, value)
    for id,v in pairs(t) do
        if (v == value) then
            return id
        end
    end
    return 0
end

function hc.get_agreed_string(value, noun)
    if value == 1 then
        return value .. " " .. noun
    else
        return value .. " " .. noun .. "s"
    end
end

function hc.rename_as(p, name)
    parse("setname " .. p .. " \"" .. name .. "\"")
end

function hc.read_file(name)
    local f, err = io.open(name)

    if f == nil then
        print("Error: " .. err)
        return {}
    end
    f:close()

    local t = {}
    local i = 1

    for line in io.lines(name) do
        local k
        local m = 0
        local n
        local row = {}

        row = hc.from_csv(line)
        if row ~= nil then
            t[i] = row
            i = i + 1
        else
            print("Error: File " .. name .. ": faulty line: " .. line)
        end
    end
    print("Read " .. #t .. " entries from " .. name .. ".")

    return t
end

function hc.write_file(name, t, append)
    local s = ""
    for _,row in ipairs(t) do
        s = s .. hc.to_csv(row) .. "\n"
    end

    local mode

    if append then
        mode = "a+"
    else
        mode = "w"
    end

    local f, err = io.open(name, mode)

    if f == nil then
        print("Error: " .. err)
        return
    end
    f:write(s)
    f:close()
    print("Saved " .. #t .. " entries to " .. name .. ".")
end

function hc.censor_text(text)
    return text:gsub("%a+", hc.util.censor_word)
end

-- Convert from CSV string to table
function hc.from_csv(s)
    s = s .. ',' -- ending comma

    local t = {}
    local fieldstart = 1

    repeat
    -- next field is quoted? (starts with `"'?)
        if string.find(s, '^"', fieldstart) then
            local a, c
            local i = fieldstart

            repeat
            -- find closing quote
                a, i, c = string.find(s, '"("?)', i + 1)
            until c ~= '"' -- quote not followed by quote?
            if not i then
                return nil
            end

            local f = string.sub(s, fieldstart + 1, i - 1)

            table.insert(t, (string.gsub(f, '""', '"')))
            fieldstart = string.find(s, ',', i) + 1
        else -- unquoted; find next comma
            local nexti = string.find(s, ',', fieldstart)

            table.insert(t, string.sub(s, fieldstart, nexti - 1))
            fieldstart = nexti + 1
        end
    until fieldstart > string.len(s)
    return t
end

-- Convert from table to CSV string
function hc.to_csv(tt)
    local s = ""

    for _,p in ipairs(tt) do
        s = s .. "," .. hc.util.escape_csv(p)
    end

    -- remove first comma
    return string.sub(s, 2)
end


------------------------------------------------------------------------------
-- Debug functions
------------------------------------------------------------------------------

function hc.print(...)
    local v = ""
    for _,value in ipairs(arg) do
        v = v .. hc.util.get_printable_value(value) .. "\t"
    end
    print(v)
end


-------------------------------------------------------------------------------
-- Internal functions
-------------------------------------------------------------------------------

function hc.util.get_player_id(value, attribute)
    for j=1,hc.SLOTS do
        if hc.player_exists(j) and value == player(j, attribute) then
            return j
        end
    end
end

function hc.util.censor_word(w)
    local word = hc.util.censored_words[w:lower()]
    if word then
        return word
    end
    return w
end

function hc.util.init_censored_words_table()
    local t = {}
    for i,word in ipairs(hc.CENSORED_WORDS) do
        local length = word:len()
        t[word] = word:sub(1, 1) .. string.rep("*", length - 2) .. word:sub(length, length)
    end
    hc.util.censored_words = t
end

function hc.util.get_printable_value(value)
    if type(value) == "string" then
        return "\"" .. value .. "\""
    elseif type(value) == "number" then
        return tostring(value)
    elseif type(value) == "nil" then
        return "<nil>"
    elseif type(value) == "boolean" then
        if value then
            return "true"
        else
            return "false"
        end
    elseif type(value) == "table" then
        return hc.util.get_table_as_string(value)
    elseif type(value) == "function" then
        return "<function>"
    else
        return "<unknown>"
    end
end

function hc.util.get_table_as_string(table)
    local msg = ""
    for key,value in pairs(table) do
        if msg ~= "" then
            msg = msg .. ", "
        end
        msg = msg .. hc.util.get_printable_value(key) .. "=" .. hc.util.get_printable_value(value)
    end
    return "{" .. msg .. "}"
end

-- Used to escape "'s by toCSV
function hc.util.escape_csv(s)
    if string.find(s, '[,"]') then
        s = '"' .. string.gsub(s, '"', '""') .. '"'
    end
    return s
end
