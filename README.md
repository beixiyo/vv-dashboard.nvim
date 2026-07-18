<div align="center">
  <h1>vv-dashboard.nvim</h1>
  <p><a href="./README.md">English</a> | <a href="./README.zh-CN.md">中文</a></p>
  <img src="./docs/assets/vv-dashboard.png" alt="vv-dashboard demo" width="900" />
  <p>Want my Neovim configuration? See <a href="https://github.com/beixiyo/dotfiles">dotfiles</a></p>
  <p><em>A minimal Neovim startup dashboard — one buffer, no floating window, and natural sidebar coexistence</em></p>
  <p>
    <img src="https://img.shields.io/badge/Neovim-0.10+-57A143?style=flat-square&amp;logo=neovim&amp;logoColor=white" alt="Requires Neovim 0.10+" />
    <img src="https://img.shields.io/badge/Lua-2C2D72?style=flat-square&amp;logo=lua&amp;logoColor=white" alt="Lua" />
  </p>
</div>

---

## Features

- Uses a single `nofile` buffer in a regular window instead of a floating window, allowing sidebars such as `vv-explorer` to remain visible
- Renders three configurable sections: a multiline header, shortcut keys, and a single-line footer with optional highlight chunks
- Centers each line horizontally by display width and centers the entire dashboard vertically
- Selects a main-area window automatically, skips known sidebar windows, and opens a new vertical split only when every regular window is a sidebar
- Re-centers automatically after `VimResized` and `WinResized`
- Opens automatically only when Neovim starts without arguments, the current buffer is empty, and no named file buffer has been restored
- Supports command strings and Lua functions as shortcut actions; the dashboard closes before the action runs
- Prevents accidental Insert mode entry while preserving keys assigned to dashboard actions

## Installation

```lua
{
  'beixiyo/vv-dashboard.nvim',
  dependencies = { 'beixiyo/vv-utils.nvim' },
  event = 'VimEnter',
  ---@type VVDashboardConfig
  opts = {
    header = nil,           -- Multiline ASCII art: string split by \n, or string[]
    keys = {
      { icon = '󰁚', key = 'r', desc = 'Recent files', action = 'Telescope oldfiles' },
      { icon = '󰁞', key = 'f', desc = 'Find files',   action = 'Telescope find_files' },
      { icon = '', key = 'g', desc = 'Global search', action = 'Telescope live_grep' },
      { icon = '', key = 'q', desc = 'Quit',          action = 'qa' },
    },
    footer = nil,           -- fun(): VVDashboardChunk[] | string | nil
    auto_open = true,       -- Open on startup with no arguments and an empty buffer
    filetype = 'dashboard', -- Filetype of the dashboard buffer
    width = 60,             -- Container width used to align the key rows
    key_gap = 1,            -- Number of blank lines between keys
    section_gap = 2,        -- Number of blank lines between header, keys, and footer
  },
}
```

## Configuration

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `header` | `string \| string[]` | *VSCode ASCII art* | Multiline header text |
| `keys` | `VVDashboardKey[]` | `{}` | Shortcut list: `{ icon?, key, desc, action }` |
| `footer` | `fun(): VVDashboardChunk[] \| string \| nil` | `nil` | Footer content; supports highlighted chunks in the form `{ text, hl_group }[]` |
| `auto_open` | `boolean` | `true` | Open on `VimEnter` when there are no arguments and the current buffer is empty |
| `filetype` | `string` | `'dashboard'` | Dashboard buffer filetype |
| `width` | `integer` | `60` | Container width of the key section |
| `key_gap` | `integer` | `1` | Number of blank lines between keys |
| `section_gap` | `integer` | `2` | Number of blank lines between the three sections |
| `highlights` | `VVDashboardHighlights` | *See below* | Highlight groups for the header, icon, description, key, and footer |

The default highlight groups are `Title` for the header, `Special` for icons, `Normal` for descriptions, `Constant` for keys, and `Comment` for a plain-text footer. Each value can be overridden through `opts.highlights`.

Each key action accepts either an Ex command string, with or without a leading `:`, or a Lua function.

## Commands

| Command | Description |
|---------|-------------|
| `:VVDashboardOpen` | Open the dashboard, or focus its existing window if it is already open |
| `:VVDashboardClose` | Close the dashboard and replace it with an empty buffer in the same window |
| `:VVDashboardToggle` | Close the dashboard if it is open, otherwise open it |

## Design

The dashboard occupies a regular window rather than a floating window. This prevents a full-screen float from visually covering sidebars and lets the layout continue to be managed by Neovim. The target-window selection skips the `vv-explorer` filetype; if no main-area window exists, the plugin creates a right-hand vertical split.

The buffer uses `buftype=nofile`, `bufhidden=wipe`, is unlisted, and has swap disabled. Window-local decorations such as line numbers, the sign column, folds, wrapping, and the cursor line are disabled explicitly. When an action runs, the dashboard is replaced with an empty buffer in the same regular window, then the action is scheduled for the next event-loop turn so buffer cleanup can finish safely.

Rendering consists of the `header`, `keys`, and `footer` sections. Text is centered using display width, which keeps multibyte icons and text aligned, while the key rows use `width` as their left/right alignment container. The footer may return plain text or highlighted chunks. Resize events trigger a fresh render so the dashboard remains centered as the surrounding layout changes.

Automatic opening is intentionally conservative: it is skipped when Neovim receives arguments, when the current buffer contains content or has a name, or when a named listed buffer has already been restored by a session plugin.

## License

[MIT](./LICENSE)
