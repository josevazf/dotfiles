### Code Intelligence

Prefer LSP over Grep/Glob/Read for code navigation:
- `goToDefinition` / `goToImplementation` to jump to source
- `findReferences` to see all usages across the codebase
- `workspaceSymbol` to find where something is defined
- `documentSymbol` to list all symbols in a file
- `hover` for type info without reading the file
- `incomingCalls` / `outgoingCalls` for call hierarchy

Before renaming or changing a function signature, use
`findReferences` to find all call sites first.

Use Grep/Glob only for text/pattern searches (comments,
strings, config values) where LSP doesn't help.

After writing or editing code, check LSP diagnostics before

### Keeping Skills Up to Date

Skills live in `~/.claude/skills/` (project-specific skills may also live in `.claude/skills/` within a repo). If during a session you discover something non-obvious about a workflow, pattern, or process that a skill covers — a gotcha, a missing step, a changed convention — update the relevant skill file to reflect it.

Use the `superpowers:writing-skills` skill when creating or editing skills to ensure they follow the correct format and conventions.

