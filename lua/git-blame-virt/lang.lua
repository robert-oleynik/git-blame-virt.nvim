-- SPDX-License-Identifier: BSD-2-Clause
--
-- Copyright (c) 2022 Robert Oleynik

local M = {}
local treesitter = require'git-blame-virt.treesitter'
local utils = require'git-blame-virt.utils'

M.ts_queries = {
	lua = [[
	(function_declaration) @node
	]],
	java = [[
	(method_declaration) @node
	(class_declaration) @node
	(constructor_declaration) @node
	]],
	javascript = [[
	(function_declaration) @node
	]],
	latex = [[
	(chapter) @node
	(section) @node
	(subsection) @node
	(subsubsection) @node
	]],
	python = [[
	(function_definition) @node
	(class_definition) @node
	]]
}

M.ts_symbols = {
	lua = {
		'function'
	},
	rust = {
		'function',
		'mod',
		'enum',
		'struct',
		'macro',
		'trait_item'
	},
	cpp = {
		'struct',
		'class',
		'template',
		'function'
	},
	java = {
		'method',
		'class'
	},
	javascript = {
		'function'
	},
	latex = {
		'chapter',
		'section',
		'subsection',
		'subsubsection'
	},
	python = {
		'function',
		'class'
	}
}

M.queries = {
	rust = {
		'(function_item)',
		'(mod_item body: (_))',
		'(enum_item)',
		'(struct_item)',
		'(macro_definition)',
		'(trait_item)'
	},
	cpp = {
		'(struct_specifier)',
		'(class_specifier)',
		'(template_declaration)',
		'(function_definition)',
	}
}

M.fn = {}

local function parse_rust()
	local sym = M.ts_symbols.rust
	local queries = M.queries.rust

	local query_str = ''
	for _, q in ipairs(queries) do
		query_str = query_str .. string.format([[
			(
				(attribute_item)+
				.
				%s @id
			) @node
			%s @node
		]], q, q)
	end
	local query = vim.treesitter.query.parse_query('rust', query_str)

	M.fn['rust'] = function(bufnr)
		bufnr = bufnr or 0
		if query == nil then
			utils.error('Invalid query (language: rust)')
		end

		return treesitter.run(bufnr, function(root)
			local ids = {}
			local result = {}
			for id, nodes, _ in query:iter_matches(root, bufnr) do
				local symbol = sym[math.floor((id - 1) / 2) + 1]
				local first_line, _, last_line, _ = nodes[2]:range()
				local r = { symbol, first_line, last_line }

				if nodes[1] ~= nil then
					local i = utils.find(ids, nodes[1]:id())
					if i then
						ids[i] = nodes[1]:id()
						result[i] = r
					else
						table.insert(ids, nodes[1]:id())
						table.insert(result, r)
					end
				else
					local i = utils.find(ids, nodes[2]:id())
					if not i then
						table.insert(ids, nodes[2]:id())
						table.insert(result, r)
					end
				end
			end
			return result
		end)
	end
end

local function parse_cpp()
	local sym = M.ts_symbols.cpp
	local queries = M.queries.cpp

	local query_str = [[
	(namespace_definition) @node
	]]
	for _, q in ipairs(queries) do
		query_str = query_str .. string.format([[
			(template_declaration %s @id) @node
			%s @node
		]], q, q)
	end
	local query = vim.treesitter.query.parse_query('cpp', query_str)

	M.fn.cpp = function(bufnr)
		bufnr = bufnr or 0
		if query == nil then
			utils.error('Invalid query (language: cpp)')
		end

		return treesitter.run(bufnr, function(root)
			local ids = {}
			local result = {}
			for id, nodes, _ in query:iter_matches(root, bufnr) do
				local first_line, _, last_line, _ = nodes[1]:range()
				if id == 1 then
					table.insert(result, { 'namespace', first_line, last_line })
				else
					local symbol = sym[math.floor((id - 1) / 2)]
					local r = { symbol, first_line, last_line }

					if nodes[2] ~= nil then
						local i = utils.find(ids, nodes[2]:id())
						if i then
							ids[i] = nodes[2]:id()
							result[i] = r
						else
							table.insert(ids, nodes[2]:id())
							table.insert(result, r)
						end
					else
						local i = utils.find(ids, nodes[1]:id())
						if not i then
							table.insert(ids, nodes[1]:id())
							table.insert(result, r)
						end
					end
				end
			end
			return result
		end)
	end
end

---Setup TreeSitter queries.
function M.setup()
	for lang, query in pairs(M.ts_queries) do
		M.fn[lang] = M.fn[lang] or treesitter.parse_query(lang, query, M.ts_symbols[lang])
	end
	parse_rust()
	parse_cpp()
end

return M
