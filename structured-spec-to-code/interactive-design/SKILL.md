---
name: interactive-design
description: This workflow guides you through the process of transforming a rough idea into a detailed design document. It systematically refines your idea through interactive requirements clarification, research, and iterative design. Use when the user has a rough idea, feature concept, or project proposal that needs to be developed into a comprehensive design before implementation — whether for a greenfield project or adding features to an existing system.
---

# Interactive Design

## Overview

Transform a rough idea into a detailed design document through interactive requirements clarification, research, and iterative design. The process is collaborative and iterative, allowing movement between requirements clarification and research as needed.

## Parameters

- **rough_idea** (required): The initial concept or idea to develop into a detailed design
- **project_name** (optional): A short, descriptive name for the project. If not provided, will be generated from the rough idea
- **project_dir** (optional, default: ".agents/planning/{project_name}"): The base directory where all project files will be stored

**Constraints for parameter acquisition:**
- You MUST ask for all required parameters upfront in a single prompt rather than one at a time
- You MUST support multiple input methods including:
  - Direct input: Text provided directly in the conversation
  - File path: Path to a local file containing the rough idea
  - URL: Link to an internal resource (e.g., document, wiki page)
  - Other methods: You SHOULD be open to other ways the user might want to provide the idea
- You MUST use appropriate tools to access content based on the input method
- You MUST confirm successful acquisition of all parameters before proceeding
- If project_name is not provided, You MUST generate a short kebab-case name from the rough idea, prefixed with the current date in YYYY-MM-DD format (e.g., "2026-01-30-template-manager", "2026-01-30-auth-system")
- You SHOULD save the acquired rough idea to a consistent location for use in subsequent steps
- You MUST NOT overwrite the existing project directory because this could destroy previous work and cause data loss
- You MUST ask for project_dir if it is not given and the generated default directory already exists and has contents from previous iteration

## Steps

### 1. Create Project Structure

Set up a directory structure to organize all artifacts created during the process.

**Constraints:**
- You MUST create the specified project directory if it doesn't already exist
- You MUST create the following file:
  - {project_dir}/rough-idea.md (containing the provided rough idea)
- You MUST create the following subdirectories:
  - {project_dir}/research/ (directory for research notes)
  - {project_dir}/design/ (directory for design documents)
- You MUST notify the user when the structure has been created
- You MUST remind the user to keep all project files in context throughout the process
- If the design targets an existing codebase, you MUST check if a codebase summary exists at `.agents/summary/`:
  - If it exists: check `.agents/summary/.last_commit` and use the VCS diff-stat (e.g., changes since that revision) to assess how current it is. If the summary is significantly out of date, suggest the user run the `codebase-summary` workflow to refresh it before proceeding
  - If it does not exist: suggest the user run the `codebase-summary` workflow first, as the design process will benefit from an up-to-date understanding of the codebase

### 2. Initial Process Planning

Determine the initial approach and sequence for requirements clarification and research.

**Constraints:**
- You MUST ask the user if they prefer to:
  - Start with requirements clarification (default)
  - Start with preliminary research on specific topics
  - Explore relevant parts of the existing codebase first (for brownfield projects — use the codebase summary and code navigation tools to understand the areas affected by the design)
  - Provide additional context or information before proceeding
- You MUST adapt the subsequent process based on the user's preference
- You MUST explain that the process is iterative and the user can move between requirements clarification and research as needed
- You MUST wait for explicit user direction before proceeding to any subsequent step
- You MUST NOT automatically proceed to requirements clarification or research without user confirmation because this could lead the process in a direction the user doesn't want

### 3. Requirements Clarification

Guide the user through a series of questions to refine the initial idea and develop a thorough specification.

