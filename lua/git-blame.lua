local M = {}

function M.setup(options)
	if vim.g.git_blame == nil then
		vim.g.git_blame = {}
	end

	if options == nil then
		options = {}
	end

	local defaults = {
		git_blame = {
			debug = false
		}
	}

	vim.g.git_blame = vim.tbl_deep_extend('keep', options, vim.g.git_blame, defaults)
end

return M
