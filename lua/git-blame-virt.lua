local M = {}
M.git_blame_virt_ns = -1

-- Extract all lua functions. Returns a list of all function stored inside this node. All lines are 1-indexed.
--
-- Result:
-- ```
-- {
--    {
--	      first = <line>,
--	      last = <line>,
--	      type = <treesitter type>,
--	      indent = <char offset>
--    }, ...
-- }
-- ```- A function is identified by type `ty`
function M.ts_type_extract(node, types)
	local chunks = {}
	for child in node:iter_children() do
		if child:child_count() > 0 then
			local cchunks = M.ts_type_extract(child, types)
			for _,c in ipairs(cchunks) do
				table.insert(chunks, c)
			end
		end

		for _,ty in ipairs(types) do
			if child:type() == ty then
				local first, indent, last, _ = child:range()
				table.insert(chunks, {
					type = ty,
					first = first + 1,
					last = last + 1,
					indent = indent,
				})
			end
		end
	end
	return chunks
end

M.lang = {
	lua = function(node)
		local chunks = require'git-blame-virt.lang.lua'.ts_chunks(node)
		if vim.g.git_blame_virt.debug then
			print(vim.inspect(chunks))
		end
		return chunks
	end,
	rust = function(node)
		local chunks = require'git-blame-virt.lang.rust'.ts_chunks(node)
		if vim.g.git_blame_virt.debug then
			print(vim.inspect(chunks))
		end
		return chunks
	end,
	cpp = function(node)
		local chunks = require'git-blame-virt.lang.cpp'.ts_chunks(node)
		if vim.g.git_blame_virt.debug then
			print(vim.inspect(chunks))
		end
		return chunks
	end,
	python = function(node)
		local chunks = require'git-blame-virt.lang.python'.ts_chunks(node)
		if vim.g.git_blame_virt.debug then
			print(vim.inspect(chunks))
		end
		return chunks
	end
}
M.lang.c = M.lang.cpp

