-- SPDX-License-Identifier: BSD-2-Clause
--
-- Copyright (c) 2022 Robert Oleynik

local M = {}

M.utils = require("git-blame-virt.utils")
M.git = require("git-blame-virt.git")
M.lang = require("git-blame-virt.lang")
M.treesitter = require("git-blame-virt.treesitter")
M.extmark = require("git-blame-virt.extmark")

---Generates virt_line content from aggregated git blame information.
---
---@param info (table) Aggregated git blame information.
---@return (table) Content of extmark's virtual lines.
function M.display(info)
	local content = { "" }
	if info.last.timestamp == 0 then
		if M.config.display.commit_hash then
			table.insert(content, "0000000")
		end
		if M.config.display.commit_summary then
			table.insert(content, "(Not Commited Yet)")
		end
	else
		if M.config.display.commit_hash then
			table.insert(content, info.last.hash:sub(1, 7))
		end
		if M.config.display.commit_summary then
			table.insert(content, "(" .. info.last.summary .. ")")
		end
		if M.config.display.commit_committers then
			local max = M.config.display.max_committer
			local suffix = ""
			local committers = {}
			for i = 1, max do
				committers[i] = info.committers[i]
			end
			if #info.committers > max then
				suffix = string.format(" (+%i committers)", #info.committers - max)
			end
			M.utils.debug(vim.inspect(committers))
			table.insert(content, " " .. M.utils.join(committers, ", ") .. suffix)
		end
		if M.config.display.commit_time then
			table.insert(content, "| " .. M.utils.rel_time_str(info.last.timestamp))
		end
	end
	return {
		{ M.utils.join(content, " "), M.config.display.hi },
	}
end

---Update blame information of buffer. This function is asynchronous.
---
---@param bufnr (number|nil) Buffer to update information. Use `nil` or `0` for current buffer
function M.update(bufnr)
	bufnr = bufnr or 0
	local ft = vim.api.nvim_buf_get_option(bufnr, "filetype")
	M.utils.debug(vim.inspect(M.lang.fn[ft]), type(M.lang.fn[ft]))
	if type(M.lang.fn[ft]) ~= "function" then
		M.utils.error("Files of type", ft, "are not supported (yet)")
		return
	end
	local chunks = M.lang.fn[ft](bufnr)
	M.git.async_read_blame(bufnr, function(blame_info)
		M.extmark.clear(bufnr)
		for _, chunk in ipairs(chunks) do
			local sym, first_line, last_line = chunk[1], chunk[2], chunk[3]
			local info = blame_info(first_line + 1, last_line + 1)
			M.utils.debug(vim.inspect(info))

			local text_line = vim.api.nvim_buf_get_lines(bufnr, first_line, first_line + 1, true)[1]
			local indent = text_line:find("[^%s]+", 1)
			local virt_lines = {
				{ text_line:sub(1, indent - 1):gsub("\t", string.rep(" ", vim.o.tabstop)) },
			}

			local content = M.config.display.fn(info)
			for _, c in ipairs(content) do
				table.insert(virt_lines, c)
			end
			M.extmark.replace(bufnr, first_line, { virt_lines })
		end
	end)
end

M.config = {
	debug = false,
	allow_foreign_repos = true,
	display = {
		commit_hash = true,
		commit_summary = true,
		commit_committers = true,
		max_committer = 3,
		commit_time = true,
		hi = "Comment",
		fn = M.display,
	},
	ft = {
		lua = true,
		java = true,
		javascript = true,
		latex = true,
		python = true,
		rust = true,
		cpp = true,
	},
}

function M.setup(opts)
	opts = opts or {}

	M.config = vim.tbl_deep_extend("keep", opts, M.config)

	M.extmark.setup()
	M.lang.setup()

	M.augroup = vim.api.nvim_create_augroup("NvimGitBlameVirt", { clear = true })
	vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost" }, {
		pattern = "*",
		callback = function(event)
			local modified = vim.api.nvim_buf_get_option(event.buf, "modified")
			if modified then
				return
			end

			local ft = vim.api.nvim_buf_get_option(event.buf, "filetype")
			if type(M.lang.fn[ft]) == "function" and M.config.ft[ft] then
				M.update(event.buf)
			end
		end,
		group = M.augroup,
	})
end

return M
