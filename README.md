# Capture-Skill-Design

录制 Claude Code session 的工作流，自动分析并生成可复用的 skill。

## 工作原理

```
/start-capture       启用 hooks，开始录制
     |
  正常工作            hooks 异步记录每个事件到 JSONL
     |
/capture-skill       subagent 分析日志，生成 SKILL.md
     |
/stop-capture        移除 hooks，停止录制
```

- **录制层**：通过 Claude Code hooks 异步捕获用户输入、工具调用、响应结束三类事件，写入 `~/.claude/session-logs/<session-id>.jsonl`
- **分析层**：`/capture-skill` 以 `context: fork` 启动独立 subagent，读取日志、分析工作流、生成带 YAML frontmatter 的 SKILL.md

## 安装

将 `skills/` 目录复制到 `~/.claude/skills/`：

```bash
cp -r skills/* ~/.claude/skills/
chmod +x ~/.claude/skills/capture-skill/scripts/record-event.sh
```

依赖：`jq`（录制脚本使用）。

## 使用

```bash
/start-capture                # 启用录制
# ... 正常工作 ...
/capture-skill my-workflow    # 分析并生成 skill
/stop-capture                 # 停止录制
```

定时自动检测：

```bash
/loop 3m /capture-skill my-workflow
```

查看原始日志：

```bash
cat ~/.claude/session-logs/<session-id>.jsonl | jq .
```

## 文件结构

```
skills/
├── capture-skill/
│   ├── SKILL.md              # 分析生成 skill（subagent）
│   └── scripts/
│       └── record-event.sh   # 录制脚本（含脱敏）
├── start-capture/
│   └── SKILL.md              # 启用录制 hooks
└── stop-capture/
    └── SKILL.md              # 移除录制 hooks
```

设计文档：

- `capture-skill-design.md` — 架构设计
- `capture-skill-implementation.md` — 实现细节

## 隐私

- 默认不录制，需手动 `/start-capture` 启用
- 日志文件权限 600，目录权限 700
- 写入前自动脱敏 API key、token、password、JWT 等敏感信息
- 录制失败不影响主对话（`async: true` + `exit 0`）

## 限制

- Hook 捕获结构化事件而非原始对话文本，信息有损
- 工具输入/输出截断为 300 字符
- Subagent 基于日志推理完成度，可能误判
- 日志无自动清理，需手动删除旧文件
