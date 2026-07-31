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

local function autocmd_count(group)
  local ok, autocmds = pcall(vim.api.nvim_get_autocmds, { group = group })
  return ok and #autocmds or 0
end

test('后续 setup 可取消同 tick 已排队的 auto-open', function()
  local dashboard = require('vv-dashboard')
  dashboard.setup({ auto_open = true })
  dashboard.setup({ auto_open = false })

  vim.wait(50)
  eq(require('vv-dashboard.state').is_open(), nil, '旧 auto-open 不应穿透新配置')

  dashboard.setup({ auto_open = true })
  assert(vim.wait(1000, function()
    return require('vv-dashboard.state').is_open()
  end), '当前 generation 的 auto-open 应正常打开')
  dashboard.close()
end)

test('restores every taken-over window option on close and external wipe', function()
  local dashboard = require('vv-dashboard')
  local win = vim.api.nvim_get_current_win()
  vim.wo[win].number = true
  vim.wo[win].relativenumber = true
  vim.wo[win].signcolumn = 'yes'
  vim.wo[win].foldcolumn = '2'
  vim.wo[win].wrap = true
  dashboard.setup({ auto_open = false })
  dashboard.open()
  dashboard.close()
  eq(
    autocmd_count('vv_dashboard_session'),
    0,
    'close releases session listeners'
  )
  eq(vim.wo[win].number, true, 'close restores number')
  eq(vim.wo[win].relativenumber, true, 'close restores relativenumber')
  eq(vim.wo[win].signcolumn, 'yes', 'close restores signcolumn')
  eq(vim.wo[win].foldcolumn, '2', 'close restores foldcolumn')
  eq(vim.wo[win].wrap, true, 'close restores wrap')

  dashboard.open()
  vim.cmd('enew')
  eq(vim.wo[win].number, true, 'external replacement restores number')
  eq(vim.wo[win].signcolumn, 'yes', 'external replacement restores signcolumn')
  eq(
    autocmd_count('vv_dashboard_session'),
    0,
    'external replacement releases session listeners'
  )
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

-- ─── 汇总 ──────────────────────────────────────────────────────────────

print(string.format('\n结果: %d passed, %d failed', passed, failed))
if failed > 0 then os.exit(1) end
