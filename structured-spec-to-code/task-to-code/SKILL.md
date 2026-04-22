---
name: task-to-code
description: Autonomously implement a code task using test-driven development, following an Explore, Plan, Code, Commit workflow. Takes a structured code task file (from plan-to-tasks or interactive-coding-task) and produces a complete, tested implementation with a conventional commit. Escalates to the user only when blocked by issues that require revisiting the task, plan, or design.
---

# Task to Code

## Overview

Autonomously implement a code task using TDD principles: Explore the codebase and requirements, Plan tests and implementation, Code following the RED → GREEN → REFACTOR cycle, and Commit the result. The agent works independently, documenting decisions in a scratchpad, and escalates only when blocked.

## Parameters

- **agents_dir** (optional, default: `.agents`): Base directory for all structured-spec-to-code workflow artifacts
- **task** (required): Path to a `.code-task.md` file, or a direct task description. If a file, its Reference Documentation section (if present) points to design and research documents that MUST be read
- **scratchpad_dir** (optional): Base directory for working documents (context, plan, progress). Defaults to `{agents_dir}/scratchpad/`. The scratchpad for a task is created by mirroring the task file's directory structure relative to the tasks directory. For example:
  - Task at `{agents_dir}/tasks/template-feature/step02/task-01-create-data-models.code-task.md` → scratchpad at `{agents_dir}/scratchpad/template-feature/step02/task-01-create-data-models/`
  - Task at `{agents_dir}/tasks/2026-03-23-auth-rate-limit/task-01-add-login-rate-limiting.code-task.md` → scratchpad at `{agents_dir}/scratchpad/2026-03-23-auth-rate-limit/task-01-add-login-rate-limiting/`
  - If task is provided as text (no file), generate a subdirectory name from the current date and a short slug inferred from the description

**Constraints for parameter acquisition:**
- You MUST ask for all parameters upfront in a single prompt
- You MUST validate that the task file exists and is readable (if a file path)
- You MUST confirm successful acquisition of all parameters before proceeding

## Escalation Policy

This workflow runs autonomously. Escalate to the user ONLY when:
- The task description is inconsistent with the actual codebase (e.g., references non-existent code, assumes wrong architecture)
- Required information is missing and cannot be reasonably inferred
- Tests or builds fail repeatedly and you cannot resolve the root cause
- A design decision has significant trade-offs that the task doesn't address

When escalating, clearly describe the blocker, what you've tried, and what decision you need.

## Steps

### 1. Setup

Initialize the scratchpad and read all referenced documentation.

**Constraints:**
- You MUST determine the scratchpad path (`{scratchpad}`) by mirroring the task file's path structure as described in Parameters
- You MUST create the scratchpad directory
- You MUST read the task file and extract all requirements, acceptance criteria, and references
- If the task has a Reference Documentation section, you MUST read the design document and any listed research documents
- You MUST create a `context.md` file in the scratchpad for recording findings throughout the workflow
- You MUST create a `progress.md` file using markdown checklists to track implementation progress
- You MUST create an empty `work.log` file — this is the append-only TDD evidence log, populated during the Code phase
- All documentation goes in the scratchpad; all code goes in the repository. Never mix them

### 2. Explore

Analyze requirements and research existing patterns in the codebase.

**Constraints:**
- You MUST create a clear list of functional requirements and acceptance criteria from the task
- You MUST determine the appropriate file paths and programming language, aligned with the existing project structure
- You MUST search the repository for relevant code, patterns, and conventions related to the task
- You MUST identify interfaces, libraries, and components the implementation will interact with
- You SHOULD create a dependency map showing how the new code will integrate, when the task involves multiple components
- You MUST update context.md with requirements, patterns, dependencies, and implementation paths
- If you discover inconsistencies between the task and the actual codebase, you MUST escalate to the user
- You SHOULD identify similar implementations in the codebase to follow established patterns
- You SHOULD consult the codebase summary at `{agents_dir}/summary/` if available, to understand broader system context — especially useful for tasks without a design document
- You SHOULD read `{agents_dir}/summary/coding_style.md` if it exists, and record the applicable conventions and representative examples in context.md — this is the primary style reference for the GREEN and REFACTOR phases

### 3. Plan

Design the test strategy and outline the implementation approach.

#### 3.1 Test Strategy

**Constraints:**
- You MUST cover all acceptance criteria with at least one test scenario
- You MUST define explicit input/output pairs for each test case
- You MUST design tests that will initially fail when run against non-existent implementations
- You MUST save test scenarios to `{scratchpad}/plan.md`

#### 3.2 Implementation Plan

**Constraints:**
- You MUST append the implementation plan to `{scratchpad}/plan.md`
- You MUST include all key implementation tasks with a markdown checklist
- You MUST keep planning concise — focus on architecture and approach, not detailed code
- You SHOULD consider performance, security, and maintainability implications

### 4. Code

Implement tests and code following the TDD cycle. For each requirement or acceptance criterion, repeat the RED → GREEN → REFACTOR cycle before moving to the next.

#### 4.1 Per-Requirement TDD Cycle

For each requirement, in the order defined by the implementation plan:

