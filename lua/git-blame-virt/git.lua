-- SPDX-License-Identifier: BSD-2-Clause
--
-- Copyright (c) 2022 Robert Oleynik

local M = {}
local utils = require("git-blame-virt.utils")

--- Read blame information of file stored in buffer `bufnr` by calling git blame asynchronous.
---
---@param bufnr (number|nil) Number of buffer to parse information from. Use `nil` or `0` for
---  current buffer.
---@param callback (fun(table)) Function to call then git blame is finished and parsed.
function M.async_read_blame(bufnr, callback)
	local config = require("git-blame-virt").config
	local job = require("plenary.job")
	local path = require("plenary.path")

	bufnr = bufnr or 0
	local filename = vim.api.nvim_buf_get_name(bufnr)
	utils.debug("git-blame parse file:", filename)

	if not path:new(filename):exists() then
		return
	end

	local workdir = config.allow_foreign_repos and path:new(filename):parent().filename or vim.env.CWD
	utils.debug("workdir:", workdir)

	job:new({
		command = "git",
		args = {
			"blame",
			"-s",
			"--incremental",
			"--date",
			"unix",
			"--",
			filename,
		},
		cwd = workdir,
		on_exit = vim.schedule_wrap(function(j, return_value)
			if return_value ~= 0 then
				utils.debug("git blame: exited with", return_value)
				utils.debug("stderr:")
				for _, line in ipairs(j:stderr_result()) do
					utils.debug(line)
				end
				return
			end
			utils.debug("git blame: exited with", return_value)
			local info = M.parse_git_blame(j:result())
			if type(callback) ~= "function" then
				utils.error("git-blame-virt.git.async_read_blame: callback is not a function")
				return
			end
			callback(info)
		end),
	}):start()
end

--- Parse lines printed by git blame.
---
---@param lines (table) Lines stored as a table of strings.
---@return (table) TODO
function M.parse_git_blame(lines)
	local result = {
		commits = {},
		lines = {},
	}
	local current_commit = nil
	for i, line in ipairs(lines) do
		if utils.begins_with_sha1(line) then
			local hash, _, first_line, num_lines = line:match("(%x+)%s(%d+)%s(%d+)%s(%d+)")
			result.commits[hash] = result.commits[hash] or {}
			current_commit = hash

			first_line = tonumber(first_line)
			num_lines = tonumber(num_lines)
			for i = first_line, first_line + num_lines - 1 do
				result.lines[i] = hash
			end
		else
			local is_committer = line:match("^committer%s")
			local is_timestamp = line:sub(1, 14) == "committer-time"
			local is_summary = line:match("^summary%s")
			-- utils.debug(i, current_commit, line)
			if is_committer then
				local committer = line:sub(11, -1)
				result.commits[current_commit].committer = committer
			elseif is_timestamp then
				local timestamp = line:sub(16, -1)
				result.commits[current_commit].timestamp = tonumber(timestamp)
			elseif is_summary then
				local summary = line:sub(9, -1)
				result.commits[current_commit].summary = summary
			end
		end
	end
	-- utils.debug(vim.inspect(result))
	return setmetatable(result, {
		__call = function(self, first_line, last_line)
			local result = {
				committers = {},
				last = {
					hash = "",
					timestamp = 0,
					summary = "",
				},
			}
			for i = first_line, last_line do
				local hash = self.lines[i]
				local commit = self.commits[hash]
				if commit then
					utils.set_insert(result.committers, commit.committer)
					if result.last.timestamp <= commit.timestamp and hash ~= string.rep("0", 40) then
						result.last.hash = hash
						result.last.timestamp = commit.timestamp
						result.last.summary = commit.summary
					end
				end
			end
			return result
		end,
	})
end

return M
