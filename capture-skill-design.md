# Capture Skill — 工作流录制与自动生成

实时记录 Claude Code session 中的对话流程，分析工作进度，总结成可复用的 skill。

## 架构

```
/start-capture (启用hooks)
       ↓
Hook 录制  →  Subagent 分析  →  生成 SKILL.md
（async）     （context: fork）
       ↓
/stop-capture (移除hooks)
```

## 文件结构

```
~/.claude/
├── settings.json                          # hooks 按需写入（默认不录制）
├── session-logs/                          # 自动生成的日志目录（权限 700）
│   └── <session-id>.jsonl                 # 每个 session 一个日志文件（权限 600）
└── skills/
    ├── capture-skill/
    │   ├── SKILL.md                       # 分析生成 skill（subagent: fork + general-purpose）
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

接收三种事件，通过 stdin 读取 JSON，写入 `~/.claude/session-logs/<session-id>.jsonl`：

| 事件类型 | 记录内容 |
|---|---|
| `user` | 用户输入的 prompt（`jq` 提取 `.user_prompt`） |
| `tool` | 工具名(`.tool_name`)、输入摘要(`.tool_input`前300字符)、输出摘要(`.tool_output`前300字符) |
| `stop` | 响应结束时间戳（直接用 `date` 生成，不依赖 stdin JSON） |

### 隐私保护

- **文件权限**：日志目录 700，日志文件 600，仅本人可读写
- **敏感信息脱敏**：录制时通过 `sed` 自动替换为 `[REDACTED]`：
  - key/token/secret/password 等字段的值（正则匹配 `key=xxx` 模式）
  - `sk-`、`pk-`、`ak-`、`rk-`、`xox[bpas]-` 等 API key 前缀
  - `ghp_` 开头的 GitHub token（36+ 字符）
  - `eyJ` 开头的 JWT token

### Hooks 配置

**默认不录制**。通过 `/start-capture` 写入 `~/.claude/settings.json`，通过 `/stop-capture` 移除。

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

## 第二层：Subagent 分析生成

`~/.claude/skills/capture-skill/SKILL.md`

YAML frontmatter 配置：
- `context: fork` — 隔离于主对话上下文
- `agent: general-purpose` — 使用通用 agent
- `allowed-tools: Read, Glob, Grep, Bash, Write` — 限定可用工具

分析流程：

1. 读取 `~/.claude/session-logs/${CLAUDE_SESSION_ID}.jsonl`
2. 分析用户目标、操作步骤、工具使用模式、决策分支点
3. 判断工作流是否完成（未完成则返回进度摘要）
4. 生成带完整 YAML frontmatter 的 SKILL.md（`name`、`description`、`argument-hint`、`allowed-tools`）
5. 将观察到的步骤泛化为指令，硬编码值替换为 `$ARGUMENTS`
6. 展示给用户确认后写入 `~/.claude/skills/$ARGUMENTS/SKILL.md`

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
| 敏感脱敏 | sed 正则替换 | 防止 key/token/password 写入日志 |

## 已知限制

- Hook 捕获的是结构化事件，非原始对话文本，信息有损
- 工具输入输出截断为 300 字符
- Subagent 基于日志推理工作完成度，可能误判
- 需要 `jq` 可用（录制脚本依赖）
- 日志无自动清理，需手动删除旧文件
