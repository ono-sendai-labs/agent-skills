---
name: design-to-plan
description: Convert a detailed design document into a structured, incremental implementation plan with a progress checklist. Use when the user has a completed design document and wants to create an actionable implementation plan, or when transitioning from the interactive-design workflow to implementation.
---

# Design to Plan

## Overview

Convert a detailed design document into a structured implementation plan. Each step in the plan results in a working, demoable increment of functionality, following test-driven development and agile best practices.

## Parameters

- **project_dir** (required): Project directory containing the design and supporting artifacts (e.g., `.agents/planning/{project_name}`)
- **design_path** (optional, default: `{project_dir}/design/detailed-design.md`): Path to the detailed design document, if not at the conventional location
- **output_path** (optional, default: `{project_dir}/implementation/plan.md`): Path where the implementation plan will be written

**Constraints for parameter acquisition:**
- You MUST ask for all parameters upfront in a single prompt
- You MUST validate that the design document exists and is readable
- You MUST confirm successful acquisition of all parameters before proceeding

## Steps

### 1. Analyze Design

Read and understand the design document and any supporting artifacts.

**Constraints:**
- You MUST read the design document at design_path
- You SHOULD read supporting artifacts in project_dir if available (research notes, requirements in idea-honing.md) to inform the plan
- You MUST identify all components, interfaces, data models, and workflows described in the design
- You MUST identify dependencies between components
- For brownfield projects (indicated by Integration or Migration sections in the design), you SHOULD also review the codebase summary at `.agents/summary/` if available, to understand integration points and sequencing constraints

### 2. Create Implementation Plan

Create a structured implementation plan as a numbered series of incremental steps.

**Constraints:**
- You MUST create the output directory if it doesn't exist
- You MUST create the implementation plan at the output_path
- You MUST include a checklist at the beginning of plan.md to track implementation progress
- You MUST follow this guiding principle:
  ```
  Convert the design into a series of implementation steps that will build each component
  in a test-driven manner following agile best practices. Each step must result in a working,
  demoable increment of functionality. Prioritize incremental progress and early testing,
  ensuring no big jumps in complexity at any stage. Each step builds on previous steps and
  ends with wiring things together — no hanging or orphaned code.
  ```
- You MUST format the plan as a numbered series of detailed steps, each beginning with "Step N:"
- You MUST ensure each step includes:
  - A clear objective
  - General implementation guidance
  - Test requirements for the functionality introduced in this step
  - How it integrates with previous work
  - **Demo** — explicit description of the working functionality that can be demonstrated after completing this step
- You MUST sequence steps so that core end-to-end functionality is available as early as possible
- You MUST NOT include excessive implementation details already covered in the design document
- You MUST NOT create steps solely dedicated to testing — test requirements belong in the step that introduces the functionality
- You MUST ensure the plan covers all aspects of the design and the checklist items correspond directly to the steps
- For brownfield projects, you MUST sequence integration and migration steps appropriately — typically early (to validate compatibility) rather than deferred to the end

### 3. Present and Iterate

Present the plan to the user for review and revise based on feedback.

**Constraints:**
- You MUST summarize the plan structure: number of steps, key milestones, and overall progression
- You MUST highlight where core end-to-end functionality becomes available
- You MUST invite the user to request adjustments to the plan
- If the user requests changes, you MUST revise the plan and re-present until the user is satisfied
- Once the plan is accepted, you MUST suggest next steps, including running `plan-to-tasks` to generate code task files from the plan

## Examples

### Example Input
```
project_dir: ".agents/planning/template-feature"
```

### Example Output
```
I've read the detailed design and supporting artifacts. Here's the implementation plan:

Created: .agents/planning/template-feature/implementation/plan.md

The plan has 12 steps:
- Steps 1-3: Core data models and storage layer (demoable with CLI/REPL)
- Steps 4-6: Template CRUD API endpoints (demoable with API calls)
- Steps 7-9: Sharing, permissions, and versioning (demoable with multi-user scenarios)
- Steps 10-12: Document generation and custom fields (full feature demo)

Core end-to-end functionality (create template → generate document) is available by Step 7.

Would you like me to adjust the plan?
```

## Troubleshooting

### Design Document Incomplete
If the design document is missing sections or details:
- You SHOULD note which sections are incomplete and how this affects the plan
- You SHOULD create the plan based on available information and flag gaps
- You MAY suggest returning to the interactive-design workflow to fill gaps

### Plan Granularity
If the user finds steps too large or too small:
- You SHOULD adjust step granularity based on user feedback
- You SHOULD aim for steps that represent roughly 1-3 code tasks each
