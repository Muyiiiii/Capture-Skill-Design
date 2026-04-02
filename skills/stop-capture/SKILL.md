---
name: stop-capture
description: "Disable session recording hooks for capture-skill"
---

Disable session recording by removing the capture-skill hooks from `~/.claude/settings.json`.

Read `~/.claude/settings.json`, then remove the three hook entries that reference `record-event.sh`:
- The `UserPromptSubmit` entry with `record-event.sh user`
- The `PostToolUse` entry with `record-event.sh tool`
- The `Stop` entry with `record-event.sh stop`

If removing these entries leaves the `hooks` object empty, remove the `hooks` field entirely.

If there are other hooks not related to capture-skill, keep them intact.

After editing, confirm to the user that recording is now disabled.
