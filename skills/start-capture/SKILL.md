---
name: start-capture
description: "Enable session recording hooks for capture-skill"
---

Enable session recording by adding hooks to `~/.claude/settings.json`.

Read `~/.claude/settings.json`, then add the following `hooks` field (merge with existing hooks if any):

```json
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
```

After editing, confirm to the user that recording is now enabled. Remind them to run `/stop-capture` when done.
