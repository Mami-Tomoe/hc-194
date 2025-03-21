------------------------------------------------------------------------------
-- Module API
------------------------------------------------------------------------------

function hc.no_clip.init()
	addhook('key', 'hc.no_clip.key_hook')
	addbind(hc.NO_CLIP_KEY)
end

------------------------------------------------------------------------------
-- Hooks
------------------------------------------------------------------------------

function hc.no_clip.key_hook(p, key, state)
	if state ~= 0 then
		return
	elseif key ~= hc.NO_CLIP_KEY then
		return
	elseif not hc.commands.is_authorized(p, hc.NO_CLIP_LEVEL) then
		return
	elseif player(p, 'health') <= 0 then
		return
	end

	local mx, my = player(p, 'mousemapx'), player(p, 'mousemapy')

	if mx <= -1 or my <= -1 then
		return
	end

	local x, y = player(p, 'x'), player(p, 'y')

	if hc.NO_CLIP_EFFECT then
		local r, g, b = math.random(255), math.random(255), math.random(255)

		parse('effect "colorsmoke" "' .. x .. '" "' .. y .. '" "8" "32" "' .. r .. '" "' .. g .. '" "' .. b .. '"')
	end

	if hc.NO_CLIP_SFX then
		if hc.NO_CLIP_SFX.from then
			parse('sv_soundpos "' .. hc.NO_CLIP_SFX.from .. '" "' .. x .. '" "' .. y .. '" "0"')
		end

		if hc.NO_CLIP_SFX.to then
			parse('sv_soundpos "' .. hc.NO_CLIP_SFX.to .. '" "' .. mx .. '" "' .. my .. '" "0"')
		end
	end

	-- Not using hc.exec to avoid clogging the HC logs.
	-- You may change this if you wish.
	parse('setpos ' .. p .. ' ' .. mx .. ' ' .. my)
end
