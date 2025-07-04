-- Workaround for timer bug

-------------------------------------------------------------------------------
-- Module API
-------------------------------------------------------------------------------

function hc.timer.init()
	hc.timer.timers = {}

	cs2d_timer = timer
	-- timer = hc.timer.timer

	cs2d_freetimer = freetimer
	-- freetimer = hc.timer.free_timer
	addhook("second", "hc.timer.timer_hook")
end

------------------------------------------------------------------------------
-- Hooks
------------------------------------------------------------------------------

function hc.timer.timer_hook()
	local now = os.time()
	local timers_to_add = {}
	local num_to_remove = 0

	for id, timer in ipairs(hc.timer.timers) do
		if timer.expiration < now then
			num_to_remove = id
			hc.main.call_function(timer.func, timer.p)
			if timer.c ~= nil and timer.c ~= 1 then
				timer.c = timer.c - 1
				table.insert(timers_to_add, timer)
			end
		else
			break
		end
	end

	for i = 1, num_to_remove do
		table.remove(hc.timer.timers, 1)
	end
	for _, timer in ipairs(timers_to_add) do
		hc.timer.insert_timer(timer)
	end
end

------------------------------------------------------------------------------
-- CS2D function replacements
------------------------------------------------------------------------------

---This function is deprecated and may be removed in a future release.
---@deprecated
function hc.timer.timer(time, func, p, c)
	hc.timer.insert_timer({ time = time, func = func, p = p, c = c })
end

---This function is deprecated and may be removed in a future release.
---@deprecated
function hc.timer.free_timer(func, p)
	for id, timer in ipairs(hc.timer.timers) do
		if timer.func == func and p == nil or timer.p == p then
			table.remove(hc.timer.timers, id)
			return
		end
	end
	print("Error: Couldn't find timer '" .. func .. "'.")
end

------------------------------------------------------------------------------
-- Internal functions
------------------------------------------------------------------------------

function hc.timer.insert_timer(timer)
	timer.expiration = os.time() + timer.time / 1000
	for id, t in ipairs(hc.timer.timers) do
		if t.expiration > timer.expiration then
			table.insert(hc.timer.timers, id, timer)
			return
		end
	end
	table.insert(hc.timer.timers, timer)
end
