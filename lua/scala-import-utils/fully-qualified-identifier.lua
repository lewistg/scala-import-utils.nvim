---@class siu.FullyQualifiedIdentifier
---@field path string[]
---@field name string
local FullyQualifiedIdentifier = {}
FullyQualifiedIdentifier.__index = FullyQualifiedIdentifier

---@param path string[]
---@param name string
---@return siu.FullyQualifiedIdentifier
function FullyQualifiedIdentifier:new(path, name)
	local o = setmetatable({}, FullyQualifiedIdentifier)

	o.path = path
	o.name = name

	return o
end

function FullyQualifiedIdentifier.__tostring(fully_qualified_identifier)
	local segments = { unpack(fully_qualified_identifier.path) }
	table.insert(segments, fully_qualified_identifier.name)
	return table.concat(segments, ".")
end

return FullyQualifiedIdentifier
