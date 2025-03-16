------------------------------------------------------------------------------
--
-- Usage:
--
-- The following global variables must be set (e.g. in server.lua):
--
--   hc_dir	path to the hc directory
--   hc_conf	path to the hc.conf file
--
-- Example
--   hc_dir = "sys/lua/hc"
--   hc_conf = hc_dir.."/hc.conf"
--
------------------------------------------------------------------------------

if hc == nil then hc = {} end

hc.CORE_MODULES = { "util", "main", "timer", "commands", "user", "editor", "images" }


function hc.init()
	parse('mp_hudscale 1')

	hc.DIR = hc_dir

	dofile(hc.DIR .. "/core/cs2d.lua")
	dofile(hc.DIR .. "/core/constants.lua")

	-- Read config
	dofile(hc_conf)

	-- Read mandatory modules
	for _, module in ipairs(hc.CORE_MODULES) do
		hc.init_module("core", module)
	end

	-- Read optional modules
	for _, module in ipairs(hc.MODULES) do
		hc.init_module("modules", module)
	end

	-- These functions must be called after all modules have registered their
	-- callbacks.
	hc.main.init_players(hc.SCRIPT_INIT)
	hc.main.call_hook("init", false)
end

function hc.remove()
	hc.main.call_hook("remove", false)

	for id, value in pairs(hc.main.images) do
		if value then
			freeimage(id)
		end
	end
	for hook, funcs in pairs(hc.main.real_hooks) do
		for id, func in pairs(funcs) do
			hc.main.free_real_hook(hook, func)
		end
	end
end

function hc.init_module(type, name)
	local ns_func = loadstring("hc." .. name .. " = {}")
	ns_func()

	dofile(hc.DIR .. "/" .. type .. "/" .. name .. ".lua")

	local init_func = loadstring("local f = hc." .. name .. ".init; if f ~= nil and type(f) == \"function\" then f() end")
	init_func()
end

-- Initialize
hc.init()
