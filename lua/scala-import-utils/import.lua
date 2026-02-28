---@class siu.Import
---@field path string[]
---@field namespace_selectors string[]|'*'
---@field line number 0-based index
local Import = {}
Import.__index = Import

---@return siu.Import
function Import:new(path, namespace_selectors, line)
	local o = setmetatable({}, Import)

	o.path = path
	o.namespace_selectors = namespace_selectors
	o.line = line

	return o
end

---@param import_declaration_node TSNode
---@param source number|string
---@return siu.Import
function Import.from_import_declaration_node(import_declaration_node, source)
	---@type string[]
	local import_path = {}
	---@type string[]|'*'
	local namespace_selectors = nil

	for node, name in import_declaration_node:iter_children() do
		if name == "path" then
			local text = vim.treesitter.get_node_text(node, source)
			if text ~= "." then
				table.insert(import_path, text)
			end
		elseif node:type() == "namespace_selectors" then
			assert(namespace_selectors == nil)
			for namespace_selector_identifer_node, _ in node:iter_children() do
				if namespace_selector_identifer_node:type() == "identifier" then
					if namespace_selectors == nil then
						namespace_selectors = {}
					end
					local text = vim.treesitter.get_node_text(namespace_selector_identifer_node, source)
					table.insert(namespace_selectors, text)
				end
			end
		elseif node:type() == "namespace_wildcard" then
			assert(namespace_selectors == nil)
			namespace_selectors = "*"
		end
	end

	if namespace_selectors == nil then
		namespace_selectors = { import_path[#import_path] }
		import_path[#import_path] = nil
	end

	local line = import_declaration_node:range()

	return Import:new(import_path, namespace_selectors, line)
end

---@param path1 string[]
---@param path2 string[]
function Import.compare_paths(path1, path2)
	for i = 1, math.min(#path1, #path2) do
		local segment1 = path1[i]
		local segment2 = path2[i]
		if segment1 < segment2 then
			return -1
		elseif segment1 > segment2 then
			return 1
		end
	end
	if #path1 > #path2 then
		return 1
	elseif #path1 < #path2 then
		return -1
	end
	return 0
end

function Import:merge(other_import)
	if Import.compare_paths(self.path, other_import.path) ~= 0 then
		return { self, other_import }
	else
		if self.namespace_selectors == "*" or other_import.namespace_selectors == "*" then
			return Import:new(self.path, "*", self.line)
		else
			---@type {[string]: any}
			local selectors_set = {}
			for _, selector in ipairs(self.namespace_selectors) do
				selectors_set[selector] = true
			end
			for _, selector in ipairs(other_import.namespace_selectors) do
				selectors_set[selector] = true
			end
			local selectors = vim.tbl_keys(selectors_set)
			table.sort(selectors)

			return Import:new(self.path, selectors, self.line)
		end
	end
end

function Import.__tostring(import)
	---@type string
	local selectors_str = ""
	if import.namespace_selectors == "*" then
		selectors_str = "*"
	else
		local sorted_selectors = { unpack(import.namespace_selectors) }
		table.sort(sorted_selectors)

		local template
		if #sorted_selectors == 1 then
			template = "%s"
		else
			template = "{%s}"
		end
		selectors_str = string.format(template, table.concat(sorted_selectors, ", "))
	end

	---@type string[]
	local parts = { unpack(import.path) }
	table.insert(parts, selectors_str)

	return "import " .. table.concat(parts, ".")
end

return Import
