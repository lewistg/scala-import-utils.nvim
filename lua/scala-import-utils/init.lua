local M = {}

---@param node TSNode
---@param position [number, number]
---@return boolean
local function node_contains_position(node, position)
	local pos_row, pos_col = unpack(position)
	local row1, col1, row2, col2 = node:range()
	if pos_row < row1 or pos_row > row2 then
		return false
	elseif pos_row == row1 and pos_col < col1 then
		return false
	elseif pos_row == row2 and pos_col > col2 then
		return false
	end
	return true
end

---@type vim.treesitter.LanguageTree
---@return string[]
local function get_package_path(tree, source)
	local queries = require("scala-import-utils.queries")
	---@type string[]
	local path = {}
	for id, node, metadata in queries.package_query:iter_captures(tree:root(), source) do
		local text = vim.treesitter.get_node_text(node, source)
		if text ~= "." then
			for segment in vim.gsplit(text, ".", { plain = true }) do
				table.insert(path, segment)
			end
		end
	end
	return path
end

---@param source string|number A file name or buffer ID
---@param position [number, number] Indexes should be 0-based
---@return siu.FullyQualifiedIdentifier|nil
function M.get_fully_qualified_identifier(source, position)
	---@type vim.treesitter.LanguageTree
	local tree
	if type(source) == "number" then
		tree = vim.treesitter.get_parser(source):parse()[1]
	else
		tree = vim.treesitter.get_string_parser(source, "scala"):parse()[1]
	end

	local queries = require("scala-import-utils.queries")

	---@typevim.treesitter.Query[]
	local identifier_queries = {
		queries.class_identifier_query,
		queries.object_identifier_query,
	}

	---@type string|nil
	local identifier_name = vim.iter(identifier_queries):fold(nil, function(name, query)
		if name ~= nil then
			return name
		else
			---@type string|nil
			for id, node, metadata in query:iter_captures(tree:root(), source) do
				vim.print(node)
				if node_contains_position(node, position) then
					return vim.treesitter.get_node_text(node, source)
				end
			end
		end
	end)

	if identifier_name ~= nil then
		local path = get_package_path(tree, source)
		local FullyQualifiedIdentifier = require("scala-import-utils.fully-qualified-identifier")
		return FullyQualifiedIdentifier:new(path, identifier_name)
	end
	return nil
end

---@param bufnr
---@param new_import siu.Import
function M.add_import(bufnr, new_import)
	local queries = require("scala-import-utils.queries")
	local tree = vim.treesitter.get_parser(bufnr):parse()[1]

	---@type siu.Import[]
	local imports = {}

	local Import = require("scala-import-utils.import")
	for id, import_declaration_node, metadata in queries.import_query:iter_captures(tree:root(), bufnr) do
		local import = Import.from_import_declaration_node(import_declaration_node, bufnr)
		table.insert(imports, import)
	end

	local mergeable_import = vim.iter(imports):find(function(import)
		return Import.compare_paths(import.path, new_import.path) == 0
	end)

	if mergeable_import ~= nil then
		local merged_import = mergeable_import:merge(new_import)
		assert(merged_import)
		vim.api.nvim_buf_set_lines(bufnr, import.line, import.line + 1, true, { tostring(merged_import) })
	else
		---@type number
		local line
		local first_greater = vim.iter(imports):find(function(import)
			return Import.compare_paths(import.path, new_import.path) > 0
		end)
		if first_greater then
			line = first_greater.line - 1
		elseif #imports > 0 then
			line = imports[#imports].line
		else
			-- default insert spot
			line = 2
		end
		vim.api.nvim_buf_set_lines(bufnr, line, line, false, { tostring(new_import) })
	end
end

function M.get_import_from_qf_list(item_index)
	if vim.bo.buftype ~= "quickfix" then
		return nil
	end

	local qf_item = vim.fn.getqflist({
		idx = item_index,
		items = true,
	}).items[1]

	if qf_item == nil or not qf_item.valid then
		return nil
	end

	---@type number|string
	local source
	if vim.api.nvim_buf_is_loaded(qf_item.bufnr) then
		source = qf_item.bufnr
	else
		local file = io.open(vim.fn.bufname(qf_item.bufnr), "r")
		assert(file)
		source = file:read("*a")
	end

	local fully_qualified_identifier = M.get_fully_qualified_identifier(source, { qf_item.lnum - 1, qf_item.col - 1 })

	return fully_qualified_identifier
end

---@param line_index 0-based
function M.organize_import(bufnr, line_index)
	local queries = require("scala-import-utils.queries")
	local tree = vim.treesitter.get_parser(bufnr):parse()[1]

	---@type siu.Import|nil
	local source_import = nil
	---@type siu.Import[]
	local other_imports = {}

	local Import = require("scala-import-utils.import")
	for id, import_declaration_node, metadata in queries.import_query:iter_captures(tree:root(), bufnr) do
		local import = Import.from_import_declaration_node(import_declaration_node, bufnr)
		if import.line == line_index then
			source_import = import
		else
			table.insert(other_imports, import)
		end
	end

	if source_import == nil then
		return line_index
	end

	local mergeable_import = vim.iter(other_imports):find(function(import)
		return Import.compare_paths(import.path, source_import.path) == 0
	end)

	---@type number
	local destination_line = source_import.line

	if mergeable_import ~= nil then
		local merged_import = mergeable_import:merge(source_import)
		assert(merged_import)
		vim.api.nvim_buf_set_lines(
			bufnr,
			mergeable_import.line,
			mergeable_import.line + 1,
			true,
			{ tostring(merged_import) }
		)
		vim.api.nvim_buf_set_lines(bufnr, source_import.line, source_import.line + 1, true, {})
		if source_import.line < mergeable_import.line then
			destination_line = mergeable_import.line - 1
		else
			destination_line = mergeable_import.line
		end
	else
		local first_greater = vim.iter(other_imports):find(function(import)
			return Import.compare_paths(import.path, source_import.path) > 0
		end)

		---@type number|nil
		local insert_line = nil
		if first_greater then
			insert_line = first_greater.line
		elseif #other_imports > 0 then
			insert_line = other_imports[#other_imports].line + 1
		end
		if insert_line then
			vim.api.nvim_buf_set_lines(bufnr, insert_line, insert_line, false, { tostring(source_import) })
			---@type number
			local deletion_line
			if source_import.line > insert_line then
				deletion_line = source_import.line + 1
			else
				deletion_line = source_import.line
			end
			vim.api.nvim_buf_set_lines(bufnr, deletion_line, deletion_line + 1, false, {})
			if deletion_line < insert_line then
				destination_line = insert_line - 1
			else
				destination_line = insert_line
			end
		end
	end

	return destination_line
end

return M
