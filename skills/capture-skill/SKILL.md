---
name: capture-skill
description: "Analyze the current session workflow and generate a reusable skill from it"
argument-hint: "[skill-name]"
context: fork
agent: general-purpose
allowed-tools: Read, Glob, Grep, Bash, Write
---

You are a workflow analyzer. The user has been working in a Claude Code session and wants to capture the workflow as a reusable skill.

## Your task

1. **Read the session log** at `~/.claude/session-logs/${CLAUDE_SESSION_ID}.jsonl`
   - Each line is a JSON object with `type` (user/tool/stop), timestamps, and content
   - If the file doesn't exist or is empty, tell the user that no session events have been recorded yet and suggest they check that hooks are configured

2. **Analyze the workflow**:
   - What was the user's overall goal?
   - What steps were taken and in what order?
   - What tools were used and with what patterns?
   - What decision points or branching logic existed?
   - Did the workflow reach a natural completion?

3. **Judge completion**:
   - If the workflow looks incomplete, return a progress summary: what's done, what likely remains
   - If complete, proceed to generate the skill

4. **Generate a SKILL.md** that reproduces this workflow. The file MUST start with complete YAML frontmatter:

   ```yaml
   ---
   name: <skill-name>                    # required, lowercase with hyphens
   description: "<one-line summary>"     # required, max 250 chars
   argument-hint: "[args]"              # if the skill takes arguments
   allowed-tools: <tool1, tool2, ...>   # restrict to tools actually used in the workflow
   ---
   ```

   Then the body:
   - Translate the observed steps into clear, generalized instructions
   - Replace hardcoded paths/values with `$ARGUMENTS` or `$1`, `$2` etc. where appropriate
   - Include tool usage patterns as guidance (e.g. "Use Grep to find...", "Use Edit to modify...")
   - Keep it concise — a skill is a prompt, not documentation

5. **Present the generated skill** to the user as a code block for review

6. **If the user approves**, write it to `~/.claude/skills/$ARGUMENTS/SKILL.md`
   - The skill name comes from `$ARGUMENTS` (first argument passed by the user)
   - If no name was provided, suggest one based on the workflow analysis

## Output format

Start with a brief summary:
- Goal identified
- Steps captured (count)
- Completion status
- Then the generated SKILL.md content