**Constraints:**
- You MUST create an empty {project_dir}/idea-honing.md file if it doesn't already exist
- You MUST NOT pre-populate answers to questions without user input because this assumes user preferences without confirmation
- You MUST NOT write answers to the idea-honing.md file before the user has responded
- For questions that are nuanced, open-ended, or likely to benefit from discussion, you MUST ask ONE question at a time
- For questions that are straightforward and factual (e.g., target platform, supported formats, naming preferences), you MAY batch 2-4 related questions together in a single message
- You MUST wait for the user's complete response before proceeding, which may require brief back-and-forth dialogue across multiple turns
- After receiving the user's response, you MUST append both questions and answers to {project_dir}/idea-honing.md before proceeding
- You MAY suggest possible answers when asking a question, but MUST wait for the user's actual response
- You MUST format the idea-honing.md document with clear question and answer sections
- You MUST include the final chosen answer in the answer section
- You MAY include alternative options that were considered before the final decision
- You MUST continue asking questions until sufficient detail is gathered
- You SHOULD ask about edge cases, user experience, technical constraints, and success criteria
- For brownfield projects, you SHOULD also ask about integration with existing functionality, backward compatibility, impact on existing users/workflows, and migration concerns. Use the codebase summary (if available) to inform these questions
- You SHOULD adapt follow-up questions based on previous answers
- You MAY suggest options when the user is unsure about a particular aspect
- You MAY recognize when the requirements clarification process appears to have reached a natural conclusion
- You MUST explicitly ask the user if they feel the requirements clarification is complete before moving to the next step
- You MUST offer the option to conduct research if questions arise that would benefit from additional information
- You MUST be prepared to return to requirements clarification after research if new questions emerge
- You MUST NOT proceed with any other steps until explicitly directed by the user because this could skip important clarification steps

### 4. Research Relevant Information

Conduct research on relevant technologies, libraries, or existing code that could inform the design, while collaborating with the user for guidance.

**Constraints:**
- You MUST identify areas where research is needed based on the requirements
- You MUST propose an initial research plan to the user, listing topics to investigate
- You MUST ask the user for input on the research plan, including:
  - Additional topics that should be researched
  - Specific resources (files, websites, internal tools) the user recommends
  - Areas where the user has existing knowledge to contribute
- You MUST incorporate user suggestions into the research plan
- You MUST document research findings in separate markdown files in the {project_dir}/research/ directory
- You SHOULD organize research by topic (e.g., {project_dir}/research/existing-code.md, {project_dir}/research/technologies.md)
- You SHOULD include mermaid diagrams when documenting system architectures, data flows, or component relationships in research
- You MUST include links to relevant references and sources when research is based on external materials (websites, documentation, articles, etc.)
- You SHOULD use available tools (including code navigation, search, and the codebase summary if available) to gather relevant information
- You MUST periodically check with the user during the research process (these check-ins may involve brief dialogue to clarify feedback) to:
  - Share preliminary findings
  - Ask for feedback and additional guidance
  - Confirm if the research direction remains valuable
- You MUST summarize key findings that will inform the design
- You SHOULD cite sources and include relevant links in research documents
- You MUST ask the user if the research is sufficient before proceeding to the next step
- You MUST offer to return to requirements clarification if research uncovers new questions or considerations
- You MUST NOT automatically return to requirements clarification after research without explicit user direction because this could disrupt the user's intended workflow
- You MUST wait for the user to decide the next step after completing research

### 5. Iteration Checkpoint

Determine if further requirements clarification or research is needed before proceeding to design.

**Constraints:**
- You MUST summarize the current state of requirements and research to help the user make an informed decision
- You MUST explicitly ask the user if they want to:
  - Proceed to creating the detailed design
  - Return to requirements clarification based on research findings
  - Conduct additional research based on requirements
- You MUST support iterating between requirements clarification and research as many times as needed
- You MUST ensure that both the requirements and research are sufficiently complete before proceeding to design
- You MUST NOT proceed to the design step without explicit user confirmation because this could skip important refinement steps

### 6. Create Detailed Design

Develop a comprehensive design document based on the requirements and research.

