--- vv-dashboard.nvim 变更测试
--- 运行: nvim --headless -u NONE -l tests/test_smoke.lua

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

-- ─── 汇总 ──────────────────────────────────────────────────────────────

print(string.format('\n结果: %d passed, %d failed', passed, failed))
if failed > 0 then os.exit(1) end
