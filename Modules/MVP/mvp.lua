------------------------------------------------------------------------------
-- Module API
------------------------------------------------------------------------------

local function reset_player(p)
	hc.players[p].mvp = { kills = 0, damage = 0 }
end


function hc.mvp.init()
	addhook('init_player', 'hc.mvp.init_player_hook')
	addhook('delete_player', 'hc.mvp.delete_player_hook')
	addhook('endround', 'hc.mvp.endround_hook')
	addhook('startround_prespawn', 'hc.mvp.startround_prespawn_hook')
	addhook('kill', 'hc.mvp.kill_hook')
	addhook('hit', 'hc.mvp.hit_hook')
end

------------------------------------------------------------------------------
-- Internal functions
------------------------------------------------------------------------------

function hc.mvp.get_mvp()
	local mvp, kills, damage

	for p = 1, hc.SLOTS do
		if hc.player_exists(p) then
			local p_kills = hc.players[p].mvp.kills
			local p_damage = hc.players[p].mvp.damage

			if mvp then
				if p_kills > hc.players[mvp].mvp.kills                                      -- Either more kills.
					or p_kills == hc.players[mvp].mvp.kills and p_damage > hc.players[mvp].mvp.damage then -- Or same kills but more damage.
					mvp    = p
					kills  = p_kills
					damage = p_damage
				end
			elseif p_kills > 0 then
				mvp    = p
				kills  = p_kills
				damage = p_damage
			elseif p_damage > 0 then
				mvp    = p
				kills  = p_kills
				damage = p_damage
			end
		end
	end

	return mvp, kills, damage
end

------------------------------------------------------------------------------
-- Hooks
------------------------------------------------------------------------------

function hc.mvp.init_player_hook(p, reason)
	reset_player(p)
end

function hc.mvp.delete_player_hook(p, reason)
	hc.players[p].mvp = nil
end

function hc.mvp.startround_prespawn_hook(mode)
	for p = 1, hc.SLOTS do
		if hc.player_exists(p) then
			reset_player(p)
		end
	end
end

function hc.mvp.endround_hook(mode)
	local mvp, kills, damage = hc.mvp.get_mvp()

	if mvp then
		hc.info(0, {
			'MVP: ' .. player(mvp, 'name'),
			'Frags: ' .. kills,
			'Damage: ' .. damage
		})
	end
end

function hc.mvp.kill_hook(killer, victim, itemType, x, y, obj, assistant)
	local frags = 1

	if hc.MVP_FRIENDLY_FIRE_PENALTY == true then
		if player(victim, 'team') == player(killer, 'team') then
			frags = -frags -- Reduce frags (penalty).
		end
	end

	hc.players[killer].mvp.kills = hc.players[killer].mvp.kills + frags
end

function hc.mvp.hit_hook(victim, source, itemType, hpdmg, apdmg, rawdmg, obj)
	if source <= 0 then
		return
	end

	local dmg = hpdmg

	if hc.MVP_FRIENDLY_FIRE_PENALTY == true then
		if player(victim, 'team') == player(source, 'team') then
			dmg = -dmg -- Reduce inflicted damage (penalty).
		end
	end

	hc.players[source].mvp.damage = hc.players[source].mvp.damage + dmg
end
