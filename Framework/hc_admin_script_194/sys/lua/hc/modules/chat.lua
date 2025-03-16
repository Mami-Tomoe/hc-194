-------------------------------------------------------------------------------
-- Module API
-------------------------------------------------------------------------------

hc.chat.SAY_TAGS = {
    [hc.VIP] = "VIP",
    [hc.MODERATOR1] = "Mod",
    [hc.MODERATOR2] = "Mod",
    [hc.ADMINISTRATOR] = "Adm"
}

hc.chat.COLOURS = {
    Normal = "nil",
    Strong = {
        [hc.T] = hc.STRONG_RED,
        [hc.CT] = hc.STRONG_BLUE
    },
    Black = hc.BLACK,
    Orange = hc.ORANGE,
    Lime = hc.LIME,
    Green = hc.GREEN,
    ["Olive Green"] = hc.OLIVE_GREEN,
    ["Army Green"] = hc.ARMY_GREEN,
    Cyan = hc.CYAN,
    Purple = hc.PURPLE,
    Pink = hc.PINK,
    Brown = hc.BROWN
}

hc.chat.TAG_PROP_NAME = "say_tag"
hc.chat.COLOUR_PROP_NAME = "tag_colour"

hc.chat.ON = "1"
hc.chat.OFF = "0"

