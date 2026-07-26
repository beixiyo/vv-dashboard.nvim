-- Public dashboard facade: configuration, composition and lifecycle only

local Actions = require('vv-dashboard.actions')
local Lifecycle = require('vv-dashboard.lifecycle')
local Render = require('vv-dashboard.render')
local State = require('vv-dashboard.state')
local Target = require('vv-dashboard.target')
local Window = require('vv-dashboard.window')

local M = {}

local defaults = {
  header = [[
██╗   ██╗███████╗ ██████╗ ██████╗ ███████╗ ███████╗
██║   ██║██╔════╝██╔════╝██╔═══██╗██╔═══██╗██╔════╝
██║   ██║███████╗██║     ██║   ██║██║   ██║█████╗
╚██╗ ██╔╝╚════██║██║     ██║   ██║██║   ██║██╔══╝
 ╚████╔╝ ███████║╚██████╗╚██████╔╝███████╔╝███████╗
  ╚═══╝  ╚══════╝ ╚═════╝╚═════╝ ╚══════╝╚══════╝]],
  keys = {},
  footer = nil,
  auto_open = true,
  filetype = 'dashboard',
  width = 60,
  key_gap = 1,
  section_gap = 2,
  highlights = {
    header = 'Title',
    icon = 'Special',
    desc = 'Normal',
    key = 'Constant',
    footer = 'Comment',
  },
}

local config = vim.deepcopy(defaults)

local function render()
  Render.render(State.get(), config)
end

local function release_session(session)
  if not session then return end
  Window.restore(session.win, session.window_options)
  State.clear(session.buf)
end

function M.open()
  if State.is_open() then
    vim.api.nvim_set_current_win(State.get().win)
    return
  end

  local win = Target.pick()
  local previous = vim.api.nvim_win_get_buf(win)
  local buf = vim.api.nvim_create_buf(false, true)

  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].swapfile = false
  vim.bo[buf].buflisted = false
  vim.bo[buf].filetype = config.filetype

  vim.api.nvim_win_set_buf(win, buf)
  vim.api.nvim_set_current_win(win)

  local session = {
    buf = buf,
    win = win,
    window_options = Window.take_over(win),
  }
  State.set(session)

  require('vv-utils.bufdelete').wipe_if_throwaway(previous)
  render()
  Actions.bind(buf, config.keys, M.close)
  Lifecycle.bind_session(buf, render, function()
    release_session(session)
  end)
end

function M.close()
  local session = State.get()
  if not State.is_open() then
    Lifecycle.clear_session()
    State.clear()
    return
  end

  Lifecycle.clear_session()
  release_session(session)
  vim.api.nvim_win_call(session.win, function()
    vim.cmd('enew')
  end)

  if vim.api.nvim_buf_is_valid(session.buf) then
    pcall(vim.api.nvim_buf_delete, session.buf, { force = true })
  end
end

function M.toggle()
  if State.is_open() then
    M.close()
  else
    M.open()
  end
end

local function auto_open()
  if vim.fn.argc() ~= 0 then return end

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buf].buflisted and vim.api.nvim_buf_get_name(buf) ~= '' then return end
  end

  local buf = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local has_content = #lines > 1 or (lines[1] and lines[1] ~= '')
  if vim.api.nvim_buf_get_name(buf) == '' and not has_content then M.open() end
end

---@param opts? VVDashboardConfig
function M.setup(opts)
  config = vim.tbl_deep_extend('force', vim.deepcopy(defaults), opts or {})

  local commands = {
    VVDashboardOpen = M.open,
    VVDashboardClose = M.close,
    VVDashboardToggle = M.toggle,
  }
  for name, callback in pairs(commands) do
    vim.api.nvim_create_user_command(name, callback, { force = true })
  end

  Lifecycle.configure_auto_open(config.auto_open, auto_open)
end

---@class VVDashboardKey
---@field icon? string  快捷键图标 @default nil
---@field key string  触发按键
---@field desc string  操作描述
---@field action string|fun()  Vim 命令或回调函数

---@class VVDashboardChunk
---@field [1] string  文本
---@field [2]? string  高亮组 @default nil

---@class VVDashboardHighlights
---@field header? string  header 高亮组 @default 'Title'
---@field icon? string  快捷键图标高亮组 @default 'Special'
---@field desc? string  操作描述高亮组 @default 'Normal'
---@field key? string  按键高亮组 @default 'Constant'
---@field footer? string  footer 纯文本高亮组 @default 'Comment'

---@class VVDashboardConfig
---@field header? string|string[]  标题内容 @default built-in ASCII art
---@field keys? VVDashboardKey[]  快捷键列表 @default {}
---@field footer? fun(): VVDashboardChunk[]|string  footer 内容 @default nil
---@field auto_open? boolean  空启动时自动打开 @default true
---@field filetype? string  Dashboard buffer filetype @default 'dashboard'
---@field width? integer  内容区域宽度 @default 60
---@field key_gap? integer  快捷键之间的空行数 @default 1
---@field section_gap? integer  区块之间的空行数 @default 2
---@field highlights? VVDashboardHighlights  各区域高亮配置 @default built-in highlight groups

return M