function M.display_blame_info(buf, chunk, info)
	local line = ''
	local prev = false
	if vim.g.git_blame_virt.config.display_commit then
		line = line .. vim.g.git_blame_virt.icons.git .. ' ' .. info.commit.hash .. ' '
		prev = true
	end
	if vim.g.git_blame_virt.config.display_committers then
		local committers = ''
		for i,committer in ipairs(info.committers) do
			if i > vim.g.git_blame_virt.config.max_committers then
				break
			end
			if committers ~= '' then
				committers = committers .. ', '
			end
			committers = committers .. committer
		end
		if #info.committers > vim.g.git_blame_virt.config.max_committers then
			committers = committers .. '(+' .. (#info.committers - vim.g.git_blame_virt.config.max_committers) .. ' committers)'
		end
		if prev == true then
			line = line .. vim.g.git_blame_virt.seperator .. ' '
		end
		line = line .. vim.g.git_blame_virt.icons.committer .. committers .. ' '
		prev = true
	end
	if vim.g.git_blame_virt.config.display_time and info.commit.timestamp ~= 0 then
		local commit_time = os.time({
			day = 1,
			month = 1,
			year = 1970,
			hour = 0,
			min = 0,
			sec = info.commit.timestamp
		})
		local now = os.time()
		local diff = os.difftime(now, commit_time)
		local u = diff
		local unit = nil
		if diff < 60 then
			unit = 'second'
		elseif diff < 3600 then
			u = (diff / 60)
			unit = 'minute'
		elseif diff < 86400 then
			u = (diff / 3600)
			unit = 'hour'
		elseif diff < 2592000 then
			u = (diff / 86400)
			unit = 'day'
		elseif diff < 31536000 then
			u = (diff / 2592000)
			unit = 'month'
		else
			u = (diff / 31536000)
			unit = 'year'
		end
		u = math.floor(u * 10) / 10;
		if u - 1 >= 0.1 then
			unit = unit .. 's'
		end
		if prev == true then
			line = line .. vim.g.git_blame_virt.seperator  .. ' '
		end
		line = line  .. u .. ' ' .. unit .. ' ago'
	end

	local text_line = vim.api.nvim_buf_get_lines(buf, chunk.first-1, chunk.first, true)[1]
	local indent = text_line:find('[^%s]+', 1)

	vim.api.nvim_buf_set_extmark(buf, M.git_blame_virt_ns, chunk.first-1, 0, {
		virt_lines = {
			{
				{ text_line:sub(1, indent-1):gsub('\t', string.rep(' ', vim.o.tabstop)), '' },
				{ line, vim.g.git_blame_virt.higroup }
			}
		},
		virt_lines_above = true
	})
end

-- Parse multi line `git blame` output.
--
-- ```
-- {
--     commits = { '<commit hash>', ... },
--     committers = { '<name>', ... },
-- }
-- ```
function M.parse_blame(lines)
	local info = {
		commit = {
			hash = '',
			timestamp = 0
		},
		committers = {}
	}
	local committers = {}
	for _, str in ipairs(lines) do
		local commit = ''
		for i = 1, #str do
			if str:sub(i,i) == ' ' then
				commit = str:sub(1, i-1)
				break
			end
		end

		local i = str:find('%(', 1)
		local j = str:find(' +%d+ +%d+%)', i)
		local committer = str:sub(i+1, j-1)
		committers[committer] = true

		i = str:find('%d+ +%d+%)', j)
		j = str:find(" +%d+%)", i)
		local timestamp = tonumber(str:sub(i, j-1), 10)

		if timestamp > info.commit.timestamp then
			info.commit.timestamp = timestamp
			info.commit.hash = commit
		end
	end

	for committer,_ in pairs(committers) do
		info.committers[#info.committers + 1] = committer
	end

	return info
end

-- Runs git blame on `file` and extract git blame information from `location`.
-- The blame is taken from line `line_start` to `line_end`.
--
-- This function is async. Use `on_result` to specify callback function
function M.git_blame_virt(file, line_start, line_end, on_result)
	local Job = require'plenary.job'

	Job:new({
		command = 'git',
		args = {
			'blame',
			'--date', 'unix',
			'-L', line_start .. ',' .. line_end,
			'--', file
		},
		on_exit = vim.schedule_wrap(function(job, result)
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
		end)
	}):start()
end

-- Returns a list of all functions found by TreeSitter
--
-- Result:
-- ```
-- {
--    {
--		 first = <line>,
--		 last = <line>
--    },
-- }
-- ```
function M.ts_extract_chunks(bufnr)
	local ft = vim.api.nvim_buf_get_option(bufnr, 'filetype')
	if type(M.lang[ft]) == 'function' then
		local parser = vim.treesitter.get_parser(bufnr)
		local tree = parser:parse()[1]
		return M.lang[ft](tree:root())
	end
	return nil
end

function M.ts_dump_tree(node, D)
	local d = 0
	if D then
		d = D
	end
	if node == nil then
		local parser = vim.treesitter.get_parser(bufnr)
		local tree = parser:parse()[1]
		node = tree:root()
	end
	for child in node:iter_children() do
		local b, _, e, _ = child:range()
		print(string.rep('  ', d), child, b .. ':' .. e)
		if child:child_count() > 0 then
			M.ts_dump_tree(child, d + 1)
		end
	end
end

function M.setup(options)
	if vim.g.git_blame_virt == nil then
		vim.g.git_blame_virt = {}
	end

	if options == nil then
		options = {}
	end

	local defaults = {
		debug = false,
		icons = {
			git = '',
			committer = '👥'
		},
		seperator = '|',
		config = {
			display_commit = false,
			display_committers = true,
			display_time = true,
			max_committers = 3
		},
		higroup = 'Comment'
	}

	vim.g.git_blame_virt = vim.tbl_deep_extend('keep', options, vim.g.git_blame_virt, defaults)

	if M.git_blame_virt_ns == -1 then
		M.git_blame_virt_ns = vim.api.nvim_create_namespace('GitBlameNvim')
	end
	
	local agid = vim.api.nvim_create_augroup('GitBlameNvim', {
		clear = true
	})
	vim.api.nvim_create_autocmd({"BufWritePost", "BufEnter"}, {
		pattern = '*',
		callback = function()
			local buf = vim.api.nvim_get_current_buf()
			local name = vim.api.nvim_buf_get_name(buf)
			if not vim.api.nvim_buf_get_option(buf, 'modified') then
				vim.api.nvim_buf_clear_namespace(buf, M.git_blame_virt_ns, 0, -1)
				local chunks = M.ts_extract_chunks(buf)
				if chunks ~= nil then
					for _,chunk in ipairs(chunks) do
						M.git_blame_virt(name, chunk.first, chunk.last, function(info)
							M.display_blame_info(buf, chunk, info)
						end)
					end
				end
			end
		end
	})
end

return M
