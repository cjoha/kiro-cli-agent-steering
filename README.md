# Steering Generator — Kiro CLI Custom Agent

A Kiro CLI custom agent that interviews you about your project, scans your codebase, and generates tailored [steering documents](https://kiro.dev/docs/steering/) for the Kiro IDE and CLI.

## What it does

Instead of manually writing `.kiro/steering/*.md` files, this agent walks you through a structured conversation, inspects your repo, and produces steering docs that are specific to your project — not generic boilerplate.

It works in three phases:

1. **Interview** — Asks about your product, tech stack, team conventions, and preferences (one group of questions at a time, not a wall of text).
2. **Codebase analysis** — Reads your dependency files, config files, directory structure, and CI/CD setup to verify and supplement your answers.
3. **Generation** — Writes focused steering markdown files into `.kiro/steering/`.

## Prerequisites

- [Kiro CLI](https://kiro.dev/cli/) installed (`curl -fsSL https://cli.kiro.dev/install | bash`)
- Python 3 available on your PATH (used by the overwrite guard script)
- An authenticated Kiro CLI session (`kiro-cli` then sign in)

## Quick start

### 1. Copy the agent into your project

Copy the `.kiro/agents/` directory into the root of the project you want to generate steering for:

```bash
cp -r .kiro/agents/ /path/to/your-project/.kiro/agents/
```

Your project should end up with this structure:

```
your-project/
├── .kiro/
│   └── agents/
│       ├── steering-generator.json
│       ├── prompts/
│       │   ├── steering-generator.md
│       │   └── steering-topics.md
│       └── scripts/
│           └── guard-overwrite.sh
├── src/
├── package.json
└── ...
```

### 2. Run the agent

From your project root:

```bash
kiro-cli --agent steering-generator
```

The agent will introduce itself and start asking questions. Answer naturally — short answers are fine. It won't move to the next group of questions until you respond.

### 3. Let it scan

After the interview, the agent will scan your codebase. It reads things like:

- `package.json`, `Cargo.toml`, `pyproject.toml`, `go.mod`, etc.
- Monorepo indicators (`pnpm-workspace.yaml`, `nx.json`, `turbo.json`, etc.)
- Config files (`.eslintrc`, `tsconfig.json`, `.prettierrc`, etc.)
- CI/CD config (`.github/workflows/`, `Jenkinsfile`, etc.)
- Infrastructure files (`cdk.json`, `Dockerfile`, `serverless.yml`, etc.)

It will present a summary of what it found and ask you to confirm before writing anything.

### 4. Review the output

Generated files land in `.kiro/steering/`. Typical output:

| File | Purpose | Inclusion |
|------|---------|-----------|
| `product.md` | Product overview, goals, target users | Always |
| `tech.md` | Languages, frameworks, versions, infra | Always |
| `structure.md` | Directory layout, naming, import patterns | Always |
| `conventions.md` | Coding standards, formatting, error handling | Always |
| `testing.md` | Test framework, patterns, coverage | Always (if relevant) |
| `api-standards.md` | REST/API conventions | Conditional on API files |
| `security.md` | Auth, validation, secrets | Always (if relevant) |
| `{package}.md` | Per-package steering (monorepos) | Conditional on package path |

The agent will skip files that aren't relevant to your project. A simple project might only get 3-4 files.


## Overwrite protection

This agent **cannot overwrite existing steering files**. This is enforced at two levels:

1. **preToolUse hook** — A shell script (`.kiro/agents/scripts/guard-overwrite.sh`) intercepts every file write. If the target file already exists, the write is blocked with a non-zero exit code. The agent cannot bypass this.

2. **System prompt rules** — The agent is instructed to proactively check for existing files and skip them. If a naming collision occurs, it will either pick a different name or ask you what to do.

If you want the agent to regenerate a file that already exists, you need to manually delete or rename the existing file first:

```bash
# Remove a specific file
rm .kiro/steering/conventions.md

# Or rename it
mv .kiro/steering/conventions.md .kiro/steering/conventions-old.md

# Then re-run the agent
kiro-cli --agent steering-generator
```

## Customising the agent

### Adding custom steering topics

Edit `.kiro/agents/prompts/steering-topics.md` to add topics you always want covered. This file is loaded as context every time the agent runs.

```markdown
## Accessibility Standards
Always generate an accessibility.md steering file that covers:
- WCAG 2.1 AA compliance requirements
- Semantic HTML expectations
- ARIA usage patterns
- Keyboard navigation requirements

## Git Workflow
Always generate a git-workflow.md steering file that covers:
- Branch naming conventions
- Commit message format
- PR review process
- Merge strategy
```

The agent will pick these up and include them in its generation plan.

### Changing the model

Edit `model` in `.kiro/agents/steering-generator.json`:

```json
{
  "model": "claude-sonnet-4"
}
```

Use `/model` in an active Kiro CLI session to see available models.

### Adjusting write permissions

The agent can only write to `.kiro/steering/**` by default. To change this, edit `toolsSettings.fs_write.allowedPaths` in the agent JSON:

```json
"toolsSettings": {
  "fs_write": {
    "allowedPaths": [".kiro/steering/**"]
  }
}
```

### Modifying the interview flow

The full system prompt lives in `.kiro/agents/prompts/steering-generator.md`. Edit the Phase 1 section to add, remove, or reorder interview questions. The agent follows the prompt structure closely.

## File reference

```
.kiro/agents/
├── steering-generator.json          # Agent configuration
│   ├── tools: fs_read, fs_write, execute_bash
│   ├── allowedTools: fs_read (auto-approved)
│   ├── fs_write scoped to .kiro/steering/**
│   └── preToolUse hook on fs_write
├── prompts/
│   ├── steering-generator.md        # System prompt (3-phase workflow)
│   └── steering-topics.md           # Your custom topics (placeholder)
└── scripts/
    └── guard-overwrite.sh           # Blocks writes to existing files
```

## What are steering files?

Steering files are markdown documents in `.kiro/steering/` that give Kiro persistent context about your project. They support three inclusion modes:

- **Always** (default) — Loaded into every Kiro interaction. No front matter needed.
- **Conditional** — Loaded only when working with files matching a glob pattern. Uses front matter:
  ```yaml
  ---
  inclusion: fileMatch
  fileMatchPattern: "packages/api/**"
  ---
  ```
- **Manual** — Available on-demand via `#steering-file-name` in chat. Uses front matter:
  ```yaml
  ---
  inclusion: manual
  ---
  ```

Steering files can reference other project files using `#[[file:relative/path]]`, which keeps the steering current with your actual codebase.

For full details, see the [Kiro steering documentation](https://kiro.dev/docs/steering/).

## Troubleshooting

**Agent doesn't appear in `/agent` list**
- Make sure the JSON is valid: `python3 -m json.tool .kiro/agents/steering-generator.json`
- Check the file is in `.kiro/agents/` at your project root

**Writes are being blocked unexpectedly**
- The guard script requires Python 3. Check it's available: `python3 --version`
- The script checks if the file exists on disk. If you see `BLOCKED`, the file is already there.

**Agent skips the interview and goes straight to scanning**
- This shouldn't happen, but if it does, start a new session. The system prompt is explicit about the three-phase flow.

**Generated files are too generic**
- Give more detailed answers during the interview. The agent uses your words directly.
- Add specific topics to `steering-topics.md`.
- Edit the generated files after — they're just markdown.
