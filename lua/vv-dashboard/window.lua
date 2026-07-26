-- Owns the dashboard's window-local option takeover.

local M = {}

local options = {
  'number', 'relativenumber', 'cursorline', 'cursorcolumn', 'signcolumn',
  'foldcolumn', 'list', 'spell', 'statuscolumn', 'wrap',
}

local minimal = {
  number = false, relativenumber = false, cursorline = false, cursorcolumn = false,
  signcolumn = 'no', foldcolumn = '0', list = false, spell = false,
  statuscolumn = '', wrap = false,
}

function M.take_over(win)
  local snapshot = {}
  for _, name in ipairs(options) do
    snapshot[name] = vim.api.nvim_get_option_value(name, { scope = 'local', win = win })
    vim.api.nvim_set_option_value(name, minimal[name], { scope = 'local', win = win })
  end
  return snapshot
end

function M.restore(win, snapshot)
  if not snapshot or not vim.api.nvim_win_is_valid(win) then return end
  for name, value in pairs(snapshot) do
    pcall(vim.api.nvim_set_option_value, name, value, { scope = 'local', win = win })
  end
end

return M
