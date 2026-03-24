---
name: plan-to-tasks
description: Generate structured code task files from an implementation plan. Processes one plan step at a time, breaking it into logical code tasks with acceptance criteria. Use when the user has an implementation plan (from design-to-plan or similar) and wants to generate code task files for the next step.
---

# Plan to Tasks

## Overview

Generate structured code task files from an implementation plan. Processes one step at a time, breaking it into logical sub-tasks with acceptance criteria, reference documentation, and implementation guidance. Each code task is a self-contained specification that can be handed to the `task-to-code` workflow.

## Parameters

- **agents_dir** (optional, default: `.agents`): Base directory for all structured-spec-to-code workflow artifacts
- **project_dir** (required): Project directory containing the plan and design artifacts (e.g., `{agents_dir}/planning/{project_name}`)
- **plan_path** (optional, default: `{project_dir}/implementation/plan.md`): Path to the implementation plan
- **step_number** (optional): Specific step to process. If not provided, automatically determines the next uncompleted step from the plan's checklist
- **output_dir** (optional, default: `{agents_dir}/tasks/{project_name}`): Directory where code task files will be created. `{project_name}` is inferred from the last path component of project_dir (e.g., `{agents_dir}/planning/template-feature` → `template-feature`)

**Constraints for parameter acquisition:**
- You MUST ask for all parameters upfront in a single prompt
- You MUST validate that the plan file exists and is readable
- You MUST confirm successful acquisition of all parameters before proceeding

## Steps

### 1. Parse Plan and Determine Target Step

Read the implementation plan and identify which step to process.

**Constraints:**
- You MUST read the plan file and parse its checklist and numbered steps
- You MUST determine the target step: use step_number if provided, otherwise find the first uncompleted step from the checklist
- If all steps are complete, you MUST inform the user and ask how to proceed
- You MUST read the design document (at `{project_dir}/design/detailed-design.md` or as referenced in the plan) to understand the full context
- You SHOULD read relevant research documents in `{project_dir}/research/` if they inform the target step

### 2. Break Down Step into Tasks

Analyze the target step and break it into logical code tasks. This step is non-interactive — use best judgement to produce a good breakdown.

Each code task MUST be an **atomic commit** — after implementing a task, the repository builds and all tests pass. A task should focus on a **single concern** (one data model, one API endpoint, one validation layer) and be **independently testable** (tests can be written without code from later tasks in the same step).

**Constraints:**
- You MUST extract the step's objective, implementation guidance, test requirements, integration notes, and demo criteria
- You MUST break the step into logical sub-tasks focusing on functional components
- You MUST sequence tasks so that each builds on prior work — tasks that create things later tasks consume come first (e.g., "define schema" before "implement CRUD on that schema")
- You MUST NOT create separate tasks for testing — test requirements belong in each functional task
- You MUST identify which research documents (if any) are directly relevant to each task
- If the step would produce more than 5-6 tasks, you MUST split at a natural boundary and escalate to the user for guidance
- You MUST log a concise one-line summary for each planned task with proposed sequence and dependencies

### 3. Generate Task Files

Create code task files for the approved breakdown.

**Constraints:**
- You MUST create a folder named `step{NN}` (zero-padded) within output_dir (e.g., `step01`, `step02`)
- You MUST create task files named sequentially: `task-01-{title}.code-task.md`, `task-02-{title}.code-task.md`, etc.
- You MUST use kebab-case for task names
- You MUST follow the Code Task Format below
- You MUST include a "Reference Documentation" section with the path to the design document as required reading
- You MUST include specific research documents in "Additional References" only if directly relevant to that task
- You MUST include comprehensive acceptance criteria covering functionality and tests
- You MUST provide realistic complexity assessment and required skills

### 4. Report Results

Inform the user about generated tasks and next steps.

**Constraints:**
- You MUST list all generated task files with their paths
- You MUST include the step's demo requirements for context
- You MUST suggest running `task-to-code` on each task in sequence
- You MUST NOT mark the plan's checklist item as complete — the checklist tracks implementation progress, not task generation. `task-to-code` marks the step complete after the last task in the step is committed. Re-running plan-to-tasks for the same step will regenerate its tasks

## Code Task Format

Each code task file MUST follow this structure:

```markdown
# Task: [Task Name]

## Description
[What needs to be implemented and why]

## Background
[Context needed to understand the task]

## Reference Documentation
**Required:**
- Design: [path to detailed design document]

**Additional References (if relevant to this task):**
- [Specific research document or section]

**Note:** Read the detailed design document before beginning implementation.

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
project_dir: ".agents/planning/template-feature"
```

### Example Output
```
Parsed plan: 12 steps, 1 completed.
Processing Step 2: Core data models and validation.

Generated: .agents/tasks/template-feature/step02/
- task-01-create-data-models — Define Template and Field data models with persistence
- task-02-implement-validation — Add field-level validation rules and error reporting
- task-03-add-serialization — JSON serialization/deserialization with round-trip tests

Step 2 demo: Working data models with validation that can create, validate, and serialize/deserialize data objects.

Next: Run `task-to-code` on each task in sequence.
```

## Troubleshooting

### Plan File Not Found
If the plan file doesn't exist at the expected path:
- You SHOULD check if project_dir contains an `implementation/` directory
- You SHOULD suggest running `design-to-plan` first if no plan exists

### All Steps Complete
If all steps in the checklist are marked complete:
- You SHOULD inform the user and ask if they want to regenerate tasks for a specific step
- You SHOULD suggest reviewing the plan for potential additional steps

### Step Too Large
If a step would produce more than 5-6 tasks:
- You MUST escalate to the user for guidance on where to split
