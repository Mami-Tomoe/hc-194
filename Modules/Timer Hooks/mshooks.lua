------------------------------------------------------------------------------
-- Module API
------------------------------------------------------------------------------

local added_mshooks = {}

------------------------------------------------------------------------------
-- Internal functions
------------------------------------------------------------------------------

local function has_timer_for(ms)
	for _, hk in ipairs(added_mshooks) do
		if hk.ms == ms then
			return true
		end
	end

	return false
end

local function call_mshooks(ms)
	for _, hk in ipairs(added_mshooks) do
		if hk.ms == ms then
			local success, result = pcall(hk.func)

			if not success then
				print(hc.RED .. 'mshooks error: ' .. result)
			end
		end
	end
end

------------------------------------------------------------------------------
-- Public functions
------------------------------------------------------------------------------

---Attaches the Lua function "func" to the a timer hook that gets called every "ms".
---@param ms number milliseconds
---@param func string|function function
---@param prio? number priority
function hc.mshooks.add_hook(ms, func, prio)
	ms = ms or 0
	prio = prio or 0

	-- Convert function string to function reference.
	if type(func) == 'string' then
		func = _G[func]
	end

	-- Creates a timer "hook" if it hasn't been already.
	if not has_timer_for(ms) then
		timer(ms, 'hc.mshooks.ms_cb', tostring(ms), 0)
	end

	local entry = {
		ms = ms,
		func = func,
		prio = prio
	}

	local inserted

	for i, hk in ipairs(added_mshooks) do
		if prio >= hk.prio then
			table.insert(added_mshooks, i, entry)

			inserted = true

			break
		end
	end

	if not inserted then
		table.insert(added_mshooks, entry)
	end
end

---Removes a function from_csv a timer hook.
---@param ms number milliseconds
---@param func string|function function
function hc.mshooks.free_hook(ms, func)
	ms = ms or 0

	-- Convert function string to function reference.
	if type(func) == 'string' then
		func = _G[func]
	end

	local removed

	for i, hk in ipairs(added_mshooks) do
		if func == hk.func and ms == hk.ms then
			table.remove(added_mshooks, i)

			removed = true

			break
		end
	end

	if not removed then
		return
	end

	-- Frees a timer "hook" if it isn't used anymore.
	if not has_timer_for(ms) then
		freetimer('hc.mshooks.ms_cb', tostring(ms))
	end
end

------------------------------------------------------------------------------
-- Timer callback
------------------------------------------------------------------------------

function hc.mshooks.ms_cb(ms)
	ms = tonumber(ms)

	call_mshooks(ms)
end