hc.chat.EMOTICONS = {
    ["^[:=8][-^o]?[)%]3>]$"] = "smiling", -- :)
    ["^%^[_]?%^$"] = "smiling", -- ^_^
    ["^[:=8][-^o]?[D]$"] = "smiling_big", -- :D
    ["^[:=8][-^o]?[(%[]$"] = "frowning", -- :(
    ["^[;][-^o]?[)%]D]$"] = "winking", -- ;)
    ["^[xX][-^o]?[D]+$"] = "laughing", -- xD
    ["^[lL1][oO��0]+[lL1]+[sSzZ]*%??$"] = "laughing", -- lol
    ["^[hH][aAeEoO��][hH][aAeEoO��]$"] = "laughing", -- hehe
    ["^[rR][oO��0]+[fF][lL1]+$"] = "laughing", -- rofl
    ["^[:=8xX][-^o]?[pPbq]$"] = "cheeky", -- :P
    ["^[:=8xX]['][-^o]?%($"] = "crying", -- :'(
    ["^[;][-]?%($"] = "crying", -- ;(
    ["^D[-^o]?[:=8xX]$"] = "crying", -- Dx
    ["^T[_.-]?T$"] = "crying", -- T_T
    ["^[:=8][-^o]?[oO0]$"] = "surprised", -- :O
    ["^[oO0][_.-]?[oO0]$"] = "surprised", -- O_o
    ["^[oO0][mM][gG]$"] = "surprised", -- omg
    ["^[:=8][-^o]?[/\\]$"] = "skeptical", -- :/
    ["^[:=8][-^o]?[sS]$"] = "uneasy", -- :S
    ["^>[:=8;][-^o]?[)%]D]$"] = "evil", -- >:D
    ["^>[_.-]<$"] = "angry", -- >_<
    ["^>[:=8;][-^o]?[(%[]$"] = "angry", -- >:(
    ["^<3$"] = "heart" -- <3
}



hc.chat.EMOTICON_LINGER_TIME = 3
hc.chat.EMOTICON_FADE_IN_STEP = 0.30
hc.chat.EMOTICON_FADE_OUT_STEP = 0.20
hc.chat.EMOTICON_OPACITY = 0.60
hc.chat.EMOTICON_PATH = "gfx/hc/emoticons/"


function hc.chat.init()
    hc.add_menu_command("Say Colour", hc.chat.colour_command, hc.SAY_COLOUR_LEVEL, hc.COMMAND_MENU_KEY, { category = "Config" })
    hc.add_menu_command("Say Tag", hc.chat.tag_command, hc.SAY_TAG_LEVEL, hc.COMMAND_MENU_KEY, { category = "Config" })

    addhook("init_player", "hc.chat.init_player_hook")
    addhook("delete_player", "hc.chat.delete_player_hook")
    addhook("say", "hc.chat.say_hook", 999999)
    addhook("ms100", "hc.chat.ms100_hook")

    hc.chat.smiling_players = {}
end


-------------------------------------------------------------------------------
-- Hooks
-------------------------------------------------------------------------------

function hc.chat.init_player_hook(p, reason)
    hc.players[p].chat = {}
end

function hc.chat.delete_player_hook(p, reason)
    local chat = hc.players[p].chat

    if chat.smiley_time ~= nil then
        freeimage(chat.emoticon)
        freeimage(chat.speechbubble)
        for i,id in ipairs(hc.chat.smiling_players) do
            if id == p then
                table.remove(hc.chat.smiling_players, i)
                break
            end
        end
    end
end

function hc.chat.ms100_hook()
    local still_smiling_players = {}

    for i,p in ipairs(hc.chat.smiling_players) do
        local chat = hc.players[p].chat
        local time = os.difftime(os.time(), chat.smiley_time)

        if time < hc.chat.EMOTICON_LINGER_TIME and chat.alpha < hc.chat.EMOTICON_OPACITY then
            chat.alpha = chat.alpha + hc.chat.EMOTICON_FADE_IN_STEP
            imagealpha(chat.speechbubble, chat.alpha)
            imagealpha(chat.emoticon, chat.alpha)
            table.insert(still_smiling_players, p)
        elseif time > hc.chat.EMOTICON_LINGER_TIME then
            chat.alpha = chat.alpha - hc.chat.EMOTICON_FADE_OUT_STEP
            if chat.alpha <= 0 then
                freeimage(chat.emoticon)
                freeimage(chat.speechbubble)
                chat.smiley_time = nil
                chat.emoticon = nil
                chat.speechbubble = nil
            else
                imagealpha(chat.speechbubble, chat.alpha)
                imagealpha(chat.emoticon, chat.alpha)
                table.insert(still_smiling_players, p)
            end
        else
            table.insert(still_smiling_players, p)
        end
    end
    hc.chat.smiling_players = still_smiling_players
end

function hc.chat.say_hook(p, text)
    if text == "rank" then
        return 0
    end

    local team = player(p, "team")

    if team == hc.SPEC or tonumber(game("sv_gamemode")) == hc.NORMAL and
            player(p, "health") == 0 then
    -- Spectating players and dead players in normal mode can't talk
    -- to living players.
        return 0
    end

    hc.chat.check_for_smileys(p, text)

    if hc.is_vip(p) then
        local colour_name = hc.get_player_property(p, hc.chat.COLOUR_PROP_NAME)
        local colour

        if colour_name then
            colour = hc.chat.COLOURS[colour_name]
            if colour and type(colour) == "table" then
                colour = colour[team]
            elseif not colour or colour == "nil" then
                return 0
            end
        else
            return 0
        end

        local title = colour .. player(p, "name")

        local show_tag = hc.get_player_property(p, hc.chat.TAG_PROP_NAME)

        if show_tag == nil or show_tag == hc.chat.ON then
            local tag = hc.chat.SAY_TAGS[hc.get_level(p)]
            title = title .. " /" .. tag .. "/"
        end

        text = hc.strip_end(text, "[©@]C", 2)

        if player(p, "health") == 0 then
            msg(title .. " *DEAD*: " .. text)
        else
            msg(title .. ": " .. text)
        end
        return 1
    end
    return 0
end


------------------------------------------------------------------------------
-- Internal functions
------------------------------------------------------------------------------

function hc.chat.check_for_smileys(p, message)
    for word in string.gmatch(message, "[^%s]+") do
        for smiley,emoticon in pairs(hc.chat.EMOTICONS) do
            if word:match(smiley) then
                hc.chat.show_emoticon(p, emoticon)
                return
            end
        end
    end
end

function hc.chat.show_emoticon(p, emoticon)
    local chat = hc.players[p].chat

    if chat.emoticon ~= nil then
        freeimage(chat.emoticon)
    else
        table.insert(hc.chat.smiling_players, p)
        chat.speechbubble = image(hc.chat.EMOTICON_PATH .. "speechbubble.png", 0, 0, 200 + p)
        chat.alpha = hc.chat.EMOTICON_FADE_IN_STEP
    end
    chat.smiley_time = os.time()
    chat.emoticon = image(hc.chat.EMOTICON_PATH .. emoticon .. ".png",
        0, 0, 200 + p)
    imagealpha(chat.speechbubble, chat.alpha)
    imagealpha(chat.emoticon, chat.alpha)
end

------------------------------------------------------------------------------
-- Command callbacks
------------------------------------------------------------------------------

function hc.chat.tag_command(p)
    local menu = {
        { title = "On", value = hc.chat.ON },
        { title = "Off", value = hc.chat.OFF }
    }
    hc.show_menu(p, "Say Tag", menu,
        function(p, id, item)
            hc.set_player_property(p, hc.chat.TAG_PROP_NAME, item.value)
        end)
end

function hc.chat.colour_command(p)
    local menu = {}
    local i = 1
    for colour in pairs(hc.chat.COLOURS) do
        menu[i] = colour
        i = i + 1
    end
    table.sort(menu)
    hc.show_menu(p, "Say Colour", menu,
        function(p, id, item)
            hc.set_player_property(p, hc.chat.COLOUR_PROP_NAME, item)
        end)
end
