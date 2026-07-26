-- Autocommand ownership for one dashboard session and setup-time auto-open

local M = {}

local session_group_name = 'vv_dashboard_session'
local setup_group_name = 'vv_dashboard_setup'

function M.clear_session()
  pcall(vim.api.nvim_del_augroup_by_name, session_group_name)
end

---@param buf integer
---@param render fun()
---@param on_close fun()
function M.bind_session(buf, render, on_close)
  local group = vim.api.nvim_create_augroup(session_group_name, { clear = true })

  vim.api.nvim_create_autocmd({ 'VimResized', 'WinResized' }, {
    group = group,
    callback = render,
  })

  vim.api.nvim_create_autocmd({ 'BufWipeout', 'BufDelete' }, {
    group = group,
    buffer = buf,
    once = true,
    callback = function()
      M.clear_session()
      on_close()
    end,
  })
end

---@param enabled boolean
---@param open fun()
function M.configure_auto_open(enabled, open)
  local group = vim.api.nvim_create_augroup(setup_group_name, { clear = true })
  if not enabled then return end

  if vim.v.vim_did_enter == 1 then
    vim.schedule(open)
    return
  end

  vim.api.nvim_create_autocmd('VimEnter', {
    group = group,
    once = true,
    callback = open,
  })
end

return M
