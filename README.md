# Codex Companion

Codex Companion 是一个 macOS 原生桌宠，用透明窗口显示一位梦幻白色半透明少女，并根据 Codex 的运行状态切换动作。

当前实现重点：

- Swift/AppKit 原生桌宠窗口，不依赖网页运行时。
- 通过 Codex lifecycle hook 写入本地 `state.json`，桌宠读取该文件完成状态联动。
- 所有 Codex 状态都复用最协调的梦幻跳舞动作基底，通过节奏、气泡和轻量状态装饰区分语义。
- 原生层限制整张人物图的全局位移/旋转，避免出现“图片整体在动、人物没动”的观感。
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
- 原生动作 clip 和状态映射
- 性能约束，例如进程探测缓存、动作懒加载和低频重绘

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
