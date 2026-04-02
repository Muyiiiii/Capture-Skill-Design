# Capture Skill — 实现记录

实时记录 Claude Code session 对话流程，分析工作进度，总结成可复用 skill。

## 文件结构

```
~/.claude/
├── settings.json                          # hooks 按需写入（默认不录制）
├── session-logs/                          # 自动生成的日志目录（权限 700）
│   └── <session-id>.jsonl                 # 每个 session 一个日志文件（权限 600）
└── skills/
    ├── capture-skill/
    │   ├── SKILL.md                       # 分析生成 skill（context: fork, agent: general-purpose）
    │   └── scripts/
    │       └── record-event.sh            # 录制脚本（含脱敏）
    ├── start-capture/
    │   └── SKILL.md                       # 启用录制
    └── stop-capture/
        └── SKILL.md                       # 停止录制
```

## 第一层：Hook 录制

### 录制脚本

`~/.claude/skills/capture-skill/scripts/record-event.sh`

用法：`echo '{"json":"data"}' | record-event.sh <event_type> <session_id>`

接收三种事件，通过 stdin 读取 JSON，写入 `~/.claude/session-logs/<session-id>.jsonl`：

| 事件类型 | 输入源 | jq 提取逻辑 | 输出字段 |
|---|---|---|---|
| `user` | stdin JSON | `.user_prompt` | `{type, text, ts}` |
| `tool` | stdin JSON | `.tool_name`, `.tool_input[:300]`, `.tool_output[:300]` | `{type, name, input, output, ts}` |
| `stop` | 无（忽略 stdin） | 直接 `date -u` 生成 | `{type, ts}` |

### 隐私保护

- **文件权限**：`mkdir -p` 创建日志目录后 `chmod 700`，每次写入后 `chmod 600` 日志文件
- **敏感信息脱敏**：通过 `redact()` 函数（`sed -E`）在写入前过滤：
  - `key|token|secret|password|passwd|credential|auth|bearer|api_key|apikey|access_key|private_key` 等字段名后跟 `:=` 的值
  - `sk-`、`pk-`、`ak-`、`rk-`、`xox[bpas]-` 前缀的 token（10+ 字符）
  - `ghp_` 开头的 GitHub token（36+ 字符）
  - `eyJ` 开头的 JWT token（两段 20+ 字符以 `.` 分隔）
- **默认不录制**：hooks 不写入 settings.json，需 `/start-capture` 启用
- **脚本始终返回 0**：`exit 0` 确保录制失败不影响主对话

### Hooks 配置

通过 `/start-capture` 写入 `~/.claude/settings.json`，通过 `/stop-capture` 移除。

三个事件均为 `async: true`（异步，不阻塞主对话）：

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "cat | ~/.claude/skills/capture-skill/scripts/record-event.sh user ${CLAUDE_SESSION_ID}",
            "async": true
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "cat | ~/.claude/skills/capture-skill/scripts/record-event.sh tool ${CLAUDE_SESSION_ID}",
            "async": true
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "echo '' | ~/.claude/skills/capture-skill/scripts/record-event.sh stop ${CLAUDE_SESSION_ID}",
            "async": true
          }
        ]
      }
    ]
  }
}
```

### start-capture SKILL.md

读取 `~/.claude/settings.json`，合并写入上述 hooks（保留已有 hooks）。完成后提醒用户用 `/stop-capture` 关闭。

### stop-capture SKILL.md

读取 `~/.claude/settings.json`，移除引用 `record-event.sh` 的三个 hook 条目。若 hooks 对象为空则移除整个 `hooks` 字段。保留不相关的其他 hooks。

## 第二层：Subagent 分析生成

`~/.claude/skills/capture-skill/SKILL.md`

### YAML Frontmatter

```yaml
---
name: capture-skill
description: "Analyze the current session workflow and generate a reusable skill from it"
argument-hint: "[skill-name]"
context: fork
agent: general-purpose
allowed-tools: Read, Glob, Grep, Bash, Write
---
```

### 分析流程

1. **读取日志** — `~/.claude/session-logs/${CLAUDE_SESSION_ID}.jsonl`（不存在或为空则提示检查 hooks）
2. **分析工作流** — 用户目标、步骤顺序、工具使用模式、决策分支点、是否完成
3. **判断完成度** — 未完成返回进度摘要（已完成/剩余事项）；已完成则继续生成
4. **生成 SKILL.md** — 带完整 YAML frontmatter（`name`、`description`、`argument-hint`、`allowed-tools`）
   - 步骤泛化为可复用指令
   - 硬编码值替换为 `$ARGUMENTS` / `$1` `$2`
   - 包含工具使用模式指导
5. **展示并确认** — 代码块展示，用户确认后写入 `~/.claude/skills/$ARGUMENTS/SKILL.md`
   - 无参数时根据分析结果建议名称

### 输出格式

以简要摘要开头：识别到的目标、捕获步骤数、完成状态，然后是生成的 SKILL.md 内容。

## 使用方法

```
/start-capture                ← 启用录制（写入 hooks）
... 正常工作 ...
/capture-skill my-workflow    ← 分析日志，生成 skill
/stop-capture                 ← 停止录制（移除 hooks）
```

### 定时自动检测

```
/loop 3m /capture-skill my-workflow-name
```

每 3 分钟自动分析一次日志，工作完成时通知。

### 查看原始日志

```bash
cat ~/.claude/session-logs/<session-id>.jsonl | jq .
```

## 设计选择

| 决策 | 选择 | 理由 |
|---|---|---|
| 录制机制 | Hook | 唯一能捕获主对话事件的方式 |
| 分析执行 | Subagent（fork + general-purpose） | 不占主上下文、支持后台运行 |
| 日志格式 | JSONL | 追加写入友好、逐行可解析 |
| 日志位置 | ~/.claude/session-logs/ | 统一管理、不污染项目目录 |
| Hook 模式 | async | 不阻塞主对话 |
| 默认关闭 | /start-capture 手动启用 | 隐私优先，避免无意录制 |
| 敏感脱敏 | sed -E 正则（redact 函数） | 防止 key/token/password 写入日志 |
| 脚本容错 | exit 0 + jq 2>/dev/null | 录制失败不阻塞主对话 |

## 已知限制

- Hook 捕获的是结构化事件，非原始对话文本，信息有损
- 工具输入输出截断为 300 字符
- Subagent 基于日志推理工作完成度，可能误判
- 需要 `jq` 可用（录制脚本依赖）
- 日志无自动清理，需手动删除旧文件
