# Codex Companion

Codex Companion 是一个 macOS 原生桌宠，用透明窗口显示一位梦幻白色半透明少女，并根据 Codex 的运行状态切换动作。

当前实现重点：

- Swift/AppKit 原生桌宠窗口，不依赖网页运行时。
- 通过 Codex lifecycle hook 写入本地 `state.json`，桌宠读取该文件完成状态联动。
- `codex-running` 保留最协调的梦幻跳舞动作；其它 Codex 状态从这套角色源帧生成独立本地姿态动作，例如前倾执行、托腮思考、挥手等待、庆祝和歪头报错。
- 状态动作使用局部区域姿态变形和独立动作目录，原生层继续限制整张人物图的全局位移/旋转，避免出现“图片整体在动、人物没动”的观感。
- 动作 PNG 懒加载、进程探测缓存、低频舞台重绘，降低常驻资源占用。

## Requirements

- macOS 13+
- Node.js 18+
- Swift toolchain / Xcode Command Line Tools
- Codex hooks support, only needed for live Codex 状态联动

## Install

```bash
npm install
```

## Development

运行前端状态预览：

```bash
npm run dev
```

构建前端资源：

```bash
npm run build
```

构建 macOS 桌宠：

```bash
npm run desktop:build
```

构建并启动桌宠：

```bash
npm run desktop:run
```

生成的应用位于：

```text
build/native/Codex Companion.app
```

## Test

```bash
npm test -- --run
```

测试覆盖：

- Codex 状态归一化和优先级
- hook 到状态文件的映射
- 原生动作 clip 和状态映射，确保各状态加载独立动作目录
- 本地生成动作元数据，确保非跳舞主循环状态使用局部姿态变形
- 性能约束，例如进程探测缓存、动作懒加载和低频重绘

## Action Assets

状态动作素材位于：

```text
public/assets/dancer-actions/
```

`codex-running` 是人工挑选的协调跳舞主循环。其它状态动作由脚本从这套源帧派生：

```bash
python3 scripts/generate-state-action-frames.py
```

生成策略是保持同一个梦幻白色半透明少女角色，同时对头部、上半身、手臂和裙摆做局部区域姿态变形，让 `idle`、`command-running`、`thinking`、`long-running`、`waiting-user`、`success`、`error` 看起来是明显不同的动作，而不是同一张图上下漂浮。

## Codex State Hooks

桌宠默认读取：

```text
~/Library/Application Support/CodexCompanion/state.json
```

hook 脚本：

```text
scripts/codex-companion-state-hook.mjs
```

安装方式见 [docs/hooks.md](docs/hooks.md)。

## Design Docs

- [桌宠设计文档](docs/plans/2026-06-11-codex-desktop-pet-design.md)

## Repository Notes

仓库提交源码、测试、脚本、设计文档和必要图片素材。不提交 `node_modules/`、`dist/`、`build/`、本地 `.codex/` 配置和 macOS 临时文件。
