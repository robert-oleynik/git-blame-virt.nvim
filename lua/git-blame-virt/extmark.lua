-- SPDX-License-Identifier: BSD-2-Clause
--
-- Copyright (c) 2022 Robert Oleynik

local M = {}

M.ns = nil

function M.setup()
	M.ns = M.ns or vim.api.nvim_create_namespace('GitBlameVirtNvim')
end

---Adds a new virtual line above linum. If virtual line already exists replace text of virtual
---line.
---
---@param bufnr (number|nil) Buffer to update. Use 0 or nil for current buffer.
---@param linum (number) Add virtual line above this line.
---@param content (table) Content of virtual lines. See vim.api.nvim_buf_set_extmark option
---  virt_lines.
---@return (number) Returns id of extmark.
function M.replace(bufnr, linum, content)
	bufnr = bufnr or 0
	local status, extmarks = pcall(vim.api.nvim_buf_get_extmarks, bufnr, M.ns, {linum,0}, {linum,0}, {limit=1})
	if status and extmarks[1] then
		local mark = extmarks[1][1]
		vim.api.nvim_buf_set_extmark(bufnr, M.ns, linum, 0, {
			id = mark,
			virt_lines_above = true,
			virt_lines = content
		})
		return mark
	else
		return vim.api.nvim_buf_set_extmark(bufnr, M.ns, linum, 0, {
			virt_lines_above = true,
			virt_lines = content
		})
	end
end

---Remove all extension marks except exlcluded ones.
---
---@param bufnr (number|nil) Buffer to clear. Use 0 or nil for current buffer.
---@param exclude (table) IDs of extmarks to exclude.
function M.remove_all(bufnr, exclude)
	bufnr = bufnr or 0
	local status, extmarks = pcall(vim.api.nvim_buf_get_extmarks, bufnr, M.ns, {linum,0}, {linum,0}, {limit=1})
	if status then
		for _, mark in ipairs(extmarks) do
			if not utils.contains(exclude, mark[1]) then
				vim.api.nvim_buf_del_extmark(bufnr, M.ns, mark[1])
			end
		end
	end
end

---Clear name buffer namespace. Removes all extmarks and virtual lines
---
---@param bufnr (number|nil) Buffer to clear. Use 0 or nil for current buffer.
function M.clear(bufnr)
	bufnr = bufnr or 0
	vim.api.nvim_buf_clear_namespace(bufnr, M.ns, 0, -1)
end

return M
