# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

`app-front-apps-ai-skills` is a Claude Code plugin that provides AI-assisted skills for the SAP BTP Application Frontend (appFront) service. It enables developers to migrate existing HTML5 apps from SAP Neo or `html5-apps-repo`, validate appFront configurations, and clean up deployed apps — all through natural-language commands within Claude Code.

The plugin is written entirely as structured Markdown skill definitions (no compiled code). Skills invoke only Claude Code built-in tools (`Read`, `Write`, `Edit`, `Bash`, `Task`) and require no MCP servers or network access. It is distributed via the GitHub repository or manual local installation.

## Development Commands

This repository has no build step. The skills are plain Markdown files that Claude Code interprets at runtime.

```bash
# Test a skill invocation (using the test-skill helper action)
# From the repository root, skill behaviors are defined in skills/*/SKILL.md

# Validate skill logic by reading the skill file
# skills/appfront-migrate/SKILL.md
# skills/appfront-validate/SKILL.md
# skills/appfront-cleanup/SKILL.md
```

To use the plugin skills after installation:
```
/appfront:migrate html5-repo cf xsuaa
/appfront:validate
/appfront:validate ./my-appfront-project
/appfront:cleanup
```

## Architecture

```
app-front-apps-ai-skills/
├── skills/
│   ├── appfront-migrate/
│   │   ├── SKILL.md                   # Migration skill definition (phases, HARD RULES, critic checklist)
│   │   └── references/                # Reference guides loaded during migration
│   │       ├── INDEX.md               # Reference file index
│   │       ├── migration-guides/      # Source-specific migration steps (html5-repo, neo)
│   │       ├── services/              # Service plan names, afctl commands per landscape
│   │       ├── target-configs/        # Validated xs-app.json patterns
│   │       └── troubleshooting/       # Known issues, deployment errors, WorkZone CDM steps
│   ├── appfront-validate/
│   │   └── SKILL.md                   # Validation skill: PASS/WARN/FAIL report logic
│   └── appfront-cleanup/
│       └── SKILL.md                   # Undeploy and cleanup skill
├── hooks/                             # Claude Code lifecycle hooks
├── evals/                             # Skill evaluation test cases
├── CHANGELOG.md
└── README.md
```

**Skill invocation modes:**
- `migrate`, `cleanup` require explicit `/appfront:<skill>` invocation (file-modifying, disabled auto-activation)
- `validate` auto-activates when the user asks to validate an appFront app

## Configuration

Reference files in `skills/appfront-migrate/references/` act as knowledge base for the migration skill. Key files to populate for accurate, landscape-specific results:
- `references/migration-guides/html5-repo-to-appfront.md` — step-by-step migration guide
- `references/services/app-front-service.md` — service plan names and `afctl` commands per landscape
- `references/target-configs/xs-app-patterns.md` — validated `xs-app.json` patterns
- `references/troubleshooting/known-issues.md` — issues discovered in real migrations
