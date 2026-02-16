vim.api.nvim_create_user_command("SiuYankImport", function() 
    local cursor_pos = vim.fn.getpos(".")
    local bufnr, line, col = unpack(cursor_pos)

    local siu = require("scala-import-utils")
    ---@type siu.FullyQualifiedIdentifier|nil
    local identifier
    if vim.bo.filetype == "scala" then
        identifier = siu.get_fully_qualified_identifier(bufnr, {line - 1, col - 1})
    elseif vim.bo.buftype == "quickfix" then
        local qf_item_index = vim.fn.getpos(".")[2]
        identifier = siu.get_import_from_qf_list(qf_item_index)
    end

    if identifier ~= nil then
        vim.fn.setreg("", "import " .. tostring(identifier) .. "\n")
    end
end, {})

vim.api.nvim_create_user_command("SiuOrganizeImport", function()
    local siu = require("scala-import-utils")
    local line = vim.fn.getpos(".")[2]
    local destination_line = siu.organize_import(0, line - 1)
    vim.fn.cursor(destination_line + 1, 1)
end, {})

vim.api.nvim_set_keymap("n", "<Plug>SiuYankImport", ":SiuYankImport<CR>", {})
vim.api.nvim_set_keymap("n", "<Plug>SiuOrganizeImport", ":SiuOrganizeImport<CR>", {})
