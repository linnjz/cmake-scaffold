---
name: skill-development
description: This skill should be used when the user wants to "create a skill", "write a new skill", "add a skill to a plugin", "improve a skill description", "organize skill content", "turn this workflow into a skill", "skillify this", "make this reusable", "save this workflow", "capture this session's repeatable process", or needs guidance on skill structure, progressive disclosure, or skill authoring best practices for Claude Code, Codex, opencode, or Pi.
---

# Skill Development

Guidance for creating effective skills that work across AI agent platforms (Claude Code, Codex, opencode, Pi).

## About Skills

Skills are modular, self-contained packages that extend an agent's capabilities with specialized knowledge, workflows, and tools. Think of them as "onboarding guides" for specific domains or tasks—they transform a general-purpose agent into a specialized agent equipped with procedural knowledge.

### What Skills Provide

1. Specialized workflows - Multi-step procedures for specific domains
2. Tool integrations - Instructions for working with specific file formats or APIs
3. Domain expertise - Domain knowledge, schemas, business logic
4. Bundled resources - Scripts, references, and assets for complex and repetitive tasks

### Anatomy of a Skill

Every skill consists of a required SKILL.md file and optional bundled resources:

```
skill-name/
├── SKILL.md (required)
│   ├── YAML frontmatter metadata (required)
│   │   ├── name: (required)
│   │   └── description: (required)
│   └── Markdown instructions (required)
└── Bundled Resources (optional)
    ├── scripts/          - Executable code (Python/Bash/etc.)
    ├── references/       - Documentation loaded into context as needed
    └── assets/           - Files used in output (templates, icons, fonts, etc.)
```

#### SKILL.md (required)

**Metadata Quality:** The `name` and `description` in YAML frontmatter determine when the agent will use the skill. Be specific about what the skill does and when to use it. Write the description in the third person (e.g. "This skill should be used when..." rather than "Use this skill when...").

#### Bundled Resources (optional)

##### Scripts (`scripts/`)

Executable code (Python/Bash/etc.) for tasks that require deterministic reliability or are repeatedly rewritten.

- **When to include**: When the same code is being rewritten repeatedly or deterministic reliability is needed
- **Example**: `scripts/rotate_pdf.py` for PDF rotation tasks
- **Benefits**: Token efficient, deterministic, may be executed without loading into context
- **Note**: Scripts may still need to be read by the agent for patching or environment-specific adjustments

##### References (`references/`)

Documentation and reference material loaded as needed into context to inform the agent's process and thinking.

- **When to include**: For documentation the agent should reference while working
- **Examples**: `references/schema.md` for database schemas, `references/api_docs.md` for API specifications, `references/policies.md` for company policies
- **Benefits**: Keeps SKILL.md lean, loaded only when the agent determines it's needed
- **Best practice**: If files are large (>10k words), include grep search patterns in SKILL.md
- **Avoid duplication**: Information should live in either SKILL.md or references files, not both. Prefer references files for detailed information unless it's truly core to the skill—this keeps SKILL.md lean while making information discoverable without hogging the context window.

##### Assets (`assets/`)

Files not intended to be loaded into context, but used within the output the agent produces.

- **When to include**: When the skill needs files used in the final output
- **Examples**: `assets/logo.png`, `assets/slides.pptx`, `assets/frontend-template/`, `assets/font.ttf`
- **Benefits**: Separates output resources from documentation, enables the agent to use files without loading them into context

### Progressive Disclosure Design Principle

Skills use a three-level loading system to manage context efficiently:

1. **Metadata (name + description)** - Always in context (~100 words)
2. **SKILL.md body** - When skill triggers (<5k words)
3. **Bundled resources** - As needed by the agent (unlimited; scripts can be executed without reading into the context window)

## Core Principles

Adapted from TDD-for-documentation: writing skills IS test-driven development applied to process documentation.

### 1. Think About Trigger Conditions Before Writing

The `description` is the **only thing the agent sees** when deciding which skill to load. It's surfaced in the system prompt alongside all other installed skills.

Before writing the body, answer these questions:

- **What capability does this skill provide?** (What does it do)
- **When/why should it trigger?** (Specific keywords, contexts, file types the user will actually say)
- **What should NOT trigger it?** (Negative cases, "Use ONLY when..." gating)

**Description = When to Use, NOT What the Skill Does.** Do not summarize the skill's workflow in the description. If the description summarizes the workflow, the agent may follow the description instead of reading the full skill content.

```yaml
# ❌ BAD: Summarizes workflow - agent may follow this instead of reading skill
description: Use when executing plans - dispatches subagent per task with code review between tasks

# ❌ BAD: Too abstract, vague
description: For async testing

# ✅ GOOD: Triggering conditions only, concrete keywords, front-loaded
description: Use when tests have race conditions, timing dependencies, or pass/fail inconsistently
```

