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
| **structured-spec-to-code** | Meta skill: orchestrates the pipeline and determines current state | — |

## Pipeline

```
Rough idea → interactive-design → design-to-plan → plan-to-tasks → task-to-code → committed code
                                                                        ↑
                              Small change → interactive-coding-task ────┘
```

For brownfield projects, run **codebase-summary** first to give the design phase an understanding of the existing system.

## Directory Conventions

```
.agents/
├── summary/                          # Codebase summary (from codebase-summary)
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
            └── progress.md
```

## Origin

Adapted from Amazon's [strands-sop](https://github.com/strands-agents/agent-sop) skills, with significant restructuring: renamed skills, split interactive/autonomous phases, removed vendor-specific references, added brownfield support, and improved TDD workflow.
