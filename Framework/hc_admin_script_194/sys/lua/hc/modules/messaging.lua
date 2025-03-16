------------------------------------------------------------------------------
-- Module API
------------------------------------------------------------------------------

function hc.messaging.init()
    hc.add_menu_command("Messages", hc.messaging.messages_command, hc.MESSAGES_LEVEL, hc.COMMAND_MENU_KEY)

    hc.add_say_command("vm", hc.messaging.vm_command, hc.VM_LEVEL, "[<message>]", "Send a message to all VIP's online.", true)
    hc.add_say_command("mm", hc.messaging.mm_command, hc.MM_LEVEL, "[<message>]", "Send a message to all moderators online.", true)
    hc.add_say_command("<id>[,<id>...]", hc.messaging.pm_command, hc.PM_LEVEL, "[<message>]", "Send a private message to a few specified players.", true, "[%d,]+")
    hc.add_say_command("om", hc.messaging.om_command, hc.OM_LEVEL, "[<message>]", "Send an offline message to a user.", true)
    hc.add_say_command("ombc", hc.messaging.ombc_command, hc.OMBC_LEVEL, "[<message>]", "Send an offline message to all or a group of users.", true)
    hc.add_say_command("bc", hc.messaging.bc_command, hc.BC_LEVEL, "[<message>]", "Send a broadcast message.", true)

    addhook("init_player", "hc.messaging.init_player_hook")
    addhook("team", "hc.messaging.team_hook")
end


------------------------------------------------------------------------------
-- Internal functions
------------------------------------------------------------------------------

function hc.messaging.send_pm(p, idstring, msg, cmd, tag, title)
    local ids = {}

    for id in string.gmatch(idstring, "%d+") do
        table.insert(ids, tonumber(id))
    end

    local cmd = "<id>[,<id>...]"

    if #ids > 0 then
        local error = false

        for _,i in ipairs(ids) do
            if i == p then
                hc.cmd_error(p, cmd, "You can't send a private message to yourself.")
                error = true
            elseif not hc.player_exists(i) then
                hc.cmd_error(p, cmd, "Player #" .. i .. " does not exist.")
                error = true
            end
        end
        if not error then
            hc.players[p].messaging.recipients = ids
            if msg ~= nil and msg ~= "" then
                hc.messaging.send_pm_cb(p, { msg })
            else
                local rec_string

                if #ids > 1 then
                    rec_string = hc.messaging.get_receiver_strings(ids, 10000, true)[1]
                else
                    rec_string = player(ids[1], "name")
                end
                hc.messaging.compose_message(p, hc.messaging.send_pm_cb, "Private Message to " .. rec_string)
            end
        end
    else
        hc.cmd_error(p, cmd, "Illegal/missing ID.")
    end
end

function hc.messaging.send_pm_cb(p, msg)
    local colour_rec = hc.LIGHT_GREY
    local colour_snd = hc.MEDIUM_GREY
    local ids = hc.players[p].messaging.recipients
    local tag = "PM"
    local sender_name = player(p, "name")

    local rec_prefix = colour_rec .. tag .. ": " .. p .. ". " .. sender_name

    -- Show to receiver.
    for _,id in ipairs(ids) do
        if #ids > 1 then
            local rec_list = {}

            for _,i in ipairs(ids) do
                if i ~= id then
                    table.insert(rec_list, i)
                end
            end
            local rec_string = hc.messaging.get_receiver_strings(rec_list, 60 - rec_prefix:len())

            hc.msgs2(id, rec_string, rec_prefix .. " -> ")
        end
        for _,line in ipairs(msg) do
            local text = hc.censor_text(line)

            msg2(id, rec_prefix .. ": " .. text)
        end
    end

    -- Show to sender.
    if #ids > 1 then
        local rec_string = hc.messaging.get_receiver_strings(ids, 60)

        hc.msgs2(p, rec_string, colour_snd .. tag .. ": -> ")

        for _,line in ipairs(msg) do
            local text = hc.censor_text(line)

            hc.msgs2(p, text, colour_snd .. tag .. ": ")
        end
    else
        local recip_name = player(ids[1], "name")
        for _,line in ipairs(msg) do
            local text = hc.censor_text(line)

            msg2(p, colour_snd .. tag .. ": -> " .. ids[1] .. ". " .. recip_name .. ": " .. text)
        end
    end
