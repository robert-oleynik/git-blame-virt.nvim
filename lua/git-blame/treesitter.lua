local M = {}

-- Returns a list of all functions found by TreeSitter
--
-- Result:
-- ```
-- {
--    {
--		 first = <line>,
--		 last = <line>
--    },
-- }
-- ```
function M.functions(bufnr)
	local lang = require'lua.git-blame.treesitter.lang'
	local ft = vim.api.nvim_buf_get_option(bufnr, 'filetype')
	if type(lang[ft]) == 'function' then
		local parser = vim.treesitter.get_parser(bufnr)
		local tree = parser:parse()[1]
		return lang[ft](tree:root())
	end
	return nil
end

return M
