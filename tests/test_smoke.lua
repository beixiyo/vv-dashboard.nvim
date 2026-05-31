--- vv-dashboard.nvim 变更测试
--- 运行: nvim --headless -u NONE -l tests/test_smoke.lua

-- -u NONE 下 runtimepath 被剥离，手动把本插件与 vv-utils 的 lua/ 接进 package.path
-- 镜像兄弟插件的 package.path 写法：用本文件路径推算 plugin 根
local this = debug.getinfo(1, 'S').source:sub(2)          -- tests/test_smoke.lua 可能是相对路径
local plugin_root = vim.fn.fnamemodify(this, ':p:h:h')    -- → plugin 绝对根目录
local vendors = vim.fn.fnamemodify(plugin_root, ':h')     -- → vendors 目录
package.path = table.concat({
  plugin_root .. '/lua/?.lua',
  plugin_root .. '/lua/?/init.lua',
  vendors .. '/vv-utils.nvim/lua/?.lua',
  vendors .. '/vv-utils.nvim/lua/?/init.lua',
  vendors .. '/vv-icons.nvim/lua/?.lua',
  vendors .. '/vv-icons.nvim/lua/?/init.lua',
  package.path,
}, ';')

local passed = 0
local failed = 0

local function test(name, fn)
  local ok, err = pcall(fn)
  if ok then
    passed = passed + 1
    print('  PASS  ' .. name)
  else
    failed = failed + 1
    print('  FAIL  ' .. name .. ': ' .. tostring(err))
  end
end

local function eq(a, b, msg)
  if a ~= b then
    error(string.format('%s: expected %s, got %s', msg or 'mismatch', tostring(b), tostring(a)))
  end
end

-- ─── FIX 2: 多字节图标高亮偏移量 ──────────────────────────────────────

print('\n[FIX 2] 多字节图标高亮偏移量')

local strw = vim.fn.strdisplaywidth

local function pad_cols(s, target_cols)
  local w = strw(s)
  if w >= target_cols then return s end
  return s .. string.rep(' ', target_cols - w)
end

