-- Pure dashboard layout plus buffer and extmark rendering

local M = {}
local namespace = vim.api.nvim_create_namespace('vv-dashboard')

local function display_width(value)
  return vim.fn.strdisplaywidth(value)
end

local function centered_padding(total, content)
  return math.max(0, math.floor((total - content) / 2))
end

local function padded(value, columns)
  return value .. string.rep(' ', math.max(0, columns - display_width(value)))
end

local function add_gap(lines, count)
  for _ = 1, count do lines[#lines + 1] = '' end
end

local function header_lines(config)
  if type(config.header) == 'string' then
    return vim.split(config.header, '\n', { plain = true, trimempty = true })
  end
  return config.header or {}
end

local function footer_chunks(config)
  if not config.footer then return {} end
  local result = config.footer()
  if type(result) == 'string' then
    return { { result, config.highlights.footer } }
  end
  if type(result) == 'table' and type(result[1]) == 'table' then return result end
  return {}
end

function M.render(session, config)
  if not session
    or not vim.api.nvim_buf_is_valid(session.buf)
    or not vim.api.nvim_win_is_valid(session.win)
  then
    return
  end

  local buf = session.buf
  local win = session.win
  local lines = {}
  local marks = {}
  local win_width = vim.api.nvim_win_get_width(win)
  local win_height = vim.api.nvim_win_get_height(win)
  local headers = header_lines(config)

  for _, text in ipairs(headers) do
    local left = centered_padding(win_width, display_width(text))
    lines[#lines + 1] = string.rep(' ', left) .. text
    marks[#marks + 1] = { #lines - 1, left, left + #text, config.highlights.header }
  end

  if #headers > 0 and #config.keys > 0 then add_gap(lines, config.section_gap) end

  local max_description = 0
  for _, item in ipairs(config.keys) do
    max_description = math.max(max_description, display_width(item.desc or ''))
  end

  for index, item in ipairs(config.keys) do
    local icon = item.icon or ''
    local description = item.desc or ''
    local key = item.key or ''
    local icon_block = padded(icon, 2)
    local description_block = padded(description, max_description)
    local occupied = display_width(icon_block .. ' ' .. description_block) + display_width(key)
    local gap = math.max(1, config.width - occupied)
    local row = icon_block .. ' ' .. description_block .. string.rep(' ', gap) .. key
    local left = centered_padding(win_width, display_width(row))

    lines[#lines + 1] = string.rep(' ', left) .. row
    local row_index = #lines - 1
    local offset = left

    if #icon > 0 then
      marks[#marks + 1] = { row_index, offset, offset + #icon, config.highlights.icon }
    end
    offset = offset + #icon_block + 1
    marks[#marks + 1] = {
      row_index,
      offset,
      offset + #description,
      config.highlights.desc,
    }
    offset = offset + #description_block + gap
    marks[#marks + 1] = { row_index, offset, offset + #key, config.highlights.key }

    if index < #config.keys then add_gap(lines, config.key_gap) end
  end

  local footer = footer_chunks(config)
  if #config.keys > 0 and #footer > 0 then add_gap(lines, config.section_gap) end
  if #footer > 0 then
    local text = ''
    local offsets = {}
    for _, chunk in ipairs(footer) do
      offsets[#offsets + 1] = #text
      text = text .. (chunk[1] or '')
    end

    local left = centered_padding(win_width, display_width(text))
    lines[#lines + 1] = string.rep(' ', left) .. text
    for index, chunk in ipairs(footer) do
      if chunk[2] and #(chunk[1] or '') > 0 then
        marks[#marks + 1] = {
          #lines - 1,
          left + offsets[index],
          left + offsets[index] + #chunk[1],
          chunk[2],
        }
      end
    end
  end

  local top = centered_padding(win_height, #lines)
  for _ = 1, top do table.insert(lines, 1, '') end

  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_clear_namespace(buf, namespace, 0, -1)
  for _, mark in ipairs(marks) do
    pcall(vim.api.nvim_buf_set_extmark, buf, namespace, mark[1] + top, mark[2], {
      end_col = mark[3],
      hl_group = mark[4],
    })
  end
  vim.bo[buf].modifiable = false

  local section_offset = #headers > 0 and config.section_gap or 0
  local cursor = #config.keys > 0
      and top + #headers + section_offset + 1
    or top + 1
  pcall(vim.api.nvim_win_set_cursor, win, { cursor, 0 })
end

return M
