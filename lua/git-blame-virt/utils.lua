-- SPDX-License-Identifier: BSD-2-Clause
--
-- Copyright (c) 2022 Robert Oleynik

local M = {}

function M.debug(...)
	local config = require("git-blame-virt").config
	if not config.debug then
		return
	end
	local msg = ""
	for _, v in ipairs({ ... }) do
		msg = msg .. tostring(v) .. " "
	end
	print(msg)
end

function M.error(...)
	local msg = ""
	for _, v in ipairs({ ... }) do
		msg = msg .. tostring(v) .. " "
	end
	msg = msg .. "\n"
	vim.api.nvim_err_writeln(msg)
end

---Checks if an input string starts with a 40-byte hex sha1 string.
---
---@param input (string) Input to check.
---@return (bool) Returns true if input matches hex string.
function M.begins_with_sha1(input)
	return input:match("^" .. string.rep("%x", 40))
end

---Add element to set if not already added.
---
---@param set (table) Set to insert element to.
---@parma el (object) Element to add to set.
function M.set_insert(set, el)
	for _, e in ipairs(set) do
		if e == el then
			return
		end
	end
	table.insert(set, el)
end

---Join array of strings with seperator.
---
---@param array (table) Array to join together.
---@param sep (string) String seperator.
---@return (string) Returns joined string.
function M.join(array, sep)
	local result = ""
	for i, v in ipairs(array) do
		result = result .. v
		if i ~= #array then
			result = result .. sep
		end
	end
	return result
end

---Check if array contains element e.
---
---@param array (table) Array to search element in.
---@param e (object) Element to search for.
---@return (bool) Return true if element was found and false if not.
function M.contians(array, e)
	for _, el in ipairs(array) do
		if el == e then
			return true
		end
	end
	return false
end

---Find element e in array arr.
---
---@param arr (table) Array to search element in.
---@param e (object) Element to search for.
---@return (number|nil) Returns index of found element and nil if no matching element was found.
function M.find(arr, e)
	for i, el in ipairs(arr) do
		if el == e then
			return i
		end
	end
	return nil
end

function M.rel_time_str(timestamp)
	local time = os.time({
		day = 1,
		month = 1,
		year = 1970,
		hour = 0,
		min = 0,
		sec = timestamp,
	})
	local now = os.time(os.date("!*t"))
	local diff = os.difftime(now, time)
	local u = diff
	if diff < 60 then
		unit = "second"
	elseif diff < 3600 then
		u = (diff / 60)
		unit = "minute"
	elseif diff < 86400 then
		u = (diff / 3600)
		unit = "hour"
	elseif diff < 2592000 then
		u = (diff / 86400)
		unit = "day"
	elseif diff < 31536000 then
		u = (diff / 2592000)
		unit = "month"
	else
		u = (diff / 31536000)
		unit = "year"
	end
	u = math.floor(u * 10) / 10
	if math.abs(u - 1) >= 0.1 then
		unit = unit .. "s"
	end
	return u .. " " .. unit
end

return M