test('pad_cols: 1-display-width icon (4 bytes) 补 1 空格', function()
  local icon = '󰈚'  -- 4 bytes, 1 display width (NerdFont)
  eq(#icon, 4, 'icon is 4 bytes')
  eq(strw(icon), 1, 'icon is 1 display width')
  local block = pad_cols(icon, 2)
  eq(strw(block), 2, 'display width padded to 2')
  eq(#block, #icon + 1, 'byte length = icon bytes + 1 padding space')
end)

test('pad_cols: 1-display-width icon (3 bytes) 补 1 空格', function()
  local icon = '▸'  -- 3 bytes, 1 display width
  eq(#icon, 3, 'icon is 3 bytes')
  eq(strw(icon), 1, 'icon is 1 display width')
  local block = pad_cols(icon, 2)
  eq(strw(block), 2, 'display width padded to 2')
  eq(#block, #icon + 1, 'byte length = icon bytes + 1 padding space')
end)

test('pad_cols: 2-display-width emoji 不加空格', function()
  local icon = '🔍'  -- 4 bytes, 2 display width
  eq(#icon, 4, 'emoji is 4 bytes')
  eq(strw(icon), 2, 'emoji is 2 display width')
  local block = pad_cols(icon, 2)
  eq(strw(block), 2, 'display width already 2')
  eq(#block, #icon, 'byte length = icon bytes (no padding)')
end)

test('byte_off 追踪: 4-byte NerdFont icon 行各段偏移正确', function()
  local ICON_SLOT = 2
  local icon = '󰈚'  -- 4 bytes, 1 display width
  local desc = 'Recent files'
  local key = 'r'
  local max_desc_w = strw(desc)

  local icon_block = pad_cols(icon, ICON_SLOT)
  local desc_padded = desc .. string.rep(' ', max_desc_w - strw(desc))
  local left_text = icon_block .. ' ' .. desc_padded
  local gap = math.max(1, 60 - strw(left_text) - strw(key))
  local row_text = left_text .. string.rep(' ', gap) .. key

  local pad = 10  -- 模拟居中 padding
  local line = string.rep(' ', pad) .. row_text

  -- 按 byte_off 方式计算
  local byte_off = pad
  local icon_start = byte_off
  local icon_end = byte_off + #icon
  byte_off = byte_off + #icon_block + 1
  local desc_start = byte_off
  local desc_end = byte_off + #desc
  byte_off = byte_off + #desc_padded + gap
  local key_start = byte_off
  local key_end = byte_off + #key

  -- 验证: 从 line 中按 byte offset 截取应与原始文本一致
  eq(line:sub(icon_start + 1, icon_end), icon, 'icon 截取')
  eq(line:sub(desc_start + 1, desc_end), desc, 'desc 截取')
  eq(line:sub(key_start + 1, key_end), key, 'key 截取')
end)

test('byte_off 追踪: 3-byte UTF-8 icon 行各段偏移正确', function()
  local ICON_SLOT = 2
  local icon = '▸'  -- 3 bytes, 1 display width
  local desc = 'Find'
  local key = 'f'
  local max_desc_w = 12

  local icon_block = pad_cols(icon, ICON_SLOT)
  local desc_padded = desc .. string.rep(' ', max_desc_w - strw(desc))
  local left_text = icon_block .. ' ' .. desc_padded
  local gap = math.max(1, 60 - strw(left_text) - strw(key))
  local row_text = left_text .. string.rep(' ', gap) .. key

  local pad = 5
  local line = string.rep(' ', pad) .. row_text

  local byte_off = pad
  local icon_start = byte_off
  local icon_end = byte_off + #icon
  byte_off = byte_off + #icon_block + 1
  local desc_start = byte_off
  local desc_end = byte_off + #desc
  byte_off = byte_off + #desc_padded + gap
  local key_start = byte_off
  local key_end = byte_off + #key

  eq(line:sub(icon_start + 1, icon_end), icon, 'icon 截取')
  eq(line:sub(desc_start + 1, desc_end), desc, 'desc 截取')
  eq(line:sub(key_start + 1, key_end), key, 'key 截取')
end)

test('byte_off 追踪: 纯 ASCII icon 行偏移正确', function()
  local ICON_SLOT = 2
  local icon = '>'
  local desc = 'Quit'
  local key = 'q'
  local max_desc_w = 12

  local icon_block = pad_cols(icon, ICON_SLOT)
  local desc_padded = desc .. string.rep(' ', max_desc_w - strw(desc))
  local left_text = icon_block .. ' ' .. desc_padded
  local gap = math.max(1, 60 - strw(left_text) - strw(key))
  local row_text = left_text .. string.rep(' ', gap) .. key

  local pad = 8
  local line = string.rep(' ', pad) .. row_text

  local byte_off = pad
  eq(line:sub(byte_off + 1, byte_off + #icon), icon, 'icon 截取')
  byte_off = byte_off + #icon_block + 1
  eq(line:sub(byte_off + 1, byte_off + #desc), desc, 'desc 截取')
  byte_off = byte_off + #desc_padded + gap
  eq(line:sub(byte_off + 1, byte_off + #key), key, 'key 截取')
end)

-- ─── FIX 57: <Nop> 防插入键不能覆盖 action 键 ──────────────────────────

print('\n[FIX 57] <Nop> 不覆盖 action 键')

-- 取某 buffer 上 normal 模式下 lhs 的映射；返回 maparg 字典或 nil
local function buf_map(buf, lhs)
  for _, m in ipairs(vim.api.nvim_buf_get_keymap(buf, 'n')) do
    if m.lhs == lhs then return m end
  end
  return nil
end

test('action 键 c 保留 callback，不被 <Nop> 覆盖；未占用键 i 仍是 <Nop>', function()
  local dash = require('vv-dashboard')
  dash.setup({
    auto_open = false,
    keys = {
      { key = 'c', desc = 'Config', action = function() end },
    },
  })
  dash.open()
  local buf = vim.api.nvim_get_current_buf()

  local mc = buf_map(buf, 'c')
  if not mc then error('action 键 c 没有任何 <buffer> 映射') end
  -- action 映射是 Lua callback；被 <Nop> 覆盖后 callback 会消失、rhs 变 <Nop>
  if not mc.callback then
    error('action 键 c 被 <Nop> 覆盖了（callback 丢失，rhs=' .. tostring(mc.rhs) .. '）')
  end

  -- 未占用键 i 仍应被映射为 <Nop>：在 keymap 列表里、无 callback、rhs 为空（Neovim 这样表示 <Nop>）
  local mi = buf_map(buf, 'i')
  if not mi then error('未占用键 i 应被映射为 <Nop>') end
  if mi.callback then error('未占用键 i 不应是 action callback') end
  eq(mi.rhs or '', '', 'i 应映射为 <Nop>（rhs 为空）')

  dash.close()
end)

-- ─── FIX 58: header 存在但 keys 为空时光标公式不溢出 ────────────────────

print('\n[FIX 58] keys 为空时光标落在有效内容行')

test('setup({ keys={}, header 多行, footer }) render 后光标在范围内且非顶部空白', function()
  local dash = require('vv-dashboard')
  dash.setup({
    auto_open = false,
    keys = {},
    header = '行1\n行2\n行3\n行4\n行5\n行6',
    footer = function() return 'hello' end,
  })
  dash.open()
  local win = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_get_current_buf()

  local line_count = vim.api.nvim_buf_line_count(buf)
  local cur = vim.api.nvim_win_get_cursor(win)
  local lnum = cur[1]

  -- 溢出 bug 下 pcall 吞错，光标停在第 1 行（顶部空白）
  if lnum < 1 or lnum > line_count then
    error('光标 ' .. lnum .. ' 越界（buffer 共 ' .. line_count .. ' 行）')
  end
  -- 该行应是内容行（首个 header 行），非空白
  local text = vim.api.nvim_buf_get_lines(buf, lnum - 1, lnum, false)[1] or ''
  if text:match('^%s*$') then
    error('光标落在空白行 ' .. lnum .. '（应为内容行）')
  end

  dash.close()
end)

-- ─── FIX 59: exec_action 上方注释纠正为常规窗语义 ──────────────────────

print('\n[FIX 59] exec_action 注释去除浮窗措辞')

test('源码中 exec_action 注释不再出现误导性的 浮窗 / 底层主窗', function()
  local path = plugin_root .. '/lua/vv-dashboard/init.lua'
  local fh = assert(io.open(path, 'r'))
  local src = fh:read('*a')
  fh:close()

  -- 只截取紧贴 exec_action 上方的连续 `--` 注释块（逐行向上收集，遇非注释行停止）
  local lines = vim.split(src, '\n', { plain = true })
  local def_idx
  for i, l in ipairs(lines) do
    if l:find('^local function exec_action') then def_idx = i break end
  end
  if not def_idx then error('未找到 exec_action 定义') end
  local block = {}
  for i = def_idx - 1, 1, -1 do
    if lines[i]:find('^%s*%-%-') then
      table.insert(block, 1, lines[i])
    else
      break
    end
  end
  local region = table.concat(block, '\n')
  if region == '' then error('未找到 exec_action 注释区域') end

  if region:find('浮窗') then
    error('exec_action 注释仍含误导措辞「浮窗」')
  end
  if region:find('底层主窗') then
    error('exec_action 注释仍含误导措辞「底层主窗」')
  end
end)

-- ─── 汇总 ──────────────────────────────────────────────────────────────

print(string.format('\n结果: %d passed, %d failed', passed, failed))
if failed > 0 then os.exit(1) end
