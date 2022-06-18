local M = {}

-- Append rhs to end of lhs. Returns result of this. Expects rhs, lhs of type array.
function M.append(lhs, rhs)
	for _,e in ipairs(rhs) do
		table.insert(lhs, e)
	end
	return lhs
end

-- Returns approximate relative time to current of Unix timestamp.
function M.approx_rel_time(timestamp)
	local commit_time = os.time({
		day = 1,
		month = 1,
		year = 1970,
		hour = 0,
		min = 0,
		sec = timestamp
	})
	local now = os.time(os.date("!*t"))
	local diff = os.difftime(now, commit_time)
	local u = diff
	local unit = nil
	if diff < 60 then
		unit = 'second'
	elseif diff < 3600 then
		u = (diff / 60)
		unit = 'minute'
	elseif diff < 86400 then
		u = (diff / 3600)
		unit = 'hour'
	elseif diff < 2592000 then
		u = (diff / 86400)
		unit = 'day'
	elseif diff < 31536000 then
		u = (diff / 2592000)
		unit = 'month'
	else
		u = (diff / 31536000)
		unit = 'year'
	end
	u = math.floor(u * 10) / 10;
	if math.abs(u - 1) >= 0.1 then
		unit = unit .. 's'
	end
	return u, unit
end

return M
