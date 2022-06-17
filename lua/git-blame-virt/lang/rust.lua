local M = {}

local utils = require'git-blame-virt.utils'

-- Returns list of chunks (first and last line, indent and TreeSitter type)
function M.ts_chunks(node)
	local chunks = {}
	local attribute = 0
	for child in node:iter_children() do
		local first, indent, last, _ = child:range()
		if attribute ~= 0 then
			first = attribute
		end
		if child:type() == 'attribute_item' then
			attribute = first
		elseif child:type() == 'struct_item' or
			child:type() == 'enum_item' or
			child:type() == 'function_item' or
			child:type() == 'macro_definition' then
			table.insert(chunks, {
				type = child:type(),
				first = first + 1,
				last = last + 1,
				indent = indent,
			})
			attribute = 0
		elseif child:type() == 'impl_item' or child:type() == 'mod_item' then
			if first ~= last then
				table.insert(chunks, {
					type = child:type(),
					first = first + 1,
					last = last + 1,
				})
				local sub_chunks = M.ts_chunks(child)
				chunks = utils.append(chunks, sub_chunks)
				attribute = 0
			end
		else
			local sub_chunks = M.ts_chunks(child)
			chunks = utils.append(chunks, sub_chunks)
		end
	end
	return chunks
end

return M
