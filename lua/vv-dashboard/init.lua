-- vv-dashboard.nvim — 极简自实现启动页
--
-- 设计：
--   * 单 buffer（nofile + bufhidden=wipe），**占用一个常规窗口**（非浮窗）
--     这样 vv-explorer 等侧栏可与 dashboard 天然共存；Neovim 的浮窗始终在
--     常规窗之上，float 模式下 explorer 会被全屏 dashboard 视觉盖掉
--   * 自动挑选"主区域窗"：跳过 vv-explorer 等 filetype 的侧栏；都不是则新开 vsplit
--   * 手动关闭装饰 wo（number/rnu/cursorline/signcolumn/foldcolumn/list/spell/statuscolumn/wrap）
--     —— 常规窗没有浮窗的 style='minimal' 特权
--   * 选中 key 触发 action：先 M.close() 把 dashboard 所在窗替换为空 buffer，
--     再 schedule 执行 action（如 :Telescope / :edit）
--   * 三段结构：header（多行 ASCII）/ keys（图标+按键+描述）/ footer（富文本一行）
--   * 每行按 display width 居中；整体按窗口高度垂直居中
--   * VimEnter 自动开启（无参数 + 空 buffer + 无 restored 文件 buffer）
--   * VimResized / WinResized 自动重新居中（常规窗尺寸跟随布局，不需要改几何）
--
-- 配置见 defaults；用户主要写 header / keys / footer 三项。
--
-- Actions 支持：
--   * function：直接调
--   * string：:cmd 或 cmd 都行

local M = {}
local ns = vim.api.nvim_create_namespace('vv-dashboard')

---@class VVDashboardKey
---@field icon? string
---@field key string
---@field desc string
---@field action string|function

---@class VVDashboardChunk
---@field [1] string 文本
---@field [2]? string 高亮组

---@class VVDashboardHighlights
---@field header string  header 渲染用的 hl 组名，默认 'Title'
---@field icon string    keys 行 icon 的 hl 组名，默认 'Special'
---@field desc string    keys 行描述文字的 hl 组名，默认 'Normal'
---@field key string     keys 行按键的 hl 组名，默认 'Constant'
---@field footer string  footer 段（纯文本场景）的 hl 组名，默认 'Comment'

---@class VVDashboardConfig
---@field header string|string[]
---@field keys VVDashboardKey[]
---@field footer? fun(): VVDashboardChunk[]|string  返回单行多色片段或纯文本
---@field auto_open boolean  启动时无参数 + 空 buffer 则自动开，默认 true
---@field filetype string  默认 'dashboard'（与 file-tree 的 close_on_filetype 对应）
---@field width integer     block 宽度（两端对齐的容器宽度），默认 60
---@field key_gap integer   keys 之间空行数，默认 1
---@field section_gap integer  header/keys/footer 之间空行数，默认 2
---@field highlights VVDashboardHighlights  各段高亮组名；直接指向标准 hl 组，用户可覆盖
local defaults = {
  header = [[
██╗   ██╗███████╗ ██████╗ ██████╗ ███████╗ ███████╗
██║   ██║██╔════╝██╔════╝██╔═══██╗██╔═══██╗██╔════╝
██║   ██║███████╗██║     ██║   ██║██║   ██║█████╗
╚██╗ ██╔╝╚════██║██║     ██║   ██║██║   ██║██╔══╝
 ╚████╔╝ ███████║╚██████╗╚██████╔╝███████╔╝███████╗
  ╚═══╝  ╚══════╝ ╚═════╝ ╚═════╝  ╚═════╝ ╚══════╝]],
  keys = {},
  footer = nil,
  auto_open = true,
  filetype = 'dashboard',
  width = 60,
  key_gap = 1,
  section_gap = 2,
  highlights = {
    header = 'Title',
    icon   = 'Special',
    desc   = 'Normal',
    key    = 'Constant',
    footer = 'Comment',
  },
}

