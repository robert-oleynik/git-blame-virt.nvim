-- SPDX-License-Identifier: BSD-2-Clause
--
-- Copyright (c) 2022 Robert Oleynik

local M = {}
local utils = require'git-blame-virt.utils'

---Generates a function which is used to build a list line spans from a buffer.
---
---@param lang (string) TreeSitter language to parse.
---@param query (string) TreeSitter query to parse.
---@param sym (table) Table of symbol names identified by query. Table is indexed by ids.
---
---@return (fun(number)) Returns a function which returns a list of symbols and line spans
--- identified by query. 
function M.parse_query(lang, query, sym)
	local query = vim.treesitter.query.parse_query(lang, query)
	return function(bufnr)
		bufnr = bufnr or 0
		if query == nil then
			utils.error('Invalid query (language: ' .. lang .. ')')
			return {}
		end

		return M.run(bufnr, function(root)
			local result = {}
			for id, nodes, _ in query:iter_matches(root, bufnr) do
				local symbol = sym[id]
				local first_line, _, last_line, _ = nodes[1]:range()
				table.insert(result, { symbol, first_line, last_line })
			end
			return result
		end)
	end
end

function M.run(bufnr, callback)
	local parser = vim.treesitter.get_parser(bufnr)
	local tree = parser:parse()[1]
	local root = tree:root()

	return callback(root)
end

return M