### 2. Verify After Writing

A skill written but never verified is untested code. Before declaring a skill done, run verification scenarios and confirm the agent actually complies and the skill loads on expected triggers.

**Core principle:** If you never watched an agent fail to apply the skill, you don't know if the skill teaches the right thing.

Verification varies by skill type:

- **Discipline skills** (rules/requirements): Pressure-test with scenarios combining time + sunk cost + exhaustion. Identify rationalizations and add explicit counters. Success = agent follows the rule under maximum pressure.
- **Technique skills** (how-to): Apply to a fresh scenario and edge cases. Success = agent applies the technique correctly to new scenarios.
- **Pattern skills** (mental models): Recognition + application + counter-example tests. Success = agent correctly identifies when/how to apply.
- **Reference skills** (docs/APIs): Retrieval + application + gap tests. Success = agent finds and correctly applies the reference info.

### The Iron Law

```
NO SKILL WITHOUT A FAILING TEST FIRST
```

Applies to NEW skills AND EDITS to existing skills. If you wrote the skill before running a baseline scenario, delete it and start over.

## Skill Creation Process

Follow the steps in order, skipping only with a clear reason.

### Step 1: Understand the Skill with Concrete Examples

Skip only when usage patterns are already clearly understood. Collect concrete examples of how the skill will be used, from the user or generated and validated with user feedback.

Run the interview with an interactive Q&A tool (see Interactive Q&A Tool Mapping); never ask questions as plain text. Avoid asking too many questions in one message; start with the most important, follow up as needed.

Pick a mode based on how much the user wants to decide:

- **Guided mode (default)**: Run the four interview rounds below.
- **Proxy mode**: Run when the user delegates decisions ("you decide", "your call", "you name it"). Follow the proxy rules instead of asking every round.

#### Guided Mode: Four Interview Rounds

**Round 1 — High-level confirmation**
Suggest a name and a triggering description (when to use, NOT what it does). Confirm the capability boundary: what should NOT trigger the skill (negative cases).

**Round 2 — Details**
Collect concrete usage examples and mark them as input for Step 2's resource planning. Ask whether the skill needs arguments. Ask how it executes (inline vs fork/subagent, mapped to the target platform). Ask where to save: project-level, platform-level (`~/.claude/skills/`), or shared (`~/.agents/skills/`).

**Round 3 — Step breakdown**
For each major step, ask what it produces, what proves it succeeded, whether the user must confirm before proceeding, and which steps run in parallel. Mark each "what proves success" answer as a candidate verification scenario for Step 5. Tailor follow-ups to the skill type (discipline/technique/pattern/reference).

**Round 4 — Wrap-up**
Confirm trigger phrases and negative cases. Collect edge cases and mark them as verification inputs for Step 5.

Skip rounds for simple processes; don't over-ask for 2-step skills.

#### Proxy Mode Rules

Proxy mode does not replace example collection. At minimum, extract an intent anchor from the conversation or one question: "What task does this skill handle? Give one minimal example."

Two granularities:
- **Global proxy**: User delegates everything up front. Skip the four rounds and fill in all fields per this skill's norms (description = triggers, not workflow; imperative form; lean SKILL.md; progressive disclosure).
- **Per-item proxy**: User delegates a single field mid-interview ("you decide the name"). Decide that item, mark it, and continue the remaining rounds.

Output a **Proxy Decision Log** listing every delegated field as "value + rationale"; flag uncertain values as `[pending confirmation]`. Consolidate confirmation into a single final review: the user reviews the decision log plus the complete SKILL.md, then approves or edits.

Treat proxy-filled success criteria as "assumptions to verify" and prioritize them as Step 5 verification scenarios — the user never confirmed them individually.

### Step 2: Plan the Reusable Skill Contents

Analyze each concrete example:

1. Consider how to execute on the example from scratch
2. Identify which scripts, references, and assets would help when executing these workflows repeatedly

Example: A `pdf-editor` skill handling "Help me rotate this PDF":
1. Rotating a PDF re-writes the same code each time
2. A `scripts/rotate_pdf.py` script would help

Example: A `big-query` skill handling "How many users have logged in today?":
1. Querying requires re-discovering table schemas each time
2. A `references/schema.md` documenting the schemas would help

### Step 3: Create the Skill Structure

```bash
mkdir -p skill-name/{references,scripts,assets}
touch skill-name/SKILL.md
```

Create only the directories you actually need. Delete any example files not needed for the skill.

### Step 4: Edit the Skill

Remember the skill is being created for another agent instance to use. Focus on including information that is beneficial and **non-obvious**. Consider what procedural knowledge, domain-specific details, or reusable assets would help another agent execute these tasks more effectively.

