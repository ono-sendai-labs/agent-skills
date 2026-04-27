# Structured Spec-to-Code

A suite of AI agent skills that guide a project from rough idea through design, planning, and implementation.

## Skills

| Skill | Purpose | Interactive? |
|---|---|---|
| **codebase-summary** | Analyze a codebase and generate documentation for AI assistants | No |
| **interactive-design** | Refine a rough idea into a detailed design document through collaborative Q&A | Yes |
| **design-to-plan** | Convert a design document into an incremental implementation plan | Light review |
| **plan-to-tasks** | Generate code task files from a plan step | No |
| **interactive-coding-task** | Create code task files from ad-hoc descriptions (small changes) | Yes |
| **task-to-code** | Implement a code task using TDD (Explore → Plan → Code → Commit) | No (escalates when blocked) |
| **code-task-review** | Review the commit produced by a single `task-to-code` run; emit a structured YAML report | No |
| **implementation-review** | Review the full implementation once all plan steps are complete; emit a YAML report and follow-on remediation `.code-task.md` files | No |
| **structured-spec-to-code** | Meta skill: orchestrates the pipeline and determines current state | — |

## Pipeline

```
Rough idea → interactive-design → design-to-plan → plan-to-tasks → task-to-code → code-task-review → committed code
                                                                        ↑              │
                              Small change → interactive-coding-task ────┘              │
                                                                                        ▼
                                                                          (report consumed by orchestrator;
                                                                           remediation re-enters task-to-code)

                            ↳ once all plan steps are complete: implementation-review
                                                                        │
                                                                        ▼
                                          (generates remediation tasks → re-enters plan-to-tasks → task-to-code)
```

For brownfield projects, run **codebase-summary** first to give the design phase an understanding of the existing system.

`code-task-review` runs after each `task-to-code` commit with clean context (cheap-model territory). Its YAML report (schema in `code-task-review/report-schema.md`) carries severity-labeled findings; the orchestrator decides whether to feed remediation back to `task-to-code` or accept the task.

`implementation-review` runs once after all plan steps are complete, also with clean context but with a more capable model. It looks across the whole implementation for architectural drift, duplication, undesirable dependencies, and doc/code divergence — issues no per-task review could catch. It emits a YAML report (schema in `implementation-review/report-schema.md`) and generates follow-on `.code-task.md` files in a new step folder, appending a corresponding step to `plan.md`. Those tasks then flow through the existing `task-to-code` loop.

## Directory Conventions

The base directory defaults to `.agents/` and is configurable via the `agents_dir` parameter on each skill.

```
{agents_dir}/
├── summary/                          # Codebase summary & coding style (from codebase-summary)
├── planning/{project_name}/          # Design artifacts (from interactive-design)
│   ├── rough-idea.md
│   ├── idea-honing.md
│   ├── research/
│   ├── design/detailed-design.md
│   └── implementation/plan.md
├── tasks/{project_name}/             # Code task files
│   ├── step01/                       #   from plan-to-tasks (grouped by plan step)
│   │   ├── task-01-*.code-task.md
│   │   └── task-02-*.code-task.md
│   ├── step02/
│   │   └── ...
│   └── task-01-*.code-task.md        #   from interactive-coding-task (no step folder)
└── scratchpad/{project_name}/        # Working documents from task-to-code
    └── step01/                       #   mirrors tasks/ structure
        └── task-01-*/
            ├── context.md
            ├── plan.md
            ├── progress.md
            ├── work.log               #   TDD evidence (RED/GREEN per cycle)
            └── review.yaml            #   from code-task-review
```

## Origin

Adapted from Amazon's [strands-sop](https://github.com/strands-agents/agent-sop) skills, with significant restructuring: renamed skills, split interactive/autonomous phases, removed vendor-specific references, added brownfield support, and improved TDD workflow.
