local M = {}
M.git_blame_ns = -1

function M.ts_type_extract(node, types, D)
	local d = 0
	if D then
		d = D
	end
	local chunks = {}
	for child in node:iter_children() do
		if child:child_count() > 0 then
			local cchunks = M.ts_type_extract(child, types, d + 1)
			for _,c in ipairs(cchunks) do
				table.insert(chunks, c)
			end
		end

		if vim.g.git_blame.debug then
			print(string.rep('  ', d), child, child:range())
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

-- Extract all lua functions. Returns a list of all function stored inside this node. All lines are 1-indexed.
--
-- Result:
-- ```
-- {
--    {
--	      first = <line>,
--	      last = <line>
--    }, ...
-- }
-- ```- A function is identified by type `ty`
function M.ts_extract_lua(node)
	return M.ts_type_extract(node, {'function_decleration'})
end

-- Extract all rust functions, impl blocks and structs as range from `node`.
function M.ts_extract_rust(node)
	return M.ts_type_extract(node, {'function_item', 'impl_item', 'struct_item'})
end

function M.display_blame_info(buf, chunk, info)
	local line = vim.g.git_blame.icons.git
	if vim.g.git_blame.config.display_commit then
		line = line ..vim.g.git_blame.spacer ..
			'Commit: ' .. info.commits[1]
	end
	if vim.g.git_blame.config.display_commit then
		local authors = ''
		for i,author in ipairs(info.authors) do
			if i > vim.g.git_blame.config.max_authors then
				break
			end
			if authors ~= '' then
				authors = authors .. ','
			end
			authors = authors .. author
		end
		if #info.authors > vim.g.git_blame.config.max_authors then
			authors = authors .. '(+' .. (#info.authors - vim.g.git_blame.config.max_authors) .. ' committers)'
		end
		line = line .. vim.g.git_blame.spacer ..
			vim.g.git_blame.icons.author ..
			authors
	end
	vim.api.nvim_buf_set_extmark(buf, M.git_blame_ns, chunk.first-1, 0, {
		virt_lines = {
			{
				{ string.rep(' ', chunk.indent), '' },
				{ line, 'Comment' }
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
		info.commits[#info.commits + 1] = commit
	end

	for author,_ in pairs(authors) do
		info.authors[#info.authors + 1] = author
	end

	return info
end

-- Runs git blame on `file` and extract git blame information from `location`.
-- The blame is taken from line `line_start` to `line_end`.
--
-- This function is async. Use `on_result` to specify callback function
function M.git_blame(file, line_start, line_end, on_result)
	local Job = require'plenary.job'

	Job:new({
		command = 'git',
		args = {
			'blame',
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
	if type(M['ts_extract_' .. ft]) == 'function' then
		local parser = vim.treesitter.get_parser(bufnr)
		local tree = parser:parse()[1]
		return M['ts_extract_' .. ft](tree:root())
	end
	return nil
end

function M.setup(options)
	if vim.g.git_blame == nil then
		vim.g.git_blame = {}
	end

	if options == nil then
		options = {}
	end

	local defaults = {
		debug = false,
		icons = {
			git = '',
			author = '👥'
		},
		spacer = ' ',
		config = {
			display_commit = true,
			display_authors = true,
			max_authors = 3
		}
	}

	vim.g.git_blame = vim.tbl_deep_extend('keep', options, vim.g.git_blame, defaults)
	print(vim.inspect(vim.g.git_blame))

	if M.git_blame_ns == -1 then
		M.git_blame_ns = vim.api.nvim_create_namespace('GitBlameNvim')
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
				vim.api.nvim_buf_clear_namespace(buf, M.git_blame_ns, 0, -1)
				local chunks = M.ts_extract_chunks(buf)
				if chunks ~= nil then
					for _,chunk in ipairs(chunks) do
						M.git_blame(name, chunk.first, chunk.last, function(info)
							M.display_blame_info(buf, chunk, info)
						end)
					end
				end
			end
		end
	})
end

return M
