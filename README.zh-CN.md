<div align="center">
  <h1>vv-dashboard.nvim</h1>
  <p><a href="./README.md">English</a> | <a href="./README.zh-CN.md">中文</a></p>
  <img src="https://github.com/beixiyo/vv-dashboard.nvim/releases/download/assets-2026-07-25/vv-dashboard.png" alt="vv-dashboard 演示" width="900" />
  <p>想要我的 Neovim 配置？查看 <a href="https://github.com/beixiyo/dotfiles">dotfiles</a></p>
  <p><em>极简 Neovim 启动页 — 单 buffer、非浮窗、与侧栏天然共存</em></p>
  <p>
    <img src="https://img.shields.io/badge/Neovim-0.10+-57A143?style=flat-square&amp;logo=neovim&amp;logoColor=white" alt="需要 Neovim 0.10+" />
    <img src="https://img.shields.io/badge/Lua-2C2D72?style=flat-square&amp;logo=lua&amp;logoColor=white" alt="Lua" />
  </p>
</div>

---

## 功能

- 在常规窗口中使用单个 `nofile` buffer，而非浮窗，因此 `vv-explorer` 等侧栏可以继续显示
- 渲染三个可配置区域：多行 header、快捷键和支持高亮片段的单行 footer
- 按显示宽度水平居中每一行，并将整个 dashboard 垂直居中
- 自动选择主区域窗口，跳过已知侧栏；只有全部常规窗口都是侧栏时才新建垂直分屏
- 在 `VimResized` 和 `WinResized` 后自动重新居中
- 仅在 Neovim 无启动参数、当前 buffer 为空且没有恢复出的具名文件 buffer 时自动打开
- 快捷键 action 支持命令字符串和 Lua 函数；执行 action 前会先关闭 dashboard
- 阻止意外进入 Insert 模式，同时保留已分配给 dashboard action 的按键

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
      { icon = '󰁚', key = 'r', desc = '最近文件', action = 'Telescope oldfiles' },
      { icon = '󰁞', key = 'f', desc = '查找文件', action = 'Telescope find_files' },
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
| `footer` | `fun(): VVDashboardChunk[] \| string \| nil` | `nil` | 底部内容，支持 `{ text, hl_group }[]` 形式的高亮片段 |
| `auto_open` | `boolean` | `true` | `VimEnter` 时无参数 + 当前 buffer 为空则自动打开 |
| `filetype` | `string` | `'dashboard'` | dashboard buffer 的 filetype |
| `width` | `integer` | `60` | keys 区域容器宽度 |
| `key_gap` | `integer` | `1` | keys 之间的空行数 |
| `section_gap` | `integer` | `2` | 三段之间的空行数 |
| `highlights` | `VVDashboardHighlights` | *见下文* | header、icon、desc、key 和 footer 的高亮组 |

默认高亮组分别为：header 使用 `Title`，icon 使用 `Special`，desc 使用 `Normal`，key 使用 `Constant`，纯文本 footer 使用 `Comment`。每一项均可通过 `opts.highlights` 覆盖。

每个快捷键 action 可以是 Ex 命令字符串（可带或不带开头的 `:`），也可以是 Lua 函数。

## 命令

| 命令 | 说明 |
|------|------|
| `:VVDashboardOpen` | 打开 dashboard；如果已经打开，则聚焦现有窗口 |
| `:VVDashboardClose` | 关闭 dashboard，并在同一窗口中换入一个空 buffer |
| `:VVDashboardToggle` | 已打开则关闭，否则打开 |

## 设计说明

Dashboard 占用常规窗口，而不是浮窗。这样可以避免全屏浮窗在视觉上覆盖侧栏，并让布局继续由 Neovim 管理。选择目标窗口时会跳过 `vv-explorer` filetype；如果不存在主区域窗口，插件会在右侧新建垂直分屏。

Dashboard buffer 使用 `buftype=nofile`、`bufhidden=wipe`，不进入 buffer 列表并禁用 swap。行号、sign column、折叠、换行和 cursor line 等窗口局部装饰会被显式关闭。执行 action 时，dashboard 会先在同一个常规窗口中被空 buffer 替换，再把 action 调度到下一轮事件循环，让 buffer 清理安全完成。

渲染由 `header`、`keys` 和 `footer` 三段组成。文本按照显示宽度居中，因此多字节图标和文字也能保持对齐；快捷键行以 `width` 作为左右对齐的容器宽度。Footer 可以返回纯文本或带高亮的片段。尺寸变化事件会触发重新渲染，让 dashboard 在周边布局改变后仍保持居中。

自动打开采用保守门禁：Neovim 带启动参数、当前 buffer 有内容或名称、或 session 插件已经恢复出具名且 listed 的 buffer 时，均不会自动打开。

## 许可证

[MIT](./LICENSE)
