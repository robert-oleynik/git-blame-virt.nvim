local M = {}

-- Append rhs to end of lhs. Returns result of this. Expects rhs, lhs of type array.
function M.append(lhs, rhs)
	for _,e in ipairs(rhs) do
		table.insert(lhs, e)
	end
	return lhs
end

return M
