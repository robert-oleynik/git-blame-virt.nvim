local M = {
	utils = {}
}

function M.utils.extract(node, types, D)
	local d = 0
	if D then
		d = D
	end
	local chunks = {}
	for child in node:iter_children() do
		if child:child_count() > 0 then
			local cchunks = M.utils.extract(child, types, d + 1)
			for _,c in ipairs(cchunks) do
				table.insert(chunks, c)
			end
		end

		if vim.g.git_blame.debug then
			print(string.rep('  ', d), child, child:range())
		end

		for _,ty in ipairs(types) do
			if child:type() == ty then
				local first, _, last, _ = child:range()
				table.insert(chunks, {
					type = ty,
					first = first + 1,
					last = last + 1
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
function M.lua(node)
	return M.utils.extract(node, {'function_decleration'})
end

-- Extract all rust functions, impl blocks and structs as range from `node`.
function M.rust(node)
	return M.utils.extract(node, {'function_item', 'impl_item', 'struct_item'})
end

return M
