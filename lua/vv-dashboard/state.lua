-- Dashboard session owner. No other module retains dashboard buffer/window state.

local M = {}
local current

function M.get()
  return current
end

function M.set(session)
  current = session
end

function M.clear(buf)
  if not buf or (current and current.buf == buf) then current = nil end
end

function M.is_open()
  return current
    and vim.api.nvim_buf_is_valid(current.buf)
    and vim.api.nvim_win_is_valid(current.win)
end

return M
