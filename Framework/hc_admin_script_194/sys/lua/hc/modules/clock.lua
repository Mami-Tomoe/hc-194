------------------------------------------------------------------------------
-- Module API
------------------------------------------------------------------------------

function hc.clock.init()
    addhook("minute", "hc.clock.minute_hook")
    addhook("post_join", "hc.clock.post_join_hook")
    hc.clock.display_time()
end


------------------------------------------------------------------------------
-- Internal functions
------------------------------------------------------------------------------

function hc.clock.display_time()
    parse("hudtxt 49 \"" .. os.date("%H:%M %Z") .. "\" 4 96 0 0 11")
end


------------------------------------------------------------------------------
-- Hooks
------------------------------------------------------------------------------

function hc.clock.minute_hook()
    hc.clock.display_time()
end

function hc.clock.post_join_hook(p)
    hc.clock.display_time()
end
