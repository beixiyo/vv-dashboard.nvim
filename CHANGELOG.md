# Changelog

## [0.1.2] - 2026-08-08

### Fixed

- header 原先逐行按显示宽度居中，ASCII art 各行宽度不一致时窄行会被单独推偏（默认标题的 51/49 混杂行宽导致第 3、4、6 行整体右移一列）；现按所有 header 行的最大显示宽度整块居中，各行共用同一左偏移，字形内部结构不再被拉歪。keys 和 footer 仍按各自显示宽度逐行居中
- 默认 ASCII 标题的 `D` 误写成 9 列宽的 `O` 形，且 C/D 与 D/E 之间缺少分隔空格；现替换为 figlet ANSI Shadow 的规范输出，行宽收敛为 50/50/48/48/50/50
- 重复 `setup()` 时旧的 scheduled auto-open 未失效，`auto_open = false` 也不会取消已排队的待执行任务；现后续 setup 使旧任务失效，且重复启停不会误取消当前生命周期的任务

## [0.1.1] - 2026-07-26

### Fixed

- 关闭 Dashboard 或从外部替换其 buffer 时，完整恢复接管前的窗口选项并清理会话监听，避免窗口持续残留极简样式
- 重复调用 `setup()` 时安全替换命令和自动打开监听，避免遗留重复生命周期状态

### Changed

- 拆分 action、渲染、状态、目标窗口与生命周期模块，并微调默认 ASCII 标题末行间距

## [0.1.0] - 2026-07-13

### Fixed
- 防输入 `<Nop>` 列表在 `bind_keys` 之后注册，覆盖了同名 action 键位（默认配置的 `c`「配置目录」被吞）；现先收集 `config.keys` 占用的键，`<Nop>` 循环里 `if not used[key]` 跳过它们，action 键保留 callback、未占用键仍 `<Nop>`
- `render()` 光标行公式在「有 header 但 keys 为空」时多算 `section_gap`（gap 实际只在两段都非空才插入），越界后被 pcall 静默吞掉、光标停在顶部空白；现 keys 为空时落到首个内容行 `top_pad+1`，否则按真实 gap 定位首个 key 行
- 更正 `exec_action` 上方误导性死注释：原写「关闭浮窗 → 焦点自动回到底层主窗口」，但本插件是常规窗（非浮窗），`M.close` 走 `nvim_win_call + enew`、焦点留在原常规窗；注释改为常规窗语义

### Changed
- Dashboard buffer now blocks Insert mode entry (`i`, `I`, `a`, `A`, `o`, `O`, `s`, `S`, `c`, `C`, `R`).