#### Start with Reusable Skill Contents

Begin implementation with the reusable resources: `scripts/`, `references/`, and `assets/`. This step may require user input (e.g. brand assets for a `brand-guidelines` skill).

#### Update SKILL.md

**Writing Style:** Write the entire skill using **imperative/infinitive form** (verb-first instructions), not second person:

```
# ✅ Good (imperative)
To create a hook, define the event type.
Configure the MCP server with authentication.

# ❌ Bad (second person)
You should create a hook by defining the event type.
You need to configure the MCP server.
```

**Description (Frontmatter):** Use third-person format with specific trigger phrases:

```yaml
description: This skill should be used when the user asks to "create a hook", "add a PreToolUse hook", "validate tool use", or mentions hook events (PreToolUse, PostToolUse, Stop).
```

To complete the SKILL.md body, answer:

1. What is the purpose of the skill, in a few sentences?
2. When should the skill be used? (Also in frontmatter description with specific triggers)
3. In practice, how should the agent use the skill? Reference all reusable contents so the agent knows how to use them.

**Keep SKILL.md lean:** Target 1,500-2,000 words for the body. Move detailed content to `references/`. Reference resources explicitly:

```markdown
## Additional Resources

### Reference Files
- **`references/patterns.md`** - Common patterns
- **`references/advanced.md`** - Advanced use cases

### Example Files
- **`examples/example-script.sh`** - Working example
```

### Step 5: Validate and Test

1. **Check structure**: Skill directory contains `SKILL.md`
2. **Validate SKILL.md**: Has frontmatter with `name` and `description`
3. **Check trigger phrases**: Description includes specific user queries
4. **Verify writing style**: Body uses imperative/infinitive form, not second person
5. **Test progressive disclosure**: SKILL.md is lean (~1,500-2,000 words), detailed content in references/
6. **Check references**: All referenced files exist
7. **Validate examples**: Examples are complete and correct
8. **Test scripts**: Scripts are executable and work correctly
9. **Run verification scenarios**: Confirm the agent loads the skill on expected triggers and complies with its instructions (see Core Principles)

**Verification scenario sources:** Draw scenarios from (1) the success criteria collected in Round 3, (2) the edge and negative cases from Round 4, (3) the baseline scenario, and (4) proxy-filled assumptions flagged as "assumptions to verify" or `[pending confirmation]`.

### Step 6: Iterate

After testing, users may request improvements, often right after using the skill with fresh context.

**Iteration workflow:**
1. Use the skill on real tasks
2. Notice struggles or inefficiencies
3. Identify how SKILL.md or bundled resources should be updated
4. Implement changes and test again

**Common improvements:**
- Strengthen trigger phrases in description
- Move long sections from SKILL.md to references/
- Add missing examples or scripts
- Clarify ambiguous instructions
- Add edge case handling

## Frontmatter Differences by Platform

All platforms require `name` and `description`. Everything else varies.

| Platform | Required | Optional fields | Typical locations |
|----------|----------|-----------------|-------------------|
| **Claude Code** | `name`, `description` | `allowed-tools`, `metadata`, `disable-model-invocation`, `user-invocable`, `version`, `compatibility`, `license` | `~/.claude/skills/<name>/`, `.claude/skills/`, plugins |
| **Codex** | `name`, `description` | `allowed-tools`, `metadata` (e.g. trigger), `arguments`, `argument-hint`, `context` (fork/inline), `agent`, `compatibility`, `license` | `~/.codex/skills/<name>/`, `.codex/skills/`, `.agents/skills/` |
| **opencode** | `name`, `description` | `license`, `compatibility`, `metadata` (string-string map) | `.opencode/skills/<name>/`, `~/.config/opencode/skills/`, auto-loads `~/.agents/skills/` and `~/.claude/skills/` |
| **Pi** | `name`, `description` | minimal (follow platform docs) | `.pi/skills/<name>/`, `~/.pi/skills/` |

**Portable strategy:** Write only `name` + `description` in frontmatter, put everything else in the body and bundled resources. This works on every platform. Add platform-specific fields only when targeting one platform's extra capability (e.g. Codex `context: fork`, `allowed-tools`).

**opencode-specific notes:**
- `name` must be lowercase hyphen-separated, up to 64 chars, and match the folder name
- `description` is effectively required: skills without one are filtered out and never surfaced to the model
- Third-person, "Use when...", front-load concrete trigger keywords and filenames; gate with "Use ONLY when..." if the skill should stay quiet on adjacent topics
- Skills registered under `skills.paths` are scanned recursively for `**/SKILL.md`

**Shared location:** `~/.agents/skills/` is the cross-platform home — opencode and Codex both auto-load it. A skill with only `name` + `description` frontmatter there works for both.