end

function hc.messaging.get_receiver_strings(receivers, width, ommit_names)
    local strings = {}
    local str = ""

    for _,id in ipairs(receivers) do
        if str:len() > width then
            table.insert(strings, str)
            str = ""
        end
        if str ~= "" then
            str = str .. ", "
        end
        str = str .. id
        if not ommit_names then
            str = str .. ". " .. player(id, "name")
        end
    end
    if str ~= "" then
        table.insert(strings, str)
    end
    return strings
end


function hc.messaging.send_mm(p, msg)
    for _,line in ipairs(msg) do
        local text = hc.censor_text(line)

        for i=1,hc.SLOTS do
            if hc.player_exists(i) and hc.is_moderator(i) and i ~= p then
                msg2(i, hc.LIGHT_GREY .. "MM: " .. p .. ". " .. player(p, "name") .. ": " .. text)
            end
        end
        msg2(p, hc.MEDIUM_GREY .. "MM: " .. text)
    end
end

function hc.messaging.send_vm(p, msg)
    for _,line in ipairs(msg) do
        local text = hc.censor_text(line)

        for i=1,hc.SLOTS do
            if hc.player_exists(i) and hc.is_vip(i) and not hc.is_moderator(i) and i ~= p then
                msg2(i, hc.LIGHT_GREY .. "VM: " .. p .. ". " .. player(p, "name") .. ": " .. text)
            end
        end
        msg2(p, hc.MEDIUM_GREY .. "VM: " .. text)
    end
end

function hc.messaging.get_messages_fn(login)
    return hc.MESSAGES_DIR_PATH .. "/" .. login .. ".hcm"
end

function hc.messaging.send_om(p, recipient, message)
    local filename = hc.messaging.get_messages_fn(recipient)
    local sender_login = hc.get_login(p)
    local t = { { sender_login, os.time(), unpack(message) } }

    hc.write_file(filename, t, true)

    local i = hc.get_player_id(recipient)
    if i ~= nil then
        hc.info(i, "You have received a new message from " .. hc.users[sender_login].name .. ".")
    end
end

function hc.messaging.compose_message(p, callback, title, message)
    hc.players[p].messaging.send_cb = callback

    hc.open_editor(p, message, "Composing " .. title,
        {
            "",
            { title = "Send Message", func = hc.messaging.send_cb },
            { title = "Print to Log", func = hc.messaging.print_om },
            { title = "Cancel Message", func = hc.messaging.cancel_cb }
        })
end

function hc.messaging.view_message(p, from, login, time, title, message)
    local header = "From: " .. from .. ", " .. os.date("%d %B %Y %X", time)
    local msg = { header, unpack(message) }

    hc.players[p].messaging.current_om = { from = from, login = login, time = time, header = header, message = message }

    hc.open_editor(p, msg, "Viewing " .. title,
        {
            { title = "Previous Message", func = hc.messaging.previous_om },
            { title = "Next Message", func = hc.messaging.next_om },
            "",
            { title = "Reply", func = hc.messaging.reply_om },
            { title = "Forward", func = hc.messaging.forward_om },
            { title = "Print to Log", func = hc.messaging.print_om },
            { title = "Delete", func = hc.messaging.delete_om },
            {
                title = "Back to Messages",
                func = function(p)
                    hc.close_editor(p)
                    hc.messaging.messages_command(p)
                end
            },
            {
                title = "Close Messages",
                func = function(p)
                    hc.close_editor(p)
                end
            }
        },
        true)
end

function hc.messaging.select_recipient_and_send_om(p, msg)
    hc.players[p].messaging.om = msg
    hc.show_menu(p, "Recipient", hc.get_users(),
        function(p, id, item)
            local name = hc.users[item.login].name
            local yes = 1
            local yes_new = 2
            local no_new = 3
            local no = 4
            local login = item.login

            hc.show_menu(p, "Send message to " .. name .. "?",
                {
                    { title = "Yes", value = yes },
                    { title = "Yes and to another recipient", value = yes_new },
                    { title = "No. Select a new recipient", value = no_new },
                    { title = "No. Scratch it.", value = no }
                },
                function(p, id, item)
                    if item.value == yes or item.value == yes_new then
                        hc.messaging.send_om(p, login, hc.players[p].messaging.om)
                        hc.event(p, "Message sent to " .. name .. ".")
                    end
                    if item.value == yes_new or item.value == no_new then
                        hc.messaging.select_recipient_and_send_om(p, msg)
                    end
                end)
        end)
