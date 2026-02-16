---@class siu.Queries
---@field package_query
---@field class_identifier_query
---@field object_identifier_query
---@field import_query

---@type {[string]: fun}
local _queries = {
	package_query = function()
		---@type string
		local query_src = [[
        (compilation_unit
            (package_clause
                name: (package_identifier) @package-identifier))
        ]]
		return vim.treesitter.query.parse("scala", query_src)
	end,
	class_identifier_query = function()
		---@type string
		local query_src = [[
        (compilation_unit
            (class_definition
                name: (identifier) @class-name))
        ]]
		return vim.treesitter.query.parse("scala", query_src)
	end,
	object_identifier_query = function()
		local query_src = [[
        (compilation_unit
            (object_definition
                name: (identifier) @object-name))
        ]]
		return vim.treesitter.query.parse("scala", query_src)
	end,
	import_query = function()
		local query_src = [[
        (compilation_unit (import_declaration) @import-declaration)
        ]]
		return vim.treesitter.query.parse("scala", query_src)
	end,
}

---@type siu.Queries
local queries = setmetatable({}, {
	__index = function(table, key)
		if _queries[key] ~= nil then
			table[key] = _queries[key]()
			return table[key]
		end
		return nil
	end,
})

return queries
