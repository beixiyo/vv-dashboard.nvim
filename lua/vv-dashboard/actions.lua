-- Buffer-local key bindings and post-close action execution.

local M = {}

function M.bind(buf, keys, close)
  for _, item in ipairs(keys or {}) do
    if item.key and item.action then
      vim.keymap.set('n', item.key, function()
        close()
        vim.schedule(function()
          if type(item.action) == 'function' then return item.action() end
          if type(item.action) == 'string' then return vim.cmd(item.action) end
        end)
      end, { buffer = buf, nowait = true, silent = true, desc = 'dashboard: ' .. (item.desc or '') })
    end
  end

  local used = {}
  for _, item in ipairs(keys or {}) do used[item.key] = true end
  for _, key in ipairs({ 'i', 'I', 'a', 'A', 'o', 'O', 's', 'S', 'c', 'C', 'R' }) do
    if not used[key] then vim.keymap.set('n', key, '<Nop>', { buffer = buf, nowait = true, silent = true }) end
  end
end

return M
