local M = {}
local utils = require'git-blame-virt.utils'

function M.ts_chunks(node)
	local chunks = {}
	for child in node:iter_children() do
		local first, _, last, _ = child:range()
		if child:type() == 'function_declaration' or child:type() == 'method_declaration' then
			table.insert(chunks, {
				type = child:type(),
				first = first,
				last = last
			})
		end
		if child:child_count() > 0 then
			local cchunks = M.ts_chunks(child)
			chunks = utils.append(chunks, cchunks)
		end
	end
	return chunks
end

return M