end


-------------------------------------------------------------------------------
-- Menu callbacks
-------------------------------------------------------------------------------

function hc.messaging.send_cb(p, message, current_line)
    if #message > 0 then
        hc.close_editor(p)
        hc.players[p].messaging.send_cb(p, message)
    else
        hc.info(p, "Nothing to send!")
    end
end

function hc.messaging.cancel_cb(p, message, current_line)
    if #message > 0 then
        local entries = {
            { title = "Yes: Message will be lost!", value = true },
            { title = "No: Continue composing!", value = false }
        }
        hc.show_menu(p, "Cancel Composing?", entries,
            function(id, _, item)
                if item.value then
                    hc.close_editor(p)
                end
            end)
    else
        hc.close_editor(p)
    end
end

function hc.messaging.next_om(p)
    local om = hc.players[p].messaging.current_om

    local filename = hc.messaging.get_messages_fn(hc.get_login(p))
    local messages = hc.read_file(filename)

    for i=#messages,1,-1 do
        local row = messages[i]
        local from, login, time, message = hc.messaging.parse_message_item(row)

        if time < om.time then
            hc.close_editor(p)
            hc.messaging.view_message(p, from, login, time, "Offline Message", message)
            return
        end
    end
    hc.event(p, "No more messages.")
end

function hc.messaging.previous_om(p)
    local om = hc.players[p].messaging.current_om

    local filename = hc.messaging.get_messages_fn(hc.get_login(p))
    local messages = hc.read_file(filename)

    for i=1,#messages do
        local row = messages[i]
        local from, login, time, message = hc.messaging.parse_message_item(row)

        if time > om.time then
            hc.close_editor(p)
            hc.messaging.view_message(p, from, login, time, "Offline Message", message)
            return
        end
    end
    hc.event(p, "No more messages.")
end

function hc.messaging.print_om(p)
    local om = hc.players[p].messaging.current_om

    hc.event(p, om.header)
    for _,line in ipairs(om.message) do
        hc.event(p, line)
    end
end

function hc.messaging.reply_om(p)
    hc.close_editor(p)

    local om = hc.players[p].messaging.current_om
    local message = { "" }

    table.insert(message, "> " .. om.header)
    for _,line in ipairs(om.message) do
        table.insert(message, "> " .. line)
    end

    hc.messaging.compose_message(p, function(p, m, cl)
        hc.messaging.send_om(p, om.login, m)
        hc.messaging.view_message(p, om.from, om.login, om.time,
            "Offline Message", om.message)
    end, "OM Reply", message)
end

function hc.messaging.forward_om(p)
    hc.close_editor(p)

    local om = hc.players[p].messaging.current_om
    local message = { "" }

    table.insert(message, "> " .. om.header)
    for _,line in ipairs(om.message) do
        table.insert(message, "> " .. line)
    end

    hc.messaging.compose_message(p, function(p, m, cl)
        hc.messaging.select_recipient_and_send_om(p, m)
        hc.messaging.view_message(p, om.from, om.login, om.time,
            "Offline Message", om.message)
    end, "OM Forward", message)
end

function hc.messaging.delete_om(p)
    hc.close_editor(p)

    local om = hc.players[p].messaging.current_om
    local t = {}

    local filename = hc.messaging.get_messages_fn(hc.get_login(p))
    local messages = hc.read_file(filename)

    for _,row in ipairs(messages) do
        local from, login, time, message = hc.messaging.parse_message_item(row)

        if om.login ~= login or om.time ~= time then
            table.insert(t, row)
        else
            hc.event(p, "Message deleted.")
        end
    end

    if #t == 0 then
        os.remove(filename)
    else
        hc.write_file(filename, t)
    end
    hc.messaging.messages_command(p)
end


-------------------------------------------------------------------------------
-- Say commands
-------------------------------------------------------------------------------

