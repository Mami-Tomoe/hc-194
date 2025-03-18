-------------------------------------------------------------------------------
-- Module API
-------------------------------------------------------------------------------

function hc.reset_score.init()
	hc.add_say_command('rs', hc.reset_score.reset_score_command, hc.RESET_SCORE_LEVEL, nil,
		'Reset your score, deaths and assists.', true)
end

-------------------------------------------------------------------------------
-- Say commands
-------------------------------------------------------------------------------

function hc.reset_score.reset_score_command(p, arg)
	hc.exec(p, 'setscore ' .. p .. ' 0')
	hc.exec(p, 'setdeaths ' .. p .. ' 0')
	hc.exec(p, 'setassists ' .. p .. ' 0')

	hc.info(p, 'Your score is now reset.')
end
