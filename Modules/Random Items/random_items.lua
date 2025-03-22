------------------------------------------------------------------------------
-- Module API
------------------------------------------------------------------------------

function hc.random_items.init()
	addhook('projectile_impact', 'hc.random_items.projectile_impact_hook')
end

------------------------------------------------------------------------------
-- Hooks
------------------------------------------------------------------------------

function hc.random_items.projectile_impact_hook(p, wpnType, x, y, mode, projectileID)
	local config = hc.RANDOM_ITEMS_CONFIG

	if wpnType == config.spawnerItem then
		if math.random(100) >= config.chance then -- Total chance check.
			return
		end

		local itemID

		for i = 1, #config.weaponTypes do
			local wpn = config.weaponTypes[i]

			if math.random(0, 100) <= wpn.chance then
				itemID = wpn.id

				break -- STOP! We got the item, don't continue searching.
			end
		end

		itemID = itemID or
			config.defaultItemID -- This has to be an item, if we didn't get an item, place the default one.

		parse(('spawnitem "%d" "%d" "%d"'):format(itemID, math.floor(x / 32), math.floor(y / 32)))
	end
end