**RED — Write a failing test:**
- You MUST write a test (or small group of related tests) for the current requirement
- You MUST place test files in the appropriate test directories in the repository
- You MUST follow the testing framework conventions used in the existing codebase
- You MUST execute the test to verify it fails as expected
- You MUST document the failure in progress.md
- You MUST append the following to `{scratchpad}/work.log`, capturing both the command and its output:
  ```
  echo >> {scratchpad}/work.log "## Requirement <name>: RED - repo state"
  bash -x -c "jj log -s --limit=4" >> {scratchpad}/work.log 2>&1
  echo >> {scratchpad}/work.log "## Requirement <name>: RED - failing tests"
  bash -x -c "<test command>" >> {scratchpad}/work.log 2>&1
  ```

**GREEN — Implement just enough code to pass:**
- You MUST implement only what is needed to make the current test(s) pass
- You MUST follow the coding style and conventions of the existing codebase (consult coding_style.md conventions recorded in context.md)
- You MUST place all implementation code in the appropriate repository directories
- You MUST follow YAGNI, KISS, and SOLID principles
- You MUST execute tests to verify the new test passes and no existing tests broke
- You MUST append the following to `{scratchpad}/work.log`:
  ```
  echo >> {scratchpad}/work.log "## Requirement <name>: GREEN - repo state"
  bash -x -c "jj log -s --limit=4" >> {scratchpad}/work.log 2>&1
  echo >> {scratchpad}/work.log "## Requirement <name>: GREEN - passing tests"
  bash -x -c "<test command>" >> {scratchpad}/work.log 2>&1
  ```
- If an acceptance criterion specifies running an ad-hoc command (e.g. a CLI smoke test), append its output too:
  ```
  echo >> {scratchpad}/work.log "## Requirement <name>: acceptance - <criterion summary>"
  bash -x -c "<ad-hoc command>" >> {scratchpad}/work.log 2>&1
  ```

**REFACTOR — Clean up while green:**
- You MUST examine the code just written and refactor for clarity, removing duplication
- You MUST ensure alignment with surrounding codebase conventions (naming, error handling, imports, etc.) — use coding_style.md representative examples as the reference standard
- You MUST prioritize readability and maintainability over clever optimizations
- You MUST execute tests after refactoring to verify nothing broke

Then move to the next requirement. Update the implementation checklist in progress.md after each cycle.

#### 4.2 Validate

**Constraints:**
- You MUST execute all tests and verify they pass
- You MUST execute the relevant build command and verify it succeeds
- You MUST verify all items in the implementation checklist are complete
- You MUST NOT proceed to commit if any tests are failing
- If validation fails and you cannot resolve it, you MUST escalate to the user

### 5. Commit

Create a conventional commit for the completed implementation.

**Constraints:**
- You MUST NOT commit until both builds and tests pass
- You MUST follow the Conventional Commits specification
- You MUST commit all relevant files (implementation code, tests, and any necessary configuration changes)
- You MUST NOT commit scratchpad files
- You MUST NOT push to remote repositories
- You MUST document the commit revision identifier in progress.md
- You MUST verify all checklist items are marked complete before committing
- After committing, if the task originates from a plan (i.e., it lives under a `step{NN}/` directory within `{agents_dir}/tasks/`), you MUST check whether all tasks in that step directory are now complete (all have a corresponding commit documented in their scratchpad's progress.md). If so, you MUST mark the corresponding checklist item in the implementation plan as complete (change `- [ ]` to `- [x]`)

## Examples

### Example Input
```
task: ".agents/tasks/template-feature/step02/task-01-create-data-models.code-task.md"
```

### Example Process
```
1. Read task file → read referenced design document and research
2. Explore: Identify existing ORM patterns, database conventions in the repo
3. Plan: Design test scenarios for model creation, validation, persistence
4. Code (per-requirement TDD cycles):
   - RED: Write failing test for Template model creation
   - GREEN: Implement Template model to pass
   - REFACTOR: Align with existing model naming conventions
   - RED: Write failing test for Field model with validation
   - GREEN: Implement Field model and validation logic
   - REFACTOR: Extract shared validation patterns
   - ... (continue for remaining requirements)
   - Validate: All tests pass, build succeeds
5. Commit: "feat(models): add Template and Field data models with validation"
```

## Troubleshooting

### Build Issues
If builds fail during implementation:
- You SHOULD verify you're in the correct directory for the build system
- You SHOULD try clean builds when encountering stale cache issues
- You SHOULD check for missing dependencies and resolve them
- Review build/test output for specific error messages

### Multi-Package Coordination
If changes span multiple packages:
- You SHOULD verify package dependency order and build dependencies first
- You SHOULD validate each package builds before proceeding to dependents
- You SHOULD still aim for a single commit per task. If the changes are too large or loosely coupled to fit in one commit, escalate — the task may need to be split

### Implementation Challenges
If the implementation encounters unexpected challenges:
- You MUST document the challenge in progress.md
- You MUST attempt alternative approaches before escalating
- If blocked, escalate with a clear description of the issue and what you've tried

## Artifacts

```
{scratchpad}/
├── context.md      — Requirements, patterns, dependencies, implementation paths
├── plan.md         — Test scenarios and implementation plan
├── progress.md     — TDD cycle tracking, decisions, checklist, commit status
└── work.log        — Append-only TDD evidence: repo state + test output per RED/GREEN cycle
```
