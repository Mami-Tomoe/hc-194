------------------------------------------------------------------------------
-- Module API
------------------------------------------------------------------------------

-- HUD text ID, by default HC won't use anything past 49, so using the max (199) seems fitting.
-- Those HUD text ids (0-49) are somewhat reserved for HC and it's safer to just not use them.
-- Though, anything between (and including) 50-199 should work just fine.
--
-- (check CS2D/sys/lua/hc/core/constants.lua for valid colours)
local hudtxt_id    = 199
local hudtxt_speed = 20                 -- How fast should the HUD Text disappear? Lower means faster. (N / 100) seconds.
local colour       = hc.RED             -- The visual colour for the HUD text.
local label        = colour .. '-%d HP' -- The way the HUD text is constructed.


function hc.show_damage.init()
	addhook('init_player', 'hc.show_damage.init_player_hook')
	addhook('delete_player', 'hc.show_damage.delete_player_hook')
	addhook('hit', 'hc.show_damage.hit_hook')
	addhook('ms100', 'hc.show_damage.ms100_hook')
end

------------------------------------------------------------------------------
-- Hooks
------------------------------------------------------------------------------

function hc.show_damage.init_player_hook(p, reason)
	hc.players[p].sd = { timer = 0, damage = 0 }
end

function hc.show_damage.delete_player_hook(p, reason)
	hc.players[p].sd = nil
end

function hc.show_damage.hit_hook(victim, source, itemType, hpdmg, apdmg, rawdmg, obj)
	if source > 0 and hpdmg > 0 then
		local damage = hc.players[source].sd.damage + hpdmg

		parse('hudtxt2 ' .. source .. ' ' .. hudtxt_id .. ' "' .. label:format(damage) .. '" 425 208 1 1')

		hc.players[source].sd = {
			damage = damage,
			timer = hudtxt_speed
		}
	end
end

function hc.show_damage.ms100_hook()
	for p = 1, hc.SLOTS do
		if hc.player_exists(p) then
			local timer = hc.players[p].sd.timer

			if timer > 0 then
				hc.players[p].sd.timer = timer - 1
			else
				hc.players[p].sd.damage = 0

				parse('hudtxtalphafade ' .. p .. ' ' .. hudtxt_id .. ' 100 0')
			end
		end
	end
end
