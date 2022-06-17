local M = {}

-- Parse multi line `git blame` output.
--
-- ```
-- {
--     commits = { '<commit hash>', ... },
--     authors = { '<name>', ... },
-- }
-- ```
function M.parse_blame(lines)
	local info = {
		commits = {},
		authors = {}
	}
	local commits = {}
	local authors = {}
	for _, str in ipairs(lines) do
		j = 1
		for i = 1, #str do
			if str:sub(i,i) == ' ' then
				local commit = str:sub(1, i-1)
				commits[commit] = true
				j = i + 1
				break
			end
		end

		local i = str:find('%d%d%d%d%-%d%d%-%d%d', j)
		local author = str:sub(j+1, i-2)
		authors[author] = true
	end

	for commit,_ in pairs(commits) do
		info.commits[#info.commits] = commit
	end

	for author,_ in pairs(authors) do
		info.authors[#info.authors] = author
	end

	return info
end

-- Runs git blame on `file` and extract git blame information from `location`.
-- The blame is taken from line `line_start` to `line_end`.
--
-- This function is async. Use `on_result` to specify callback function
function M.blame(file, line_start, line_end, on_result)
	local Job = require'plenary.job'

	Job:new({
		command = 'git',
		args = {
			'blame',
			'-L', line_start .. ',' .. line_end,
			'--', file
		},
		on_exit = function(job, result)
			if not result == 0 then
				print('error: Failed to execute git blame (exit code: ' .. result .. ')')
				return
			end
			local blame_info = M.parse_blame(job:result())
			if type(on_result) == 'function' then
				if blame_info then
					on_result(blame_info)
				else
					on_result(nil)
				end
			end
		end
	}):start()
end

return M
