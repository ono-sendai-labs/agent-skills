---
name: interactive-coding-task
description: Interactively create structured code task files from rough descriptions, ideas, or ad-hoc requests. Use for smaller, well-scoped changes that don't need a full design-to-plan workflow — e.g., "address the TODO at auth.rs:45", "add input validation to the signup form", or "refactor the logging module to use structured logs".
---

# Interactive Coding Task

## Overview

Create structured code task files through interactive conversation. Suited for smaller, well-scoped changes where the context is fairly clear and a full design/plan workflow would be overkill. The workflow clarifies requirements, structures the task, and generates code task files that can be handed to `task-to-code`.

## Parameters

- **task_description** (required): What needs to be done. Can be a sentence, paragraph, file path containing a description, or a reference to specific code (e.g., "fix the TODO at src/auth.rs:45")
- **output_dir** (optional, default: `.agents/tasks/{project_name}`): Directory where code task files will be created
- **project_name** (optional): Project name for organizing tasks. If not provided, generated from the description with a YYYY-MM-DD date prefix

**Constraints for parameter acquisition:**
- You MUST ask for all parameters upfront in a single prompt
- You MUST support multiple input methods for task_description: direct text, file path, or URL
- You MUST confirm successful acquisition of all parameters before proceeding

## Steps

### 1. Understand the Request

Analyze the task description and gather enough context to create a well-structured task.

**Constraints:**
- You MUST identify the core functionality being requested
- If the description references specific code (files, line numbers, functions), you MUST read that code to understand the context
- You SHOULD check the codebase summary at `.agents/summary/` if available, to understand the broader system context
- You SHOULD examine how similar functionality is implemented elsewhere in the codebase to identify existing patterns, conventions, and reusable components
- You MUST extract any technical requirements, constraints, or preferences mentioned
- You MUST determine the appropriate complexity level (Low/Medium/High)
- If the request is ambiguous or underspecified, you MUST ask clarifying questions before proceeding — batch straightforward questions (2-4) together, and ask nuanced ones individually
- If the request seems too large for a single task (more than ~3 code tasks), you SHOULD suggest using the `interactive-design` workflow instead

### 2. Structure and Approve Tasks

Organize requirements into a task breakdown and get user approval.

**Constraints:**
- You MUST identify specific functional requirements from the description and any clarifications
- You MUST create measurable acceptance criteria using Given-When-Then format
- You MUST present each planned task with a one-line summary, proposed sequence, and its acceptance criteria for review
- You MUST ask the user to approve the breakdown before generating files
- You MUST allow the user to request modifications

### 3. Generate Task Files

Create code task files for the approved breakdown.

**Constraints:**
- You MUST create task files named: `task-01-{title}.code-task.md`, `task-02-{title}.code-task.md`, etc. (or a single file if only one task)
- You MUST use kebab-case for task names
- You MUST follow the Code Task Format below
- You MUST include comprehensive acceptance criteria covering functionality and tests
- You MUST NOT create separate tasks for testing — test requirements belong in each functional task
- You MUST provide realistic complexity assessment and required skills

### 4. Report Results

Inform the user about generated tasks and next steps.

**Constraints:**
- You MUST list all generated task files with their paths
- You MUST provide a brief summary of what was created
- You MUST suggest running `task-to-code` on each task in sequence
- If the scope turned out larger than expected, you MUST offer to create additional related tasks

## Code Task Format

Each code task file MUST follow this structure:

```markdown
# Task: [Task Name]

## Description
[What needs to be implemented and why]

## Background
[Context needed to understand the task]

## Technical Requirements
1. [First requirement]
2. [Second requirement]

## Dependencies
- [Dependency with details]

## Implementation Approach
1. [First step or approach]
2. [Second step or approach]

## Acceptance Criteria

1. **[Criterion Name]**
   - Given [precondition]
   - When [action]
   - Then [expected result]

## Metadata
- **Complexity**: [Low/Medium/High]
- **Labels**: [Comma-separated list]
- **Required Skills**: [Skills needed]
```

## Examples

### Example Input
```
task_description: "Address the TODO comment in src/auth.rs line 45 about adding rate limiting"
```

### Example Output
```
I've read src/auth.rs:45. The TODO says: "TODO: add rate limiting to prevent brute-force attacks".

Looking at the surrounding code, this is the login endpoint handler. The codebase already uses
the `governor` crate for rate limiting in the API gateway (src/gateway/throttle.rs).

Proposed task:
1. task-01-add-login-rate-limiting — Apply per-IP rate limiting to the login endpoint using the existing governor setup

Approve this breakdown? [y/modify]

---

Generated: .agents/tasks/2026-03-23-auth-rate-limit/task-01-add-login-rate-limiting.code-task.md

Next: Run `task-to-code` on the task to implement it.
```

## Troubleshooting

### Vague Description
If the task description is too vague or unclear:
- You SHOULD ask clarifying questions about specific requirements
- You SHOULD reference relevant code or the codebase summary to ground the conversation

### Scope Creep
If the task grows beyond the expected scope during clarification:
- You SHOULD suggest using `interactive-design` for the broader effort
- You SHOULD offer to create a focused task for the most critical piece