**Interactive Q&A Tool Mapping:** Interview the user with the platform's interactive question tool, never plain-text questions. On platforms without a dedicated tool, keep questions minimal and batchable.

| Platform | Q&A tool |
|----------|----------|
| Claude Code | `AskUserQuestion` |
| opencode | `question` |
| Codex | `AskUserQuestion` (when available); otherwise minimal batched text questions |

## Validation Checklist

**Structure:**
- [ ] SKILL.md file exists with valid YAML frontmatter
- [ ] Frontmatter has `name` and `description` fields
- [ ] Markdown body is present and substantial
- [ ] Referenced files actually exist

**Description Quality:**
- [ ] Uses third person ("This skill should be used when...")
- [ ] Describes triggering conditions, NOT the workflow
- [ ] Includes specific trigger phrases users would say
- [ ] Lists concrete scenarios and keywords
- [ ] Not vague or generic

**Content Quality:**
- [ ] SKILL.md body uses imperative/infinitive form
- [ ] Body is focused and lean (1,500-2,000 words ideal, <5k max)
- [ ] Detailed content moved to references/
- [ ] Examples are complete and working
- [ ] Scripts are executable and documented

**Progressive Disclosure:**
- [ ] Core concepts in SKILL.md
- [ ] Detailed docs in references/
- [ ] Working code in examples/
- [ ] Utilities in scripts/
- [ ] SKILL.md references these resources

**Testing:**
- [ ] Skill triggers on expected user queries
- [ ] Verification scenarios pass (agent complies with the skill present)
- [ ] Content is helpful for intended tasks
- [ ] No duplicated information across files
- [ ] References load when needed

## Common Mistakes to Avoid

### Mistake 1: Weak Trigger Description

❌ **Bad:** `description: Provides guidance for working with hooks.`

Vague, no trigger phrases, not third person.

✅ **Good:** `description: This skill should be used when the user asks to "create a hook", "add a PreToolUse hook", or mentions hook events (PreToolUse, PostToolUse, Stop).`

### Mistake 2: Description Summarizes the Workflow

❌ **Bad:** `description: Use when executing plans - dispatches subagent per task with code review between tasks.`

The agent may follow the description instead of reading the skill body.

✅ **Good:** `description: Use when executing implementation plans with independent tasks in the current session.`

### Mistake 3: Too Much in SKILL.md

❌ **Bad:** 8,000-word SKILL.md with everything in one file — bloats context on every load.

✅ **Good:** 1,800-word SKILL.md (core essentials) + `references/` files (2,500-3,700 words each) loaded only when needed.

### Mistake 4: Second Person Writing

❌ **Bad:** `You should start by reading the configuration file.`

✅ **Good:** `Start by reading the configuration file.`

### Mistake 5: Missing Resource References

SKILL.md must tell the agent where references/examples/scripts live:

```markdown
## Additional Resources
### Reference Files
- **`references/patterns.md`** - Detailed patterns
### Examples
- **`examples/script.sh`** - Working example
```

### Mistake 6: Narrative Storytelling

❌ "In session 2025-10-03, we found empty projectDir caused..."

Too specific, not reusable. Skills are reusable techniques, not session narratives.

### Mistake 7: Multi-Language Dilution

❌ example-js.js + example-py.py + example-go.go

One excellent example beats many mediocre ones. Porting is easy.

## Quick Reference

### Minimal Skill

```
skill-name/
└── SKILL.md
```

Good for: Simple knowledge, no complex resources needed.

### Standard Skill (Recommended)

```
skill-name/
├── SKILL.md
├── references/
│   └── detailed-guide.md
└── examples/
    └── working-example.sh
```

Good for: Most skills with detailed documentation.

### Complete Skill

```
skill-name/
├── SKILL.md
├── references/
│   ├── patterns.md
│   └── advanced.md
├── examples/
│   ├── example1.sh
│   └── example2.json
└── scripts/
    └── validate.sh
```

Good for: Complex domains with validation utilities.

## Best Practices Summary

✅ **DO:**
- Write the trigger description BEFORE the body; describe when to use, not what it does
- Use third-person in description ("This skill should be used when...")
- Include specific trigger phrases ("create X", "configure Y")
- Keep SKILL.md lean (1,500-2,000 words)
- Use progressive disclosure (move details to references/)
- Write in imperative/infinitive form
- Reference supporting files clearly
- Provide working examples
- Create utility scripts for common operations
- Verify after writing — run scenarios with the skill present and confirm compliance

❌ **DON'T:**
- Use second person anywhere
- Summarize the workflow in the description
- Have vague trigger conditions
- Put everything in SKILL.md (>3,000 words without references/)
- Leave resources unreferenced
- Include broken or incomplete examples
- Skip validation
- Declare a skill done without running verification scenarios