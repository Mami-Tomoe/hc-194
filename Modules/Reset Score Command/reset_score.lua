-------------------------------------------------------------------------------
-- Module API
-------------------------------------------------------------------------------

function hc.reset_score.init()
	hc.add_say_command('rs', hc.moderation.reset_score_command, hc.RESET_SCORE_LEVEL, '',
		'Reset your score, deaths and assists.', true)
end

-------------------------------------------------------------------------------
-- Say commands
-------------------------------------------------------------------------------

function hc.moderation.reset_score_command(p, arg)
	if hc.undo then
		local score, deaths, assists = player(p, 'score'), player(p, 'deaths'), player(p, 'assists')

		hc.undo.register_command(p, 'rs', 'Restore your previous score.', function(p)
			hc.exec(p, 'setscore ' .. p .. ' ' .. score)
			hc.exec(p, 'setdeaths ' .. p .. ' ' .. deaths)
			hc.exec(p, 'setassists ' .. p .. ' ' .. assists)
		end)
	end

	hc.exec(p, 'setscore ' .. p .. ' 0')
	hc.exec(p, 'setdeaths ' .. p .. ' 0')
	hc.exec(p, 'setassists ' .. p .. ' 0')

	hc.info(p, 'K/D/A reset.')
end
