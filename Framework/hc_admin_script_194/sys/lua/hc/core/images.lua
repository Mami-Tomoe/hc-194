------------------------------------------------------------------------------
-- Persistent player images.
-- Will not be removed at round start.
------------------------------------------------------------------------------


------------------------------------------------------------------------------
-- Module API
-------------------------------------------------------------------------------

function hc.images.init()
    addhook("startround", "hc.images.startround_hook")
    addhook("spawn", "hc.images.spawn_hook", -999999)
    addhook("die", "hc.images.die_hook")
    addhook("delete_player", "hc.images.delete_player_hook")
end


------------------------------------------------------------------------------
-- API
------------------------------------------------------------------------------

-- Rotate
hc.images.DONT_ROTATE = 0
hc.images.ROTATE = 1

-- Don't show if covered by fog of war
hc.images.NOT_IF_FOW = 0
hc.images.ALWAYS = 1

-- Location
hc.images.UNDER = 100
hc.images.OVER = 200
hc.images.TOP = 132

-- Visibility
hc.images.PUBLIC = 0
hc.images.PRIVATE = 1


function hc.create_player_image(p, path, rotate, fow, location, level,
visibility, colour, alpha, blend, scale)
    local images = hc.players[p].images

    if images == nil then
        images = { next_id = 1, imgs = {} }
        hc.players[p].images = images
    end

    local id = images.next_id

    images.next_id = id + 1

    local img = {
        id = id,
        path = path,
        x = rotate,
        y = fow,
        mode = location + p,
        level = level,
        visibility = visibility,
        colour = colour,
        alpha = alpha,
        blend = blend,
        scale = scale
    }

    local n = #images.imgs + 1

    for id,imgx in ipairs(images.imgs) do
        if img.level < imgx.level then
            n = id
            break
        end
    end

    table.insert(images.imgs, n, img)

    if hc.images.should_images_be_shown(p) then
        hc.images.create_image(p, images.imgs[n])
    end
    return id
end

function hc.delete_player_image(p, id)
    local imgs = hc.players[p].images.imgs

    for i,img in ipairs(imgs) do
        if img.id == id then
            hc.images.delete_image(img)
            table.remove(imgs, i)
            break
        end
    end
end


-------------------------------------------------------------------------------
-- Hooks
-------------------------------------------------------------------------------

function hc.images.startround_hook(mode)
    for i=1,hc.SLOTS do
        if hc.player_exists(i) then
            hc.images.delete_images(i)
            hc.images.create_images(i)
        end
    end
end

function hc.images.spawn_hook(p)
    hc.images.create_images(p)
end

function hc.images.die_hook(victim, killer, weapon, x, y)
    hc.images.delete_images(victim)
end

function hc.images.delete_player_hook(p, reason)
    hc.images.delete_images(p)
end


-------------------------------------------------------------------------------
-- Internal functions
-------------------------------------------------------------------------------

function hc.images.should_images_be_shown(p)
    return player(p, "team") ~= hc.SPEC and player(p, "health") > 0
end

function hc.images.create_images(p)
    if hc.players[p].images ~= nil then
        for id,img in ipairs(hc.players[p].images.imgs) do
            hc.images.create_image(p, img)
        end
    end
end

function hc.images.delete_images(p)
    if hc.players[p].images ~= nil then
        for id,img in ipairs(hc.players[p].images.imgs) do
            hc.images.delete_image(img)
        end
    end
end

function hc.images.create_image(p, img)
    local visibility

    if img.visibility == hc.images.PRIVATE then
        visibility = p
    else
        visibility = nil
    end

    img.cs2d_id = image(img.path, img.x, img.y, img.mode, visibility)

    if img.colour ~= nil then
        imagecolor(img.cs2d_id, unpack(img.colour))
    end
    if img.alpha ~= nil then
        imagealpha(img.cs2d_id, img.alpha)
    end
    if img.blend ~= nil then
        imageblend(img.cs2d_id, img.blend)
    end
    if img.scale ~= nil then
        imagescale(img.cs2d_id, unpack(img.scale))
    end
end

function hc.images.delete_image(img)
    if img.cs2d_id ~= nil then
        freeimage(img.cs2d_id)
        img.cs2d_id = nil
    end
end
