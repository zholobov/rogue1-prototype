# Claude Code Instructions

## Formatting

- **Never use tabs for indentation.** Always use spaces (4 spaces per indent level) in all files.

## Critical Rules

- **Never push to remote** unless explicitly told to push. Only commit locally.
- **Never make code changes** unless explicitly instructed. Research, analyze, and present options — but do not edit files until the user approves and tells you to proceed.
- **Never auto-launch Godot** for playtesting. The user controls when the game runs.
- **Never mask, suppress, or ignore warnings/errors.** Always find and fix the root cause. Do not use `@warning_ignore`, project settings suppression, or workarounds that hide the problem. If the fix is not 100% clear, stop and ask the user — explain the issue, what you know, and present options for how to properly resolve it.
