-- Chooses an ordinary content window without depending on the facade.

local M = {}
local sidebar_filetypes = { ['vv-explorer'] = true }

function M.pick()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_get_config(win).relative == '' then
      local buf = vim.api.nvim_win_get_buf(win)
      if not sidebar_filetypes[vim.bo[buf].filetype] then return win end
    end
  end

  vim.cmd('rightbelow vnew')
  return vim.api.nvim_get_current_win()
end

return M