local config = defaults
local state = nil ---@type { buf:integer, win:integer }?

-- ─── utils ───────────────────────────────────────────────────────────────

local function strw(s) return vim.fn.strdisplaywidth(s) end

local function pad_cols(s, target_cols)
  local w = strw(s)
  if w >= target_cols then return s end
  return s .. string.rep(' ', target_cols - w)
end

local function center_pad(total, content_w)
  return math.max(0, math.floor((total - content_w) / 2))
end

-- ─── render ─────────────────────────────────────────────────────────────

local function render()
  if not state or not vim.api.nvim_buf_is_valid(state.buf) then return end
  if not vim.api.nvim_win_is_valid(state.win) then return end
  local buf, win = state.buf, state.win

  local width  = vim.api.nvim_win_get_width(win)
  local height = vim.api.nvim_win_get_height(win)

  local lines = {}
  local hls = {} ---@type { row:integer, col:integer, end_col:integer, hl:string }[]

  local hl = config.highlights

  -- header（多行居中，整体用 config.highlights.header）
  local header_lines = type(config.header) == 'string'
    and vim.split(config.header, '\n', { plain = true, trimempty = true })
    or (config.header or {})
  for _, h in ipairs(header_lines) do
    local pad = center_pad(width, strw(h))
    local line = string.rep(' ', pad) .. h
    lines[#lines + 1] = line
    hls[#hls + 1] = { row = #lines - 1, col = pad, end_col = pad + #h, hl = hl.header }
  end

  -- section 之间空行（header 和 keys 之间）
  if #header_lines > 0 and #config.keys > 0 then
    for _ = 1, config.section_gap do lines[#lines + 1] = '' end
  end

  -- keys 区（block width = 60，行间 gap，两端对齐）
  --   [icon_slot][sp][desc_padded][              fill              ][key]
  -- 每个 key 之间插入 key_gap 行空行
  if #config.keys > 0 then
    local ICON_SLOT = 2
    local block_w = config.width

    local max_desc_w = 0
    for _, k in ipairs(config.keys) do
      local w = strw(k.desc or '')
      if w > max_desc_w then max_desc_w = w end
    end

    for idx, k in ipairs(config.keys) do
      local icon = k.icon or ''
      local desc = k.desc or ''
      local key  = k.key or ''
      local icon_block = pad_cols(icon, ICON_SLOT)
      local desc_padded = desc .. string.rep(' ', max_desc_w - strw(desc))
      local left_text = icon_block .. ' ' .. desc_padded
      local gap = math.max(1, block_w - strw(left_text) - strw(key))
      local row_text = left_text .. string.rep(' ', gap) .. key

      local pad = center_pad(width, strw(row_text))
      local line = string.rep(' ', pad) .. row_text
      lines[#lines + 1] = line
      local lnum = #lines - 1

      -- 用累积 byte offset 精确定位各段，避免 display-width 与 byte-length 混淆
      local byte_off = pad  -- 前置空格 bytes = 显示宽度
      if #icon > 0 then
        hls[#hls + 1] = { row = lnum, col = byte_off, end_col = byte_off + #icon, hl = hl.icon }
      end
      byte_off = byte_off + #icon_block + 1 -- icon_block bytes + 1sp
      hls[#hls + 1] = { row = lnum, col = byte_off, end_col = byte_off + #desc, hl = hl.desc }
      byte_off = byte_off + #desc_padded + gap
      hls[#hls + 1] = { row = lnum, col = byte_off, end_col = byte_off + #key, hl = hl.key }

      -- key 之间的空行（最后一个 key 不加）
      if idx < #config.keys then
        for _ = 1, config.key_gap do lines[#lines + 1] = '' end
      end
    end
  end

  -- section 之间空行（keys 和 footer 之间）
  if #config.keys > 0 and config.footer then
    for _ = 1, config.section_gap do lines[#lines + 1] = '' end
  end

  -- footer（单行多片段，或纯文本）
  if config.footer then
    local result = config.footer()
    local chunks ---@type VVDashboardChunk[]
    if type(result) == 'string' then
      chunks = { { result, hl.footer } }
    elseif type(result) == 'table' then
      -- 判断是否已是 { { text, hl }, ... } 结构
      if #result > 0 and type(result[1]) == 'table' then
        chunks = result
      else
        chunks = {}
      end
    else
      chunks = {}
    end

    if #chunks > 0 then
      local text, offsets = '', {}
      for _, c in ipairs(chunks) do
        offsets[#offsets + 1] = #text
        text = text .. (c[1] or '')
      end
      local pad = center_pad(width, strw(text))
      lines[#lines + 1] = string.rep(' ', pad) .. text
      local lnum = #lines - 1
      for i, c in ipairs(chunks) do
        local t = c[1] or ''
        local hl = c[2]
        if hl and #t > 0 then
          hls[#hls + 1] = {
            row = lnum,
            col = pad + offsets[i],
            end_col = pad + offsets[i] + #t,
            hl = hl,
          }
        end
      end
    end
  end

  -- 垂直居中
  local top_pad = center_pad(height, #lines)
  for _ = 1, top_pad do table.insert(lines, 1, '') end
  for _, h in ipairs(hls) do h.row = h.row + top_pad end

  -- 写入
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  for _, h in ipairs(hls) do
    pcall(vim.api.nvim_buf_set_extmark, buf, ns, h.row, h.col, {
      end_col = h.end_col, hl_group = h.hl,
    })
  end
  vim.bo[buf].modifiable = false

  -- 光标放在首个 key 行（避免停在空白上的空虚感）
  local key_first_lnum = top_pad + #header_lines + (#header_lines > 0 and config.section_gap or 0) + 1
  pcall(vim.api.nvim_win_set_cursor, win, { key_first_lnum, 0 })
end

-- ─── actions ────────────────────────────────────────────────────────────

-- 关闭浮窗 → 焦点自动回到底层主窗口 → schedule 执行 action
-- schedule 是必要的：M.close 会触发 BufWipeout autocmd，下一次事件循环才稳定
local function exec_action(action)
  M.close()
  vim.schedule(function()
    if type(action) == 'function' then return action() end
    if type(action) == 'string' then return vim.cmd(action) end
  end)
end

local function bind_keys(buf)
  for _, k in ipairs(config.keys or {}) do
    if k.key and k.action then
      vim.keymap.set('n', k.key, function() exec_action(k.action) end, {
        buffer = buf, nowait = true, silent = true, desc = 'dashboard: ' .. (k.desc or ''),
      })
    end
  end
end

-- 选一个"主区域窗"给 dashboard 占用：跳过 vv-explorer 这类侧栏；都是侧栏就开新 vsplit
local SIDEBAR_FTS = { ['vv-explorer'] = true }
local function pick_target_win()
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local cfg = vim.api.nvim_win_get_config(w)
    if cfg.relative == '' then
      local b = vim.api.nvim_win_get_buf(w)
      if not SIDEBAR_FTS[vim.bo[b].filetype] then
        return w
      end
    end
  end
  vim.cmd('rightbelow vnew')
  return vim.api.nvim_get_current_win()
end

-- 常规窗下没有 style='minimal'，显式设置 window-local 选项关闭装饰
local function apply_minimal_wo(win)
  local wo = {
    number = false, relativenumber = false,
    cursorline = false, cursorcolumn = false,
    signcolumn = 'no', foldcolumn = '0',
    list = false, spell = false,
    statuscolumn = '', wrap = false,
  }
  for k, v in pairs(wo) do
    vim.api.nvim_set_option_value(k, v, { scope = 'local', win = win })
  end
end

-- ─── public ─────────────────────────────────────────────────────────────

function M.open()
  -- 已经开着 → 聚焦既有窗，避免重复
  if state and state.buf and vim.api.nvim_buf_is_valid(state.buf)
    and state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_set_current_win(state.win)
    return
  end

  local target_win = pick_target_win()
  local prev_buf = vim.api.nvim_win_get_buf(target_win)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype   = 'nofile'
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].swapfile  = false
  vim.bo[buf].buflisted = false
  vim.bo[buf].filetype  = config.filetype

  -- 把 dashboard buffer 载入目标窗，并把焦点切过去
  vim.api.nvim_win_set_buf(target_win, buf)
  vim.api.nvim_set_current_win(target_win)
  apply_minimal_wo(target_win)

  -- 清理被 displace 的 startup [No Name]（也包括 pick_target_win 的 vnew 兜底产物）
  -- 严格判定空 [No Name]：不影响用户的 :enew 笔记
  require('vv-utils.bufdelete').wipe_if_throwaway(prev_buf)

  state = { buf = buf, win = target_win }
  render()
  bind_keys(buf)

  -- <Esc> 关闭 dashboard
  vim.keymap.set('n', '<Esc>', function() M.close() end, {
    buffer = buf, nowait = true, silent = true, desc = 'dashboard: close',
  })

  -- 尺寸变化 / 布局变化（比如 <leader>e 开 explorer 后 dashboard 窗变窄）→ 重新居中
  local aug = vim.api.nvim_create_augroup('vv-dashboard.' .. buf, { clear = true })
  vim.api.nvim_create_autocmd({ 'VimResized', 'WinResized' }, {
    group = aug,
    callback = function()
      if not (state and state.buf == buf and vim.api.nvim_buf_is_valid(buf)) then return end
      if not vim.api.nvim_win_is_valid(state.win) then return end
      render()
    end,
  })

  -- buf 销毁（用户 :bdelete / :edit file 替换 / 其他路径）→ 清 state
  vim.api.nvim_create_autocmd({ 'BufWipeout', 'BufDelete' }, {
    group = aug,
    buffer = buf,
    once = true,
    callback = function() state = nil end,
  })
end

function M.close()
  if not (state and state.buf and vim.api.nvim_buf_is_valid(state.buf)) then
    state = nil
    return
  end
  local buf, win = state.buf, state.win
  state = nil
  -- 把 dashboard 所在窗换成一个空 buffer（即使该窗是唯一窗也安全）
  -- bufhidden=wipe 会在 dashboard buffer 不再被任何窗显示时自动清理
  if vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_call(win, function() vim.cmd('enew') end)
  end
  -- 兜底：极端路径下若 buffer 仍存活，强制清
  if vim.api.nvim_buf_is_valid(buf) then
    pcall(vim.api.nvim_buf_delete, buf, { force = true })
  end
end

-- VimEnter 时自动判断是否开启
local function auto_open_check()
  if vim.fn.argc() ~= 0 then return end
  -- 任何已 restore 的带名文件 buffer（auto-session 等）→ 视为有活，跳过 dashboard
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[b].buflisted and vim.api.nvim_buf_get_name(b) ~= '' then return end
  end
  local buf = vim.api.nvim_get_current_buf()
  if vim.api.nvim_buf_get_name(buf) ~= '' then return end
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  if #lines > 1 or (lines[1] and lines[1] ~= '') then return end
  M.open()
end

function M.setup(opts)
  config = vim.tbl_deep_extend('force', defaults, opts or {})

  vim.api.nvim_create_user_command('VVDashboard', function() M.open() end, {})
  vim.api.nvim_create_user_command('VVDashboardClose', function() M.close() end, {})

  if config.auto_open then
    if vim.v.vim_did_enter == 1 then
      vim.schedule(auto_open_check)
    else
      vim.api.nvim_create_autocmd('VimEnter', {
        callback = auto_open_check,
        once = true,
      })
    end
  end
end

return M
