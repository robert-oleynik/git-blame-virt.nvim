local utils = require'git-blame-virt.utils'

local M = {}

M.git_blame_virt_ns = -1

function langCallback(lang)
	return function(node)
		local chunks = require('git-blame-virt.lang.' .. lang).ts_chunks(node)
		if vim.g.git_blame_virt.debug then
			print(vim.inspect(chunks))
		end
		return chunks
	end
end

M.lang = {
	lua = langCallback('lua'),
	rust = langCallback('rust'),
	cpp = langCallback('cpp'),
	python = langCallback('python'),
	java = langCallback('java'),
	javascript = langCallback('javascript'),
	tex = langCallback('latex'),
	generic = langCallback('generic')
}
M.lang.c = M.lang.cpp

function M.display_blame_info(buf, chunk, info, extid)
	local line = ''
	local prev = false

	if vim.g.git_blame_virt.debug then
		print(vim.inspect(info))
	end

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
		local u, unit = utils.approx_rel_time(info.commit.timestamp)
		if prev == true then
			line = line .. vim.g.git_blame_virt.seperator  .. ' '
		end
		line = line  .. u .. ' ' .. unit .. ' ago'
	end

	local text_line = vim.api.nvim_buf_get_lines(buf, chunk.first, chunk.first + 1, true)[1]
	local indent = text_line:find('[^%s]+', 1)

	local virt_lines = {
		{
			{ text_line:sub(1, indent-1):gsub('\t', string.rep(' ', vim.o.tabstop)), '' },
			{ line, vim.g.git_blame_virt.higroup }
		}
	}
	if extid ~= 0 then
		return vim.api.nvim_buf_set_extmark(buf, M.git_blame_virt_ns, chunk.first, 0, {
			id = extid,
			virt_lines = virt_lines,
			virt_lines_above = true
		})
	else
		return vim.api.nvim_buf_set_extmark(buf, M.git_blame_virt_ns, chunk.first, 0, {
			virt_lines = virt_lines,
			virt_lines_above = true
		})
	end
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

		if timestamp > info.commit.timestamp and commit ~= "00000000" then
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
	local workdir = vim.env.PWD
	if vim.g.git_blame_virt.config.allow_foreign_repositories then
		local Path = require'plenary.path'
		workdir = Path:new(file):parent().filename
	end

	Job:new({
		command = 'git',
		args = {
			'blame',
			'--date', 'unix',
			'-L', line_start + 1 .. ',' .. line_end + 1,
			'--', file
		},
		cwd = workdir,
		on_exit = vim.schedule_wrap(function(job, result)
			if result ~= 0 then
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
--       type = <TreeSitter type>,
--		 first = <line>,
--		 last = <line>
--    },
-- }
-- ```
function M.ts_extract_chunks(bufnr)
	local ft = vim.api.nvim_buf_get_option(bufnr, 'filetype')
	if type(M.lang[ft]) == 'function' and
		(vim.g.git_blame_virt.ft[ft] or vim.g.git_blame_virt.ft[ft] == nil) then
		local parser = vim.treesitter.get_parser(bufnr)
		local tree = parser:parse()[1]
		return M.lang[ft](tree:root())
	else
		local status, parser = pcall(vim.treesitter.get_parser, bufnr)
		if status and (vim.g.git_blame_virt.ft[ft] or vim.g.git_blame_virt.ft[ft] == nil) then
			local tree = parser:parse()[1]
			return M.lang['generic'](tree:root())
		end
	end
	return nil
end

function M.ts_dump_tree(node, D)
	local d = D or 0
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
			max_committers = 3,
			allow_foreign_repositories = true
		},
		ft = {},
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
				local chunks = M.ts_extract_chunks(buf)
				if chunks ~= nil then
					local extmarks = {}
					for i,chunk in ipairs(chunks) do
						M.git_blame_virt(name, chunk.first, chunk.last, function(info)
							if info.commit.hash == "" or #info.committers == 0 then
								return
							end

							local status, marks = pcall(
								vim.api.nvim_buf_get_extmarks,
								buf,
								M.git_blame_virt_ns,
								{chunk.first, 0},
								{chunk.first, 0},
								{limit=1}
							)
							if status and #marks > 0 then
								local extid = marks[1][1]
								M.display_blame_info(buf, chunk, info, extid)
								extmarks[extid] = true
							else
								local id = M.display_blame_info(buf, chunk, info, 0)
								extmarks[id] = true
							end

							if i == 1 then
								local status, marks = pcall(vim.api.nvim_buf_get_extmarks, buf, M.git_blame_virt_ns, 0, -1, {})
								if status then
									for _,mark in ipairs(marks) do
										local id = mark[1]
										if not extmarks[id] then 
											vim.api.nvim_buf_del_extmark(buf, M.git_blame_virt_ns, id)
										end
									end
								end
							end
						end)
					end
				end
			end
		end
	})
end

return M