**Constraints:**
- You MUST create a detailed design document at {project_dir}/design/detailed-design.md
- You MUST write the design as a standalone document that can be understood without reading other project files
- You MUST include the following sections in the design document:
  - Overview
  - Detailed Requirements (consolidated from idea-honing.md)
  - Architecture Overview
  - Components and Interfaces
  - Data Models
  - Error Handling
  - Testing Strategy
  - Appendices (Technology Choices, Research Findings, Alternative Approaches)
- For brownfield projects, you MUST also include:
  - Integration with Existing System — how the design fits into the current architecture, referencing the codebase summary where applicable
  - Migration Strategy / Backward Compatibility — how to transition from the current state without breaking existing functionality
- You MUST consolidate all requirements from the idea-honing.md file into the Detailed Requirements section
- You MUST include an appendix section that summarizes key research findings, including:
  - Major technology choices with pros and cons
  - Existing solutions analysis
  - Alternative approaches considered
  - Key constraints and limitations identified during research
- You SHOULD include diagrams or visual representations when appropriate using mermaid syntax
- You MUST generate mermaid diagrams for architectural overviews, data flow, and component relationships
- You MUST ensure the design addresses all requirements identified during the clarification process
- You SHOULD highlight design decisions and their rationales, referencing research findings where applicable
- You MUST review the design with the user and iterate based on feedback
- You MUST offer to return to requirements clarification or research if gaps are identified during design
- You MUST explicitly ask the user if they consider the design complete before proceeding to the summary step

### 7. Summarize and Present Results

Provide a summary of all artifacts created and next steps.

**Constraints:**
- You MUST create a summary document at {project_dir}/summary.md
- You MUST list all artifacts created during the process
- You MUST provide a brief overview of the design
- You MUST suggest next steps, including running the `design-to-plan` workflow to create an implementation plan from the design
- You SHOULD highlight any areas that may need further refinement
- You MUST present this summary to the user in the conversation

## Examples

### Example Input

```
Rough idea: I want to build a feature for our team's internal tool that allows users to create and manage templates for common documents we produce. Users should be able to create, edit, and share templates, as well as use them to generate new documents with custom fields.

Project name: template-feature
```

### Example Output

```
# Research Phase Interaction

Based on your requirements, I've identified several areas that would benefit from research:

1. **Existing template solutions** - Understanding what's already available
2. **Storage and versioning approaches** - How to handle template versions and sharing
3. **Custom field validation patterns** - Best practices for dynamic field validation

Should I also explore any specific parts of the existing codebase or internal documentation that might inform these areas?

---

# Project Summary

I've completed the transformation of your rough idea into a detailed design. Here's what was created:

## Directory Structure
- .agents/planning/template-feature/
  - rough-idea.md (your initial concept)
  - idea-honing.md (our Q&A requirements clarification)
  - research/
    - existing-templates.md
    - storage-options.md
    - external-solutions.md
  - design/
    - detailed-design.md
  - summary.md (this document)

## Key Design Elements
- Template management system with CRUD operations
- Role-based access control for sharing
- Versioning system for templates
- Custom fields with validation
- Document generation engine

## Next Steps
1. Review the detailed design document at .agents/planning/template-feature/design/detailed-design.md
2. When satisfied with the design, run the `design-to-plan` workflow to create an implementation plan

Would you like me to explain any specific part of the design in more detail?
```

## Troubleshooting

### Requirements Clarification Stalls
If the requirements clarification process seems to be going in circles or not making progress:
- You SHOULD suggest moving to a different aspect of the requirements
- You MAY provide examples or options to help the user make decisions
- You SHOULD summarize what has been established so far and identify specific gaps
- You MAY suggest conducting research to inform requirements decisions

### Research Limitations
If you cannot access needed information:
- You SHOULD document what information is missing
- You SHOULD suggest alternative approaches based on available information
- You MAY ask the user to provide additional context or documentation
- You SHOULD continue with available information rather than blocking progress

### Design Complexity
If the design becomes too complex or unwieldy:
- You SHOULD suggest breaking it down into smaller, more manageable components
- You SHOULD focus on core functionality first
- You MAY suggest a phased approach to implementation
- You SHOULD return to requirements clarification to prioritize features if needed