function hc.messaging.vm_command(p, arg)
    if arg then
        hc.messaging.send_vm(p, { arg })
    else
        hc.messaging.compose_message(p, hc.messaging.send_vm, "VIP Message")
    end
end

function hc.messaging.mm_command(p, arg)
    if arg then
        hc.messaging.send_mm(p, { arg })
    else
        hc.messaging.compose_message(p, hc.messaging.send_mm, "Moderator Message")
    end
end

function hc.messaging.pm_command(p, cmd, arg)
    hc.messaging.send_pm(p, cmd, arg)
end

function hc.messaging.om_command(p, arg)
    if arg then
        hc.messaging.select_recipient_and_send_om(p, { arg })
    else
        hc.messaging.compose_message(p, hc.messaging.select_recipient_and_send_om, "Offline Message")
    end
end

function hc.messaging.ombc_command(p, arg)
    local function send_ombc(p, msg)
        local menu = {
            { title = "All", value = { hc.VIP, hc.MODERATOR1, hc.MODERATOR2, hc.ADMINISTRATOR } },
            { title = "VIP's", value = { hc.VIP } },
            { title = "Moderators level 1", value = { hc.MODERATOR1 } },
            { title = "Moderators level 2", value = { hc.MODERATOR2 } },
            { title = "Moderators", value = { hc.MODERATOR1, hc.MODERATOR2 } },
            { title = "Administrators", value = { hc.ADMINISTRATOR } }
        }

        hc.show_menu(p, "Recipients", menu,
            function(p, id, item)
                for login,user in pairs(hc.users) do
                    for _,level in ipairs(item.value) do
                        if user.level == level then
                            hc.messaging.send_om(p, login, { "*** Broadcast to " .. item.title, unpack(msg) })
                            break
                        end
                    end
                end
                hc.event(p, "Message sent to: " .. item.title .. ".")
            end)
    end

    if arg then
        send_ombc(p, { arg })
    else
        hc.messaging.compose_message(p, send_ombc, "Offline Broadcast")
    end
end

function hc.messaging.bc_command(p, arg)
    local function send_bc(p, msg)
        for _,line in ipairs(msg) do
            local text = hc.censor_text(line)

            text = hc.strip_end(text, "[©@]C", 2)
            hc.info(player(p, "name") .. ": " .. text)
        end
    end

    if arg then
        send_bc(p, { arg })
    else
        hc.messaging.compose_message(p, send_bc, "Broadcast")
    end
end


-------------------------------------------------------------------------------
-- Menu commands
-------------------------------------------------------------------------------

function hc.messaging.messages_command(p)
    local t = {}

    local filename = hc.messaging.get_messages_fn(hc.get_login(p))
    local tab = hc.read_file(filename)

    for i=#tab,1,-1 do
        local row = tab[i]
        local from, login, time, message = hc.messaging.parse_message_item(row)

        table.insert(t, {
            title = from .. "|" .. os.date("%d/%m %H:%M", time),
            from = from,
            login = login,
            time = time,
            message = message
        })
    end

    if #t > 0 then
        hc.show_menu(p, "Messages", t,
            function(p, _, item)
                hc.messaging.view_message(p, item.from, item.login,
                    item.time,
                    "Offline Message",
                    item.message)
            end)
    else
        hc.info(p, "You have no messages. Use '!om' to send a message.")
    end
end

function hc.messaging.parse_message_item(row)
    local login = tonumber(row[1])
    local time = tonumber(row[2])

    row[1] = login
    row[2] = time

    local from
    local sender = hc.users[login]

    if sender then
        from = sender.name
    else
        from = login
    end

    local message = {}

    for i=3,#row do
        table.insert(message, row[i])
    end
    return from, login, time, message
end


-------------------------------------------------------------------------------
-- Hooks
-------------------------------------------------------------------------------

function hc.messaging.init_player_hook(p, reason)
    hc.players[p].messaging = {}
end

function hc.messaging.team_hook(p)
    local filename = hc.messaging.get_messages_fn(hc.get_login(p))
    local f, error = io.open(filename)
    if f == nil then
        return
    end

    if f:read(0) ~= nil then
        hc.info(p, "You have messages! Press " .. hc.DEFAULT_KEYS[hc.COMMAND_MENU_KEY] .. " to read.")
    end
    f:close()
end
