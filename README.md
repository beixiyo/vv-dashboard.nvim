# vv-dashboard.nvim

极简自实现 Neovim 启动页。单 buffer（`nofile` + `bufhidden=wipe`）占用一个常规窗口（非浮窗），可与 `vv-explorer` 等侧栏天然共存。

![screenshot](https://img.shields.io/badge/screenshot-placeholder-lightgrey)

## 特性

- 三段结构：**header**（多行 ASCII art）/ **keys**（图标 + 按键 + 描述）/ **footer**（富文本单行）
- 每行按 display width 水平居中，整体按窗口高度垂直居中
- `VimResized` / `WinResized` 自动重绘
- `VimEnter` 无参数 + 空 buffer 时自动打开
- 选中 key 触发 action 后自动关闭 dashboard

## 依赖

- [vv-utils.nvim](https://github.com/beixiyo/vv-utils.nvim) — 使用 `vv-utils.bufdelete` 清理被 dashboard 替换的空 buffer

## 安装

### lazy.nvim

```lua
{
  'beixiyo/vv-dashboard.nvim',
  dependencies = { 'beixiyo/vv-utils.nvim' },
  event = 'VimEnter',
  opts = {
    -- 配置项见下方
  },
}
```

### 手动

将插件目录加入 `runtimepath` 后调用：

```lua
require('vv-dashboard').setup({
  -- 配置项见下方
})
```

## 配置

所有可选项及其默认值：

| 选项 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `header` | `string \| string[]` | *VsCode ASCII art* | 头部多行文本，`string` 会按 `\n` 分割 |
| `keys` | `VVDashboardKey[]` | `{}` | 快捷键列表，见下方结构 |
| `footer` | `fun(): VVDashboardChunk[] \| string \| nil` | `nil` | 返回单行多色片段或纯文本的函数 |
| `auto_open` | `boolean` | `true` | 启动时无参数 + 空 buffer 则自动打开 |
| `filetype` | `string` | `'dashboard'` | dashboard buffer 的 filetype |
| `width` | `integer` | `60` | keys 区域的容器宽度（两端对齐基准） |
| `key_gap` | `integer` | `1` | keys 之间的空行数 |
| `section_gap` | `integer` | `2` | header / keys / footer 之间的空行数 |
| `highlights` | `VVDashboardHighlights` | *见下方* | 各段高亮组名 |

### VVDashboardKey

```lua
---@class VVDashboardKey
---@field icon? string    图标（NerdFont 等）
---@field key string      触发按键
---@field desc string     描述文字
---@field action string|function  动作：字符串作为 Ex 命令执行，函数直接调用
```

### VVDashboardChunk（footer 返回值）

```lua
---@class VVDashboardChunk
---@field [1] string  文本
---@field [2]? string 高亮组名
```

### 高亮组

| 字段 | 默认 hl 组 | 作用 |
|------|-----------|------|
| `highlights.header` | `Title` | header 区域 |
| `highlights.icon` | `Special` | keys 行图标 |
| `highlights.desc` | `Normal` | keys 行描述 |
| `highlights.key` | `Constant` | keys 行按键 |
| `highlights.footer` | `Comment` | footer 纯文本 |

## API

| 函数 / 命令 | 说明 |
|-------------|------|
| `require('vv-dashboard').setup(opts)` | 初始化插件 |
| `require('vv-dashboard').open()` | 打开 dashboard（已打开则聚焦） |
| `require('vv-dashboard').close()` | 关闭 dashboard，窗口替换为空 buffer |
| `:VVDashboard` | 等同于 `open()` |
| `:VVDashboardClose` | 等同于 `close()` |

## auto_open 逻辑

`VimEnter` 时检测以下条件，全部满足才自动打开：

1. `vim.fn.argc() == 0` — 无命令行文件参数
2. 无任何已加载的带名文件 buffer（排除 auto-session 恢复的场景）
3. 当前 buffer 为空的 `[No Name]`

## 示例

```lua
require('vv-dashboard').setup({
  -- header = [[]],
  keys = {
    { icon = '󰈚', key = 'r', desc = '最近文件', action = 'Telescope oldfiles' },
    { icon = '󰈞', key = 'f', desc = '查找文件', action = 'Telescope find_files' },
    { icon = '', key = 'g', desc = '全局搜索', action = 'Telescope live_grep' },
    { icon = '', key = 'q', desc = '退出', action = 'qa' },
  },
  footer = function()
    local stats = require('lazy').stats()
    return {
      { string.format(' %d plugins loaded in %dms', stats.loaded, stats.startuptime), 'Comment' },
    }
  end,
})
```

## Testing

Smoke test (zero deps, runs in `-u NONE`):

```bash
nvim --headless -u NONE -l tests/test_smoke.lua
```

Expected: trailing line `X passed, 0 failed`.
