local M = {}
local utils = require'git-blame-virt.utils'

function M.ts_chunks(node)
	local chunks = {}
	local template = node:type() == 'template_declaration'
	for child in node:iter_children() do
		local first, _, last, _ = child:range()
		if child:type() == 'function_definition' or child:type() == 'preproc_function_def' then
			if not template then
				table.insert(chunks, {
					type = child:type(),
					first = first + 1,
					last = last + 1,
				})
			end
		else
			if child:type() == 'namespace_definition' or
				child:type() == 'template_declaration' or
				(child:type() == 'class_specifier' and not template) or
				(child:type() == 'struct_specifier' and not template) then
				table.insert(chunks, {
					type = child:type(),
					first = first + 1,
					last = last + 1,
				})
			end
			local cchunks = M.ts_chunks(child)
			chunks = utils.append(chunks, cchunks)
		end
	end
	return chunks
end

return M
