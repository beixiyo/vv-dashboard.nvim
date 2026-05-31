# Changelog

## [Unreleased]

### Fixed
- 防输入 `<Nop>` 列表在 `bind_keys` 之后注册，覆盖了同名 action 键位（默认配置的 `c`「配置目录」被吞）；现先收集 `config.keys` 占用的键，`<Nop>` 循环里 `if not used[key]` 跳过它们，action 键保留 callback、未占用键仍 `<Nop>`
- `render()` 光标行公式在「有 header 但 keys 为空」时多算 `section_gap`（gap 实际只在两段都非空才插入），越界后被 pcall 静默吞掉、光标停在顶部空白；现 keys 为空时落到首个内容行 `top_pad+1`，否则按真实 gap 定位首个 key 行
- 更正 `exec_action` 上方误导性死注释：原写「关闭浮窗 → 焦点自动回到底层主窗口」，但本插件是常规窗（非浮窗），`M.close` 走 `nvim_win_call + enew`、焦点留在原常规窗；注释改为常规窗语义

### Changed
- Dashboard buffer now blocks Insert mode entry (`i`, `I`, `a`, `A`, `o`, `O`, `s`, `S`, `c`, `C`, `R`).
