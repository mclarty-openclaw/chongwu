# Codex Companion Hooks

Codex Companion 通过 Codex lifecycle hooks 感知当前状态。hook 脚本会把事件转换为本地状态文件，原生桌宠每秒读取一次并按状态切换动作。

## State File

默认状态文件：

```text
~/Library/Application Support/CodexCompanion/state.json
```

可用环境变量覆盖：

```bash
export CODEX_COMPANION_STATE_FILE="/tmp/codex-companion-state.json"
```

## Install Hooks

把下面配置写入 `~/.codex/hooks.json`，并把 `command` 中的路径替换成你的仓库路径：

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|resume|clear|compact",
        "hooks": [
          {
            "type": "command",
            "command": "node \"/absolute/path/to/chongwu/scripts/codex-companion-state-hook.mjs\"",
            "timeout": 5
          }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "node \"/absolute/path/to/chongwu/scripts/codex-companion-state-hook.mjs\"",
            "timeout": 5
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "node \"/absolute/path/to/chongwu/scripts/codex-companion-state-hook.mjs\"",
            "timeout": 5
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "node \"/absolute/path/to/chongwu/scripts/codex-companion-state-hook.mjs\"",
            "timeout": 5
          }
        ]
      }
    ],
    "PermissionRequest": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "node \"/absolute/path/to/chongwu/scripts/codex-companion-state-hook.mjs\"",
            "timeout": 5
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "node \"/absolute/path/to/chongwu/scripts/codex-companion-state-hook.mjs\"",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

## State Mapping

| Hook event | Companion state |
| --- | --- |
| `SessionStart` | `codex_running` |
| `UserPromptSubmit` | `thinking` |
| `PreToolUse` command-like tools | `command_running` |
| `PostToolUse` failed command | `error`, then `thinking` |
| `PostToolUse` successful test/build/check | `success`, then `thinking` |
| `PermissionRequest` | `waiting_user` |
| `Stop` | `waiting_user`, or short `success` when completion text is detected |

`command_running` 超过 90 秒后由桌宠提升为 `long_running`。

## Trust Hooks

如果 Codex 要求信任 hook，请在 Codex 配置中信任该脚本路径。不要把个人 `~/.codex/config.toml` 提交到仓库。
