<h1 align="center">vv-dashboard.nvim</h1>

<p align="center">
  <em>极简 Neovim 启动页 — 单 buffer、非浮窗、与侧栏天然共存</em>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Neovim-0.10+-57A143?style=flat-square&logo=neovim&logoColor=white" alt="Requires Neovim 0.10+" />
  <img src="https://img.shields.io/badge/Lua-2C2D72?style=flat-square&logo=lua&logoColor=white" alt="Lua" />
</p>

---

## 安装

```lua
{
  'beixiyo/vv-dashboard.nvim',
  dependencies = { 'beixiyo/vv-utils.nvim' },
  event = 'VimEnter',
  ---@type VVDashboardConfig
  opts = {
    header = nil,           -- 多行 ASCII art（string 按 \n 分割，string[] 逐行）
    keys = {
      { icon = '󰈚', key = 'r', desc = '最近文件', action = 'Telescope oldfiles' },
      { icon = '󰈞', key = 'f', desc = '查找文件', action = 'Telescope find_files' },
      { icon = '', key = 'g', desc = '全局搜索', action = 'Telescope live_grep' },
      { icon = '', key = 'q', desc = '退出',     action = 'qa' },
    },
    footer = nil,           -- fun(): VVDashboardChunk[] | string | nil
    auto_open = true,       -- 启动时无参数 + 空 buffer 自动打开
    filetype = 'dashboard', -- dashboard buffer 的 filetype
    width = 60,             -- keys 区域容器宽度（两端对齐基准）
    key_gap = 1,            -- keys 之间的空行数
    section_gap = 2,        -- header / keys / footer 之间的空行数
  },
}
```

## 配置

| 选项 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `header` | `string \| string[]` | *VSCode ASCII art* | 头部多行文本 |
| `keys` | `VVDashboardKey[]` | `{}` | 快捷键列表：`{ icon?, key, desc, action }` |
| `footer` | `fun(): VVDashboardChunk[] \| string \| nil` | `nil` | 底部内容，支持多色片段 `{ text, hl_group }[]` |
| `auto_open` | `boolean` | `true` | `VimEnter` 时无参数 + 空 buffer 自动打开 |
| `filetype` | `string` | `'dashboard'` | buffer filetype |
| `width` | `integer` | `60` | keys 区域容器宽度 |
| `key_gap` | `integer` | `1` | keys 之间的空行数 |
| `section_gap` | `integer` | `2` | 三段之间的空行数 |
| `highlights` | `VVDashboardHighlights` | *见源码* | 各段高亮组名（header / icon / desc / key / footer） |
