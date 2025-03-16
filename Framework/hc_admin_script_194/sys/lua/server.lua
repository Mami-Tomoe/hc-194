--
-- HC Admin Script
--
hc_dir  = "sys/lua/hc"
hc_conf = hc_dir.."/hc.conf"
dofile(hc_dir.."/hc.lua")

parse('mp_hudscale 1')