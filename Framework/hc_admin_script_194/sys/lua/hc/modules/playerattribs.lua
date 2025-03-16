------------------------------------------------------------------------------
-- Module API
-------------------------------------------------------------------------------

function hc.playerattribs.init()
    hc.add_menu_command("Attribute", hc.playerattribs.attribute_command, hc.PLAYER_ATTRIB_LEVEL, hc.COMMAND_MENU_KEY, { category = "Config" })

    addhook("init_player", "hc.playerattribs.init_player_hook")
    addhook("team", "hc.playerattribs.team_hook", 99999)
    addhook("player_level", "hc.playerattribs.player_level_hook")
end

hc.playerattribs.IMAGE_PATH = "gfx/hc/attribs/"

hc.playerattribs.ATTRIBUTES = {
    Angel = "angel.png",
    Devil = "devil.png",
    ["Gandalf Hat"] = "gandalf_hat.png",
    ["Graduation Hat"] = "graduation_hat.png",
    ["Metal Helmet"] = {
        [hc.T] = {
            [hc.VIP] = "metal_helmet_vip.png",
            [hc.MODERATOR1] = "metal_helmet_mod.png",
            [hc.MODERATOR2] = "metal_helmet_mod.png",
            [hc.ADMINISTRATOR] = "metal_helmet_adm.png"
        },
        [hc.CT] = {
            [hc.VIP] = "metal_helmet_vip.png",
            [hc.MODERATOR1] = "metal_helmet_mod.png",
            [hc.MODERATOR2] = "metal_helmet_mod.png",
            [hc.ADMINISTRATOR] = "metal_helmet_adm.png"
        }
    },
    ["Party Hat"] = "party_hat.png",
    ["Pirate Hat"] = "pirate_hat.png",
    ["Pumpkin Head"] = "pumpkin_head.png",
    ["Snowman"] = "snowman.png",
    ["Santa Hat"] = "santa_hat.png",
    Spear = "spear.png",
    Umbrella = {
        [hc.T] = "umbrella_t.png",
        [hc.CT] = "umbrella_ct.png"
    },
    None = {}
}

hc.playerattribs.ATTRIB_PROP_NAME = "player_attrib"


-------------------------------------------------------------------------------
-- Hooks
-------------------------------------------------------------------------------

function hc.playerattribs.init_player_hook(p)
    hc.playerattribs.set_image(p, player(p, "team"))
end

function hc.playerattribs.team_hook(p, team, look)
    if team ~= hc.SPEC then
        hc.playerattribs.free_image(p)
        hc.playerattribs.set_image(p, team)
    end
end

function hc.playerattribs.player_level_hook(p, old_level, new_level)
    if new_level < hc.VIP and old_level >= hc.VIP then
        hc.playerattribs.free_image(p)
    elseif new_level >= hc.VIP and old_level < hc.VIP then
        hc.playerattribs.set_image(p, player(p, "team"))
    end
end


-------------------------------------------------------------------------------
-- Internal functions
-------------------------------------------------------------------------------

function hc.playerattribs.set_image(p, team)
    local attrib_name = hc.get_player_property(p, hc.playerattribs.ATTRIB_PROP_NAME)
    local img_file = nil

    if attrib_name ~= nil then
        local attribute = hc.playerattribs.ATTRIBUTES[attrib_name]

        if type(attribute) == "table" then
            local team_attribute = attribute[team]

            if type(team_attribute) == "table" then
                local image_file = team_attribute[hc.get_level(p)]

                if image_file ~= nil then
                    img_file = image_file
                end
            elseif team_attribute ~= nil then
                img_file = team_attribute
            end
        elseif attribute ~= nil then
            img_file = attribute
        end
    end
    if img_file ~= nil then
        hc.players[p].playerattribs =
        hc.create_player_image(p, hc.playerattribs.IMAGE_PATH .. img_file, hc.images.ROTATE,
            hc.images.NOT_IF_FOW, hc.images.OVER, 0)
    end
end

function hc.playerattribs.free_image(p)
    local img = hc.players[p].playerattribs
    if img ~= nil then
        hc.delete_player_image(p, img)
        hc.players[p].playerattribs = nil
    end
end


------------------------------------------------------------------------------
-- Command callbacks
------------------------------------------------------------------------------

function hc.playerattribs.attribute_command(p)
    local menu = {}
    local i = 1

    for attrib in pairs(hc.playerattribs.ATTRIBUTES) do
        menu[i] = attrib
        i = i + 1
    end

    table.sort(menu)
    hc.show_menu(p, "Attribute", menu,
        function(p, id, item)
            hc.set_player_property(p, hc.playerattribs.ATTRIB_PROP_NAME, item)
            hc.playerattribs.free_image(p)
            hc.playerattribs.set_image(p, player(p, "team"))
        end)
end

