local M = {}
local utils = require'git-blame-virt.utils'

function M.ts_chunks(node)
	local chunks = {}
	for child in node:iter_children() do
		local first, _, last, _ = child:range()
		if child:type() == 'chapter' or
			child:type() == 'section' or
			child:type() == 'subsection' or
			child:type() == 'subsubsection' then
			table.insert(chunks, {
				type = child:type(),
				first = first,
				last = last
			})
		end
		
		if child:child_count() > 0 then
			local sub_chunks = M.ts_chunks(child)
			chunks = utils.append(chunks, sub_chunks)
		end
	end
	return chunks
end

return M
