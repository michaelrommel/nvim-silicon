local M = {}

M.gobble = function(lines)
	local shortest_whitespace = nil
	local whitespace = ""
	for _, v in pairs(lines) do
		_, _, whitespace = string.find(v, "^(%s*)")
		if type(whitespace) ~= "nil" then
			if shortest_whitespace == nil or (#whitespace < #shortest_whitespace and v ~= "") then
				shortest_whitespace = whitespace
			end
		end
	end
	if #shortest_whitespace > 0 then
		local newlines = {}
		for _, v in pairs(lines) do
			local newline = string.gsub(v, "^" .. shortest_whitespace, "", 1)
			table.insert(newlines, newline)
		end
		return newlines
	else
		return lines
	end
end

M.dump = function(t)
	local conv = {
		["nil"] = function() return "nil" end,
		["number"] = function(n) return tostring(n) end,
		["string"] = function(s) return '"' .. s .. '"' end,
		["boolean"] = function(b) return tostring(b) end
	}
	if type(t) == "table" then
		local s = "{"
		for k, v in pairs(t) do
			if type(v) == "table" then
				s = s .. (s == "{" and " " or ", ") .. (k .. " = " .. M.dump(v))
			else
				s = s .. (s == "{" and " " or ", ") .. k .. " = " .. conv[type(v)](v)
			end
		end
		return s .. " }"
	else
		return conv[type(t)](t)
	end
end

return M
