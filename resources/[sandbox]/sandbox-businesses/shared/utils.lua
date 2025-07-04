function deepcopy(orig)
	local orig_type = type(orig)
	local copy
	if orig_type == "table" then
		copy = {}
		for orig_key, orig_value in next, orig, nil do
			copy[deepcopy(orig_key)] = deepcopy(orig_value)
		end
		setmetatable(copy, deepcopy(getmetatable(orig)))
	else -- number, string, boolean, etc
		copy = orig
	end
	return copy
end

local function pluralize(word, amount)
    if not amount or amount > 1 then
        return word .. 's'
    end
    return word
end

function GetFormattedTimeFromSeconds(seconds)
    local days = 0
    local hours = Utils:Round(seconds / 3600, 0)
    if hours >= 24 then
        days = math.floor(hours / 24)
        hours = math.ceil(hours - (days * 24))
    end

    local timeString
    if days > 0 or hours > 0 then
        if days > 1 then
            if hours > 0 then
                timeString = string.format('%d %s and %d %s', days, pluralize('day', days), hours, pluralize('hour', hours))
            else
                timeString = string.format('%d %s', days, pluralize('day', days))
            end
        else
            timeString = string.format('%d %s', hours, pluralize('hour', hours))
        end
    else
        local minutes = Utils:Round(seconds / 60, 0)
        timeString = string.format('%d %s', minutes, pluralize('minute', minutes))
    end
    return timeString
end